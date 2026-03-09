import { buildSync } from 'esbuild';
import { writeFileSync } from 'fs';

// 1. Build plugin code (runs in Figma sandbox)
buildSync({
  entryPoints: ['code.ts'],
  bundle: true,
  outfile: 'code.js',
  target: 'es2017',
  format: 'iife',
  platform: 'browser',
});
console.log('Built code.js');

// 2. Build UI JavaScript (runs in browser iframe) — bundle ag-psd inline
const uiResult = buildSync({
  entryPoints: ['ui-src.ts'],
  bundle: true,
  write: false,
  target: 'es2017',
  format: 'iife',
  platform: 'browser',
  minify: true,
});
const uiJs = uiResult.outputFiles[0].text;
console.log(`Built UI JS (${(uiJs.length / 1024).toFixed(0)}kb)`);

// 3. Generate ui.html with inlined JS
const html = `<!DOCTYPE html>
<html>
<head>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      background: #1e1e1e;
      color: #e0e0e0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
    }

    h2 { font-size: 16px; font-weight: 600; margin-bottom: 16px; color: #fff; }

    .drop-zone {
      position: relative;
      display: flex;
      flex-direction: column;
      align-items: center;
      width: 100%;
      max-width: 360px;
      border: 2px dashed #555;
      border-radius: 12px;
      padding: 40px 24px;
      text-align: center;
      cursor: pointer;
      transition: all 0.2s;
      background: #2a2a2a;
    }

    .drop-zone:hover, .drop-zone.dragover {
      border-color: #a259ff;
      background: #332244;
    }

    .drop-zone p { font-size: 14px; color: #aaa; margin-top: 8px; }
    .drop-zone .icon { font-size: 36px; margin-bottom: 8px; }

    input[type="file"] {
      position: absolute;
      width: 0;
      height: 0;
      opacity: 0;
      pointer-events: none;
    }

    .status {
      margin-top: 16px;
      font-size: 13px;
      color: #aaa;
      text-align: center;
      min-height: 20px;
    }

    .status.error { color: #ff6b6b; }
    .status.success { color: #51cf66; }

    .progress-bar {
      width: 100%;
      max-width: 360px;
      height: 4px;
      background: #333;
      border-radius: 2px;
      margin-top: 12px;
      overflow: hidden;
      display: none;
    }

    .progress-bar.active { display: block; }

    .progress-bar .fill {
      height: 100%;
      background: #a259ff;
      border-radius: 2px;
      transition: width 0.3s;
      width: 0%;
    }

    .options { margin-top: 16px; width: 100%; max-width: 360px; }

    .option-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 0;
      font-size: 13px;
    }

    .option-row label { color: #ccc; }

    .toggle { position: relative; width: 36px; height: 20px; }
    .toggle input { opacity: 0; width: 0; height: 0; }

    .toggle .slider {
      position: absolute;
      cursor: pointer;
      top: 0; left: 0; right: 0; bottom: 0;
      background-color: #555;
      border-radius: 20px;
      transition: 0.2s;
    }

    .toggle .slider:before {
      content: "";
      position: absolute;
      height: 14px;
      width: 14px;
      left: 3px;
      bottom: 3px;
      background-color: white;
      border-radius: 50%;
      transition: 0.2s;
    }

    .toggle input:checked + .slider { background-color: #a259ff; }
    .toggle input:checked + .slider:before { transform: translateX(16px); }

    .footer { margin-top: 24px; font-size: 11px; color: #666; }
  </style>
</head>
<body>
  <h2>PSD Importer</h2>

  <label class="drop-zone" id="dropZone" for="fileInput">
    <div class="icon">&#128193;</div>
    <strong>Arraste um arquivo .psd aqui</strong>
    <p>ou clique para selecionar</p>
    <input type="file" id="fileInput" accept=".psd,.psb" />
  </label>

  <div class="options">
    <div class="option-row">
      <label>Importar textos como editaveis</label>
      <label class="toggle">
        <input type="checkbox" id="optText" checked />
        <span class="slider"></span>
      </label>
    </div>
    <div class="option-row">
      <label>Preservar opacidade das camadas</label>
      <label class="toggle">
        <input type="checkbox" id="optOpacity" checked />
        <span class="slider"></span>
      </label>
    </div>
    <div class="option-row">
      <label>Importar camadas ocultas</label>
      <label class="toggle">
        <input type="checkbox" id="optHidden" />
        <span class="slider"></span>
      </label>
    </div>
  </div>

  <div class="progress-bar" id="progressBar">
    <div class="fill" id="progressFill"></div>
  </div>

  <div class="status" id="status"></div>

  <div class="footer">Open Source &mdash; ag-psd + Figma Plugin API</div>

  <script>${uiJs}</script>
</body>
</html>`;

writeFileSync('ui.html', html, 'utf8');
console.log('Built ui.html (with inlined ag-psd)');
console.log('Done!');
