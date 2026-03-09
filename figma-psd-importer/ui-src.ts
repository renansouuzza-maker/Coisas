import { readPsd, initializeCanvas } from 'ag-psd';

// Initialize ag-psd with browser Canvas
initializeCanvas(
  (width: number, height: number) => {
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    return canvas;
  },
  (src: string) => {
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error('Failed to load image'));
      img.src = src;
    });
  }
);

const dropZone = document.getElementById('dropZone')!;
const fileInput = document.getElementById('fileInput') as HTMLInputElement;
const statusEl = document.getElementById('status')!;
const progressBar = document.getElementById('progressBar')!;
const progressFill = document.getElementById('progressFill')!;

dropZone.addEventListener('dragover', (e) => {
  e.preventDefault();
  dropZone.classList.add('dragover');
});

dropZone.addEventListener('dragleave', () => {
  dropZone.classList.remove('dragover');
});

dropZone.addEventListener('drop', (e) => {
  e.preventDefault();
  dropZone.classList.remove('dragover');
  if (e.dataTransfer && e.dataTransfer.files[0]) {
    processFile(e.dataTransfer.files[0]);
  }
});

fileInput.addEventListener('change', () => {
  if (fileInput.files && fileInput.files[0]) {
    processFile(fileInput.files[0]);
  }
});

function setStatus(msg: string, type?: string) {
  statusEl.textContent = msg;
  statusEl.className = 'status' + (type ? ' ' + type : '');
}

function setProgress(percent: number) {
  progressFill.style.width = percent + '%';
}

async function canvasToPng(canvas: HTMLCanvasElement): Promise<Uint8Array | null> {
  if (!canvas) return null;
  try {
    const blob: Blob | null = await new Promise((resolve) => {
      canvas.toBlob(resolve, 'image/png');
    });
    if (!blob) return null;
    const buffer = await blob.arrayBuffer();
    return new Uint8Array(buffer);
  } catch (_e) {
    return null;
  }
}

interface SerializedLayer {
  name: string;
  left?: number;
  top?: number;
  right?: number;
  bottom?: number;
  opacity?: number;
  hidden: boolean;
  blendMode?: string;
  imageBytes: Uint8Array | null;
  imageWidth: number;
  imageHeight: number;
  text: any;
  hasVectorMask: boolean;
  hasMask: boolean;
  children: SerializedLayer[] | null;
}

async function serializeLayer(layer: any, onProgress?: () => void): Promise<SerializedLayer> {
  const result: SerializedLayer = {
    name: layer.name || 'Layer',
    left: layer.left,
    top: layer.top,
    right: layer.right,
    bottom: layer.bottom,
    opacity: layer.opacity,
    hidden: layer.hidden || false,
    blendMode: layer.blendMode,
    imageBytes: null,
    imageWidth: 0,
    imageHeight: 0,
    text: null,
    hasVectorMask: !!(layer.vectorMask),
    hasMask: !!(layer.mask),
    children: null,
  };

  if (layer.canvas) {
    const png = await canvasToPng(layer.canvas);
    if (png) {
      result.imageBytes = png;
      result.imageWidth = layer.canvas.width;
      result.imageHeight = layer.canvas.height;
    }
  }

  if (layer.text) {
    result.text = {
      value: layer.text.text || '',
      fontName: null,
      fontSize: null,
      fillColor: null,
      fauxBold: false,
      fauxItalic: false,
    };
    if (layer.text.style) {
      const s = layer.text.style;
      if (s.font && s.font.name) {
        result.text.fontName = s.font.name;
      }
      if (s.fontSize) {
        result.text.fontSize = s.fontSize;
      }
      if (s.fillColor) {
        result.text.fillColor = {
          r: s.fillColor.r || 0,
          g: s.fillColor.g || 0,
          b: s.fillColor.b || 0,
          a: s.fillColor.a !== undefined ? s.fillColor.a : 1,
        };
      }
      result.text.fauxBold = !!s.fauxBold;
      result.text.fauxItalic = !!s.fauxItalic;
    }
  }

  if (layer.children && layer.children.length > 0) {
    result.children = [];
    for (const child of layer.children) {
      const serialized = await serializeLayer(child, onProgress);
      result.children.push(serialized);
      if (onProgress) onProgress();
    }
  }

  return result;
}

function countLayers(layers: any[]): number {
  let count = 0;
  for (const l of layers) {
    count++;
    if (l.children) count += countLayers(l.children);
  }
  return count;
}

async function processFile(file: File) {
  if (!file.name.match(/\.(psd|psb)$/i)) {
    setStatus('Por favor, selecione um arquivo .psd ou .psb', 'error');
    return;
  }

  setStatus('Lendo arquivo...', '');
  progressBar.classList.add('active');
  setProgress(10);

  try {
    const arrayBuffer = await file.arrayBuffer();
    setProgress(25);
    setStatus('Parsing PSD (decodificando camadas)...', '');

    const psd = readPsd(new Uint8Array(arrayBuffer), {
      skipCompositeImageData: false,
      skipLayerImageData: false,
      skipThumbnail: true,
    });

    if (!psd) {
      setStatus('Falha ao interpretar o arquivo PSD.', 'error');
      progressBar.classList.remove('active');
      return;
    }

    setProgress(40);
    setStatus('Extraindo imagens das camadas...', '');

    const allLayers = psd.children || [];
    const totalLayers = countLayers(allLayers);
    let processed = 0;

    const onProgress = () => {
      processed++;
      const pct = 40 + Math.round((processed / Math.max(totalLayers, 1)) * 30);
      setProgress(Math.min(pct, 70));
      if (processed % 3 === 0) {
        setStatus('Extraindo camada ' + processed + '/' + totalLayers + '...', '');
      }
    };

    const serializedLayers: SerializedLayer[] = [];
    for (const layer of allLayers) {
      const s = await serializeLayer(layer, onProgress);
      serializedLayers.push(s);
    }

    let compositeBytes: Uint8Array | null = null;
    if (psd.canvas) {
      compositeBytes = await canvasToPng(psd.canvas as unknown as HTMLCanvasElement);
    }

    setProgress(75);
    setStatus('Enviando para o Figma...', '');

    const optText = document.getElementById('optText') as HTMLInputElement;
    const optOpacity = document.getElementById('optOpacity') as HTMLInputElement;
    const optHidden = document.getElementById('optHidden') as HTMLInputElement;

    const options = {
      importText: optText.checked,
      preserveOpacity: optOpacity.checked,
      importHidden: optHidden.checked,
    };

    parent.postMessage({
      pluginMessage: {
        type: 'import-psd-parsed',
        psdWidth: psd.width || 1920,
        psdHeight: psd.height || 1080,
        fileName: file.name,
        layers: serializedLayers,
        compositeBytes: compositeBytes,
        options: options,
      }
    }, '*');

  } catch (err: any) {
    setStatus('Erro ao processar: ' + (err.message || err), 'error');
    progressBar.classList.remove('active');
  }
}

window.onmessage = (event: MessageEvent) => {
  const msg = event.data.pluginMessage;
  if (!msg) return;

  if (msg.type === 'progress') {
    setProgress(msg.percent);
    setStatus(msg.message, '');
  } else if (msg.type === 'done') {
    setProgress(100);
    setStatus(msg.message, 'success');
    setTimeout(() => {
      progressBar.classList.remove('active');
    }, 2000);
  } else if (msg.type === 'error') {
    setStatus(msg.message, 'error');
    progressBar.classList.remove('active');
  }
};
