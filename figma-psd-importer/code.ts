import { readPsd, Layer as PsdLayer, Psd } from 'ag-psd';

interface ImportOptions {
  importText: boolean;
  preserveOpacity: boolean;
  importHidden: boolean;
}

interface PluginMessage {
  type: string;
  data?: Uint8Array;
  fileName?: string;
  options?: ImportOptions;
}

figma.showUI(__html__, { width: 420, height: 460 });

function sendProgress(percent: number, message: string) {
  figma.ui.postMessage({ type: 'progress', percent, message });
}

function sendDone(message: string) {
  figma.ui.postMessage({ type: 'done', message });
}

function sendError(message: string) {
  figma.ui.postMessage({ type: 'error', message });
}

function rgbaToFigmaColor(r: number, g: number, b: number, a: number = 255): { color: RGB; opacity: number } {
  return {
    color: { r: r / 255, g: g / 255, b: b / 255 },
    opacity: a / 255,
  };
}

function applyBlendMode(node: SceneNode, blendMode?: string) {
  if (!blendMode) return;

  const modeMap: Record<string, BlendMode> = {
    'normal': 'NORMAL',
    'dissolve': 'NORMAL',
    'darken': 'DARKEN',
    'multiply': 'MULTIPLY',
    'color burn': 'COLOR_BURN',
    'linear burn': 'LINEAR_BURN',
    'darker color': 'DARKEN',
    'lighten': 'LIGHTEN',
    'screen': 'SCREEN',
    'color dodge': 'COLOR_DODGE',
    'linear dodge': 'LINEAR_DODGE',
    'lighter color': 'LIGHTEN',
    'overlay': 'OVERLAY',
    'soft light': 'SOFT_LIGHT',
    'hard light': 'HARD_LIGHT',
    'vivid light': 'HARD_LIGHT',
    'linear light': 'LINEAR_BURN',
    'pin light': 'HARD_LIGHT',
    'hard mix': 'HARD_LIGHT',
    'difference': 'DIFFERENCE',
    'exclusion': 'EXCLUSION',
    'subtract': 'EXCLUSION',
    'divide': 'NORMAL',
    'hue': 'HUE',
    'saturation': 'SATURATION',
    'color': 'COLOR',
    'luminosity': 'LUMINOSITY',
  };

  const key = blendMode.toLowerCase();
  if (key in modeMap && 'blendMode' in node) {
    (node as any).blendMode = modeMap[key];
  }
}

async function imageFromCanvas(layer: PsdLayer): Promise<Uint8Array | null> {
  const canvas = layer.canvas;
  if (!canvas) return null;

  // ag-psd provides canvas with toBuffer (Node) or toDataURL-like
  // In browser/plugin context, canvas is an OffscreenCanvas or HTMLCanvasElement
  try {
    if ('toBuffer' in canvas && typeof (canvas as any).toBuffer === 'function') {
      return new Uint8Array((canvas as any).toBuffer('image/png'));
    }

    // For OffscreenCanvas
    if ('convertToBlob' in canvas && typeof (canvas as any).convertToBlob === 'function') {
      const blob: Blob = await (canvas as any).convertToBlob({ type: 'image/png' });
      const buffer = await blob.arrayBuffer();
      return new Uint8Array(buffer);
    }

    // For HTMLCanvasElement
    if ('toBlob' in canvas) {
      return new Promise<Uint8Array | null>((resolve) => {
        (canvas as HTMLCanvasElement).toBlob((blob) => {
          if (!blob) { resolve(null); return; }
          blob.arrayBuffer().then(buf => resolve(new Uint8Array(buf)));
        }, 'image/png');
      });
    }
  } catch (_e) {
    // fallback: try getImageData
  }

  // Fallback: encode raw pixel data as a Figma-compatible image
  try {
    const ctx = (canvas as HTMLCanvasElement).getContext('2d');
    if (ctx) {
      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
      return new Uint8Array(imageData.data.buffer);
    }
  } catch (_e) {
    // ignore
  }

  return null;
}

async function createLayerNode(
  layer: PsdLayer,
  parent: FrameNode | GroupNode | PageNode,
  options: ImportOptions,
  depth: number = 0
): Promise<SceneNode | null> {
  // Skip hidden layers if option is off
  if (layer.hidden && !options.importHidden) {
    return null;
  }

  const name = layer.name || 'Layer';

  // Group / folder
  if (layer.children && layer.children.length > 0) {
    const group = figma.group([], parent);
    group.name = name;

    for (const child of layer.children) {
      await createLayerNode(child, parent, options, depth + 1);
    }

    // Move created children into the group
    // ag-psd children are in order, we add them to parent then group
    if (group.children.length === 0) {
      // If group ended up empty, try to re-parent recently added nodes
      // Actually, let's use a different approach - create frame first
      group.remove();

      const frame = figma.createFrame();
      frame.name = name;
      parent.appendChild(frame);
      frame.fills = []; // transparent background

      if (layer.left !== undefined && layer.top !== undefined) {
        frame.x = layer.left;
        frame.y = layer.top;
      }

      if (layer.right !== undefined && layer.left !== undefined &&
          layer.bottom !== undefined && layer.top !== undefined) {
        frame.resize(
          Math.max(1, layer.right - layer.left),
          Math.max(1, layer.bottom - layer.top)
        );
      }

      frame.clipsContent = false;

      for (const child of layer.children) {
        const childNode = await createLayerNode(child, frame, options, depth + 1);
        if (childNode) {
          // Adjust position relative to group
          if (layer.left !== undefined && layer.top !== undefined) {
            childNode.x -= layer.left;
            childNode.y -= layer.top;
          }
        }
      }

      if (options.preserveOpacity && layer.opacity !== undefined) {
        frame.opacity = layer.opacity;
      }

      if (layer.hidden) {
        frame.visible = false;
      }

      applyBlendMode(frame, layer.blendMode);
      return frame;
    }

    if (options.preserveOpacity && layer.opacity !== undefined) {
      group.opacity = layer.opacity;
    }

    if (layer.hidden) {
      group.visible = false;
    }

    applyBlendMode(group, layer.blendMode);
    return group;
  }

  // Text layer
  if (layer.text && options.importText) {
    const textNode = figma.createText();
    textNode.name = name;
    parent.appendChild(textNode);

    // Position
    if (layer.left !== undefined && layer.top !== undefined) {
      textNode.x = layer.left;
      textNode.y = layer.top;
    }

    // Load font before setting characters
    try {
      let fontFamily = 'Inter';
      let fontStyle = 'Regular';

      if (layer.text.style) {
        if (layer.text.style.font?.name) {
          fontFamily = layer.text.style.font.name;
        }
        if (layer.text.style.fauxBold) {
          fontStyle = 'Bold';
        }
        if (layer.text.style.fauxItalic) {
          fontStyle = fontStyle === 'Bold' ? 'Bold Italic' : 'Italic';
        }
      }

      try {
        await figma.loadFontAsync({ family: fontFamily, style: fontStyle });
      } catch (_e) {
        // Fallback to Inter
        await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
        fontFamily = 'Inter';
        fontStyle = 'Regular';
      }

      const textValue = layer.text.text || name;
      textNode.characters = textValue;
      textNode.fontName = { family: fontFamily, style: fontStyle };

      // Font size
      if (layer.text.style?.fontSize) {
        textNode.fontSize = layer.text.style.fontSize;
      }

      // Text color
      if (layer.text.style?.fillColor) {
        const c = layer.text.style.fillColor;
        const { color, opacity } = rgbaToFigmaColor(
          Math.round((c.r ?? 0) * 255),
          Math.round((c.g ?? 0) * 255),
          Math.round((c.b ?? 0) * 255),
          Math.round((c.a ?? 1) * 255)
        );
        textNode.fills = [{ type: 'SOLID', color, opacity }];
      }
    } catch (e) {
      // If text fails, still keep the node
      try {
        await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
        textNode.characters = layer.text.text || name;
      } catch (_e) {
        // ignore
      }
    }

    if (options.preserveOpacity && layer.opacity !== undefined) {
      textNode.opacity = layer.opacity;
    }

    if (layer.hidden) {
      textNode.visible = false;
    }

    applyBlendMode(textNode, layer.blendMode);
    return textNode;
  }

  // Image / raster layer
  if (layer.canvas) {
    const w = layer.canvas.width || 1;
    const h = layer.canvas.height || 1;

    const rect = figma.createRectangle();
    rect.name = name;
    parent.appendChild(rect);

    if (layer.left !== undefined && layer.top !== undefined) {
      rect.x = layer.left;
      rect.y = layer.top;
    }

    rect.resize(Math.max(1, w), Math.max(1, h));

    // Try to get image data
    const imageBytes = await imageFromCanvas(layer);
    if (imageBytes) {
      try {
        // Check if this is raw RGBA pixel data (length = w * h * 4)
        if (imageBytes.length === w * h * 4) {
          const image = figma.createImage(imageBytes);
          rect.fills = [{
            type: 'IMAGE',
            imageHash: image.hash,
            scaleMode: 'FILL',
          }];
        } else {
          // PNG encoded data
          const image = figma.createImage(imageBytes);
          rect.fills = [{
            type: 'IMAGE',
            imageHash: image.hash,
            scaleMode: 'FILL',
          }];
        }
      } catch (_e) {
        // If image creation fails, use a placeholder color
        rect.fills = [{ type: 'SOLID', color: { r: 0.8, g: 0.8, b: 0.8 }, opacity: 0.5 }];
      }
    }

    if (options.preserveOpacity && layer.opacity !== undefined) {
      rect.opacity = layer.opacity;
    }

    if (layer.hidden) {
      rect.visible = false;
    }

    applyBlendMode(rect, layer.blendMode);
    return rect;
  }

  // Shape layer with vector mask or path
  if (layer.vectorMask || layer.mask) {
    const rect = figma.createRectangle();
    rect.name = name;
    parent.appendChild(rect);

    if (layer.left !== undefined && layer.top !== undefined) {
      rect.x = layer.left;
      rect.y = layer.top;
    }

    const w = (layer.right ?? 0) - (layer.left ?? 0);
    const h = (layer.bottom ?? 0) - (layer.top ?? 0);
    rect.resize(Math.max(1, w), Math.max(1, h));

    // Apply solid color if available
    if (layer.effectsOpenResourceEffects || layer.vectorFill) {
      rect.fills = [{ type: 'SOLID', color: { r: 0.5, g: 0.5, b: 0.5 } }];
    }

    if (options.preserveOpacity && layer.opacity !== undefined) {
      rect.opacity = layer.opacity;
    }

    if (layer.hidden) {
      rect.visible = false;
    }

    applyBlendMode(rect, layer.blendMode);
    return rect;
  }

  // Fallback: create a rectangle placeholder for any other layer type
  if (layer.left !== undefined && layer.top !== undefined &&
      layer.right !== undefined && layer.bottom !== undefined) {
    const w = layer.right - layer.left;
    const h = layer.bottom - layer.top;

    if (w > 0 && h > 0) {
      const rect = figma.createRectangle();
      rect.name = name;
      parent.appendChild(rect);
      rect.x = layer.left;
      rect.y = layer.top;
      rect.resize(w, h);
      rect.fills = [{ type: 'SOLID', color: { r: 0.9, g: 0.9, b: 0.9 }, opacity: 0.3 }];

      if (options.preserveOpacity && layer.opacity !== undefined) {
        rect.opacity = layer.opacity;
      }

      if (layer.hidden) {
        rect.visible = false;
      }

      applyBlendMode(rect, layer.blendMode);
      return rect;
    }
  }

  return null;
}

function countLayers(layers: PsdLayer[]): number {
  let count = 0;
  for (const layer of layers) {
    count++;
    if (layer.children) {
      count += countLayers(layer.children);
    }
  }
  return count;
}

figma.ui.onmessage = async (msg: PluginMessage) => {
  if (msg.type !== 'import-psd' || !msg.data) return;

  const options: ImportOptions = msg.options || {
    importText: true,
    preserveOpacity: true,
    importHidden: false,
  };

  try {
    sendProgress(55, 'Parsing PSD...');

    // Parse the PSD file
    const psd: Psd = readPsd(msg.data, {
      skipCompositeImageData: false,
      skipLayerImageData: false,
      skipThumbnail: true,
    });

    if (!psd) {
      sendError('Falha ao interpretar o arquivo PSD.');
      return;
    }

    sendProgress(65, 'Criando estrutura no Figma...');

    const page = figma.currentPage;

    // Create a main frame for the PSD
    const mainFrame = figma.createFrame();
    mainFrame.name = msg.fileName?.replace(/\.(psd|psb)$/i, '') || 'PSD Import';
    page.appendChild(mainFrame);

    const psdWidth = psd.width || 1920;
    const psdHeight = psd.height || 1080;
    mainFrame.resize(psdWidth, psdHeight);
    mainFrame.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }];
    mainFrame.clipsContent = true;

    // Import background/composite image if available
    if (psd.canvas) {
      try {
        const bgBytes = await imageFromCanvas(psd as unknown as PsdLayer);
        if (bgBytes) {
          const bgRect = figma.createRectangle();
          bgRect.name = 'Background (Composite)';
          mainFrame.appendChild(bgRect);
          bgRect.resize(psdWidth, psdHeight);
          bgRect.x = 0;
          bgRect.y = 0;

          const image = figma.createImage(bgBytes);
          bgRect.fills = [{
            type: 'IMAGE',
            imageHash: image.hash,
            scaleMode: 'FILL',
          }];
          bgRect.locked = true;
          bgRect.visible = false; // Hidden by default, layers take priority
        }
      } catch (_e) {
        // Composite image is optional
      }
    }

    // Process layers
    const layers = psd.children || [];
    const totalLayers = countLayers(layers);
    let processedLayers = 0;

    async function processLayerWithProgress(
      layer: PsdLayer,
      parent: FrameNode | GroupNode | PageNode,
    ): Promise<void> {
      await createLayerNode(layer, parent, options);
      processedLayers++;

      const percent = 65 + Math.round((processedLayers / Math.max(totalLayers, 1)) * 30);
      if (processedLayers % 5 === 0 || processedLayers === totalLayers) {
        sendProgress(
          Math.min(percent, 95),
          `Importando camada ${processedLayers}/${totalLayers}...`
        );
      }
    }

    // Process all top-level layers (PSD layers are bottom-to-top, Figma is top-to-bottom)
    for (let i = layers.length - 1; i >= 0; i--) {
      await processLayerWithProgress(layers[i], mainFrame);
    }

    // Center the frame in viewport
    figma.viewport.scrollAndZoomIntoView([mainFrame]);

    sendProgress(100, 'Concluído!');
    sendDone(
      `Importado com sucesso! ${totalLayers} camadas de "${msg.fileName}"`
    );

    // Select the imported frame
    figma.currentPage.selection = [mainFrame];

  } catch (err: any) {
    const message = err?.message || 'Erro desconhecido';
    sendError(`Erro ao importar: ${message}`);
    console.error('PSD Import Error:', err);
  }
};
