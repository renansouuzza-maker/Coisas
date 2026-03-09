"use strict";
(() => {
  // code.ts
  figma.showUI(__html__, { width: 420, height: 460 });
  function sendProgress(percent, message) {
    figma.ui.postMessage({ type: "progress", percent, message });
  }
  function sendDone(message) {
    figma.ui.postMessage({ type: "done", message });
  }
  function sendError(message) {
    figma.ui.postMessage({ type: "error", message });
  }
  function applyBlendMode(node, blendMode) {
    if (!blendMode)
      return;
    const modeMap = {
      "normal": "NORMAL",
      "dissolve": "NORMAL",
      "darken": "DARKEN",
      "multiply": "MULTIPLY",
      "color burn": "COLOR_BURN",
      "linear burn": "LINEAR_BURN",
      "darker color": "DARKEN",
      "lighten": "LIGHTEN",
      "screen": "SCREEN",
      "color dodge": "COLOR_DODGE",
      "linear dodge": "LINEAR_DODGE",
      "lighter color": "LIGHTEN",
      "overlay": "OVERLAY",
      "soft light": "SOFT_LIGHT",
      "hard light": "HARD_LIGHT",
      "vivid light": "HARD_LIGHT",
      "linear light": "LINEAR_BURN",
      "pin light": "HARD_LIGHT",
      "hard mix": "HARD_LIGHT",
      "difference": "DIFFERENCE",
      "exclusion": "EXCLUSION",
      "subtract": "EXCLUSION",
      "divide": "NORMAL",
      "hue": "HUE",
      "saturation": "SATURATION",
      "color": "COLOR",
      "luminosity": "LUMINOSITY"
    };
    const key = blendMode.toLowerCase();
    if (key in modeMap && "blendMode" in node) {
      node.blendMode = modeMap[key];
    }
  }
  async function createLayerNode(layer, parent, options) {
    if (layer.hidden && !options.importHidden) {
      return null;
    }
    const name = layer.name || "Layer";
    if (layer.children && layer.children.length > 0) {
      const frame = figma.createFrame();
      frame.name = name;
      parent.appendChild(frame);
      frame.fills = [];
      if (layer.left !== void 0 && layer.top !== void 0) {
        frame.x = layer.left;
        frame.y = layer.top;
      }
      if (layer.right !== void 0 && layer.left !== void 0 && layer.bottom !== void 0 && layer.top !== void 0) {
        const w = layer.right - layer.left;
        const h = layer.bottom - layer.top;
        if (w > 0 && h > 0) {
          frame.resize(w, h);
        }
      }
      frame.clipsContent = false;
      for (const child of layer.children) {
        const childNode = await createLayerNode(child, frame, options);
        if (childNode && layer.left !== void 0 && layer.top !== void 0) {
          childNode.x -= layer.left;
          childNode.y -= layer.top;
        }
      }
      if (options.preserveOpacity && layer.opacity !== void 0) {
        frame.opacity = layer.opacity;
      }
      if (layer.hidden) {
        frame.visible = false;
      }
      applyBlendMode(frame, layer.blendMode);
      return frame;
    }
    if (layer.text && options.importText) {
      const textNode = figma.createText();
      textNode.name = name;
      parent.appendChild(textNode);
      if (layer.left !== void 0 && layer.top !== void 0) {
        textNode.x = layer.left;
        textNode.y = layer.top;
      }
      try {
        let fontFamily = layer.text.fontName || "Inter";
        let fontStyle = "Regular";
        if (layer.text.fauxBold) {
          fontStyle = "Bold";
        }
        if (layer.text.fauxItalic) {
          fontStyle = fontStyle === "Bold" ? "Bold Italic" : "Italic";
        }
        try {
          await figma.loadFontAsync({ family: fontFamily, style: fontStyle });
        } catch (_e) {
          await figma.loadFontAsync({ family: "Inter", style: "Regular" });
          fontFamily = "Inter";
          fontStyle = "Regular";
        }
        textNode.characters = layer.text.value || name;
        textNode.fontName = { family: fontFamily, style: fontStyle };
        if (layer.text.fontSize) {
          textNode.fontSize = layer.text.fontSize;
        }
        if (layer.text.fillColor) {
          const c = layer.text.fillColor;
          textNode.fills = [{
            type: "SOLID",
            color: { r: c.r, g: c.g, b: c.b },
            opacity: c.a
          }];
        }
      } catch (_e) {
        try {
          await figma.loadFontAsync({ family: "Inter", style: "Regular" });
          textNode.characters = layer.text.value || name;
        } catch (_e2) {
        }
      }
      if (options.preserveOpacity && layer.opacity !== void 0) {
        textNode.opacity = layer.opacity;
      }
      if (layer.hidden) {
        textNode.visible = false;
      }
      applyBlendMode(textNode, layer.blendMode);
      return textNode;
    }
    if (layer.imageBytes && layer.imageBytes.length > 0) {
      const w = layer.imageWidth || 1;
      const h = layer.imageHeight || 1;
      const rect = figma.createRectangle();
      rect.name = name;
      parent.appendChild(rect);
      if (layer.left !== void 0 && layer.top !== void 0) {
        rect.x = layer.left;
        rect.y = layer.top;
      }
      rect.resize(Math.max(1, w), Math.max(1, h));
      try {
        const image = figma.createImage(new Uint8Array(layer.imageBytes));
        rect.fills = [{
          type: "IMAGE",
          imageHash: image.hash,
          scaleMode: "FILL"
        }];
      } catch (_e) {
        rect.fills = [{ type: "SOLID", color: { r: 0.8, g: 0.8, b: 0.8 }, opacity: 0.5 }];
      }
      if (options.preserveOpacity && layer.opacity !== void 0) {
        rect.opacity = layer.opacity;
      }
      if (layer.hidden) {
        rect.visible = false;
      }
      applyBlendMode(rect, layer.blendMode);
      return rect;
    }
    if (layer.hasVectorMask || layer.hasMask) {
      const rect = figma.createRectangle();
      rect.name = name;
      parent.appendChild(rect);
      if (layer.left !== void 0 && layer.top !== void 0) {
        rect.x = layer.left;
        rect.y = layer.top;
      }
      const w = (layer.right || 0) - (layer.left || 0);
      const h = (layer.bottom || 0) - (layer.top || 0);
      rect.resize(Math.max(1, w), Math.max(1, h));
      rect.fills = [{ type: "SOLID", color: { r: 0.5, g: 0.5, b: 0.5 } }];
      if (options.preserveOpacity && layer.opacity !== void 0) {
        rect.opacity = layer.opacity;
      }
      if (layer.hidden) {
        rect.visible = false;
      }
      applyBlendMode(rect, layer.blendMode);
      return rect;
    }
    if (layer.left !== void 0 && layer.top !== void 0 && layer.right !== void 0 && layer.bottom !== void 0) {
      const w = layer.right - layer.left;
      const h = layer.bottom - layer.top;
      if (w > 0 && h > 0) {
        const rect = figma.createRectangle();
        rect.name = name;
        parent.appendChild(rect);
        rect.x = layer.left;
        rect.y = layer.top;
        rect.resize(w, h);
        rect.fills = [{ type: "SOLID", color: { r: 0.9, g: 0.9, b: 0.9 }, opacity: 0.3 }];
        if (options.preserveOpacity && layer.opacity !== void 0) {
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
  function countLayers(layers) {
    let count = 0;
    for (const layer of layers) {
      count++;
      if (layer.children) {
        count += countLayers(layer.children);
      }
    }
    return count;
  }
  figma.ui.onmessage = async (msg) => {
    if (msg.type !== "import-psd-parsed")
      return;
    const data = msg;
    const options = data.options;
    try {
      sendProgress(78, "Criando estrutura no Figma...");
      const page = figma.currentPage;
      const mainFrame = figma.createFrame();
      mainFrame.name = data.fileName.replace(/\.(psd|psb)$/i, "") || "PSD Import";
      page.appendChild(mainFrame);
      mainFrame.resize(data.psdWidth, data.psdHeight);
      mainFrame.fills = [{ type: "SOLID", color: { r: 1, g: 1, b: 1 } }];
      mainFrame.clipsContent = true;
      if (data.compositeBytes && data.compositeBytes.length > 0) {
        try {
          const bgRect = figma.createRectangle();
          bgRect.name = "Background (Composite)";
          mainFrame.appendChild(bgRect);
          bgRect.resize(data.psdWidth, data.psdHeight);
          bgRect.x = 0;
          bgRect.y = 0;
          const image = figma.createImage(new Uint8Array(data.compositeBytes));
          bgRect.fills = [{
            type: "IMAGE",
            imageHash: image.hash,
            scaleMode: "FILL"
          }];
          bgRect.locked = true;
          bgRect.visible = false;
        } catch (_e) {
        }
      }
      const layers = data.layers || [];
      const totalLayers = countLayers(layers);
      let processedLayers = 0;
      async function processWithProgress(layer, parent) {
        await createLayerNode(layer, parent, options);
        processedLayers++;
        const percent = 78 + Math.round(processedLayers / Math.max(totalLayers, 1) * 20);
        if (processedLayers % 3 === 0 || processedLayers === totalLayers) {
          sendProgress(
            Math.min(percent, 98),
            "Criando camada " + processedLayers + "/" + totalLayers + "..."
          );
        }
      }
      for (let i = layers.length - 1; i >= 0; i--) {
        await processWithProgress(layers[i], mainFrame);
      }
      figma.viewport.scrollAndZoomIntoView([mainFrame]);
      figma.currentPage.selection = [mainFrame];
      sendDone("Importado com sucesso! " + totalLayers + ' camadas de "' + data.fileName + '"');
    } catch (err) {
      const message = err && err.message ? err.message : "Erro desconhecido";
      sendError("Erro ao importar: " + message);
    }
  };
})();
