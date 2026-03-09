// Claude Voice — Popup Settings

const FIELDS = {
  language: { type: 'select', default: 'pt-BR' },
  voiceName: { type: 'select', default: '' },
  speechRate: { type: 'range', default: 1.0, display: 'rateValue', format: v => v + 'x' },
  autoSubmit: { type: 'checkbox', default: true },
  autoRead: { type: 'checkbox', default: true },
  readCodeBlocks: { type: 'checkbox', default: false },
  silenceTimeout: { type: 'range', default: 2000, display: 'silenceValue', format: v => (v / 1000) + 's' },
};

// Load settings and populate UI
document.addEventListener('DOMContentLoaded', () => {
  loadVoices();
  loadSettings();
  attachListeners();
});

function loadVoices() {
  const select = document.getElementById('voiceName');
  const populateVoices = () => {
    const voices = speechSynthesis.getVoices();
    // Keep the default option
    while (select.options.length > 1) select.remove(1);

    voices.forEach(voice => {
      const option = document.createElement('option');
      option.value = voice.name;
      option.textContent = `${voice.name} (${voice.lang})`;
      select.appendChild(option);
    });
  };

  populateVoices();
  speechSynthesis.onvoiceschanged = populateVoices;
}

function loadSettings() {
  const defaults = {};
  for (const [key, field] of Object.entries(FIELDS)) {
    defaults[key] = field.default;
  }

  chrome.storage.sync.get(defaults, (stored) => {
    for (const [key, field] of Object.entries(FIELDS)) {
      const el = document.getElementById(key);
      if (!el) continue;

      const value = stored[key];
      if (field.type === 'checkbox') {
        el.checked = value;
      } else if (field.type === 'range') {
        el.value = value;
        if (field.display) {
          document.getElementById(field.display).textContent = field.format(value);
        }
      } else {
        el.value = value;
      }
    }
  });
}

function attachListeners() {
  for (const [key, field] of Object.entries(FIELDS)) {
    const el = document.getElementById(key);
    if (!el) continue;

    const event = field.type === 'range' ? 'input' : 'change';
    el.addEventListener(event, () => {
      let value;
      if (field.type === 'checkbox') {
        value = el.checked;
      } else if (field.type === 'range') {
        value = parseFloat(el.value);
        if (field.display) {
          document.getElementById(field.display).textContent = field.format(value);
        }
      } else {
        value = el.value;
      }

      chrome.storage.sync.set({ [key]: value });
      showSaved();
    });
  }
}

function showSaved() {
  const status = document.getElementById('status');
  status.textContent = 'Salvo!';
  status.style.opacity = '1';
  setTimeout(() => {
    status.style.opacity = '0.6';
  }, 1500);
}
