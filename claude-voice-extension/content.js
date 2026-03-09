// Claude Voice Extension — Content Script
// Transcreve áudio → envia para Claude → lê resposta em voz alta
// 100% gratuito, usa Web Speech API nativa do navegador

(function () {
  'use strict';

  // ── Settings (loaded from chrome.storage) ──
  const DEFAULT_SETTINGS = {
    language: 'pt-BR',
    voiceName: '',
    speechRate: 1.0,
    autoSubmit: true,
    autoRead: true,
    silenceTimeout: 2000,
    readCodeBlocks: false,
    shortcutKey: 'Space',
  };

  let settings = { ...DEFAULT_SETTINGS };
  let isListening = false;
  let isSpeaking = false;
  let recognition = null;
  let silenceTimer = null;
  let finalTranscript = '';
  let lastResponseCount = 0;
  let observer = null;

  // ── Load Settings ──
  function loadSettings() {
    if (chrome?.storage?.sync) {
      chrome.storage.sync.get(DEFAULT_SETTINGS, (stored) => {
        settings = { ...DEFAULT_SETTINGS, ...stored };
      });
      chrome.storage.onChanged.addListener((changes) => {
        for (const [key, { newValue }] of Object.entries(changes)) {
          if (key in settings) settings[key] = newValue;
        }
      });
    }
  }

  // ── Create UI ──
  function createUI() {
    const container = document.createElement('div');
    container.id = 'claude-voice-container';

    // Transcript bubble
    const transcript = document.createElement('div');
    transcript.id = 'claude-voice-transcript';

    // Stop TTS button
    const stopBtn = document.createElement('button');
    stopBtn.id = 'claude-voice-stop-btn';
    stopBtn.title = 'Parar leitura';
    stopBtn.innerHTML = `<svg viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="2"/></svg>`;
    stopBtn.addEventListener('click', stopSpeaking);

    // Mic button
    const micBtn = document.createElement('button');
    micBtn.id = 'claude-voice-mic-btn';
    micBtn.title = 'Clique para falar (ou pressione Espaço)';
    micBtn.innerHTML = `<svg viewBox="0 0 24 24">
      <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/>
      <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/>
    </svg>`;
    micBtn.addEventListener('click', toggleListening);

    // Status
    const status = document.createElement('div');
    status.id = 'claude-voice-status';

    container.appendChild(transcript);
    container.appendChild(status);
    container.appendChild(stopBtn);
    container.appendChild(micBtn);
    document.body.appendChild(container);

    // Make draggable
    makeDraggable(container, micBtn);

    return { container, micBtn, transcript, stopBtn, status };
  }

  // ── Draggable ──
  function makeDraggable(container, handle) {
    let isDragging = false;
    let startX, startY, startRight, startBottom;

    handle.addEventListener('mousedown', (e) => {
      if (e.button !== 0) return;
      isDragging = false;
      startX = e.clientX;
      startY = e.clientY;
      startRight = parseInt(container.style.right || 24);
      startBottom = parseInt(container.style.bottom || 100);

      const onMove = (e) => {
        const dx = e.clientX - startX;
        const dy = e.clientY - startY;
        if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
          isDragging = true;
          container.classList.add('dragging');
          container.style.right = Math.max(8, startRight - dx) + 'px';
          container.style.bottom = Math.max(8, startBottom - dy) + 'px';
        }
      };

      const onUp = () => {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
        container.classList.remove('dragging');
        if (isDragging) {
          // Prevent click when dragging
          handle.addEventListener('click', (e) => e.stopImmediatePropagation(), { once: true, capture: true });
        }
      };

      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }

  // ── Speech-to-Text ──
  function initRecognition() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      showStatus('SpeechRecognition não suportado neste navegador');
      return null;
    }

    const rec = new SpeechRecognition();
    rec.continuous = true;
    rec.interimResults = true;
    rec.lang = settings.language;
    rec.maxAlternatives = 1;

    rec.onresult = (event) => {
      let interim = '';
      finalTranscript = '';

      for (let i = 0; i < event.results.length; i++) {
        const result = event.results[i];
        if (result.isFinal) {
          finalTranscript += result[0].transcript;
        } else {
          interim += result[0].transcript;
        }
      }

      updateTranscript(finalTranscript, interim);

      // Reset silence timer
      clearTimeout(silenceTimer);
      if (finalTranscript.trim()) {
        silenceTimer = setTimeout(() => {
          if (isListening && settings.autoSubmit) {
            stopListening();
            sendMessage(finalTranscript.trim());
          }
        }, settings.silenceTimeout);
      }
    };

    rec.onerror = (event) => {
      if (event.error === 'no-speech') return; // Normal, ignore
      if (event.error === 'aborted') return;
      console.warn('Claude Voice — STT error:', event.error);
      showStatus(`Erro: ${event.error}`);
    };

    rec.onend = () => {
      // Auto-restart if still in listening mode
      if (isListening) {
        try {
          rec.lang = settings.language;
          rec.start();
        } catch (e) {
          console.warn('Claude Voice — restart failed:', e);
          stopListening();
        }
      }
    };

    return rec;
  }

  function toggleListening() {
    if (isSpeaking) {
      stopSpeaking();
      return;
    }
    if (isListening) {
      stopListening();
      if (finalTranscript.trim()) {
        sendMessage(finalTranscript.trim());
      }
    } else {
      startListening();
    }
  }

  function startListening() {
    if (isListening) return;
    if (isSpeaking) stopSpeaking();

    recognition = initRecognition();
    if (!recognition) return;

    try {
      recognition.start();
      isListening = true;
      finalTranscript = '';
      ui.micBtn.classList.add('listening');
      ui.micBtn.classList.remove('speaking');
      ui.transcript.classList.add('visible');
      ui.transcript.textContent = 'Ouvindo...';
      showStatus('Fale agora');
    } catch (e) {
      console.error('Claude Voice — start error:', e);
      showStatus('Erro ao iniciar microfone');
    }
  }

  function stopListening() {
    if (!isListening) return;
    isListening = false;
    clearTimeout(silenceTimer);

    if (recognition) {
      try { recognition.stop(); } catch (e) { /* ignore */ }
      recognition = null;
    }

    ui.micBtn.classList.remove('listening');
    setTimeout(() => {
      ui.transcript.classList.remove('visible');
    }, 1500);
    hideStatus();
  }

  function updateTranscript(final, interim) {
    const el = ui.transcript;
    el.innerHTML = '';
    if (final) {
      const span = document.createElement('span');
      span.textContent = final;
      el.appendChild(span);
    }
    if (interim) {
      const span = document.createElement('span');
      span.className = 'interim';
      span.textContent = (final ? ' ' : '') + interim;
      el.appendChild(span);
    }
    if (!final && !interim) {
      el.textContent = 'Ouvindo...';
    }
  }

  // ── DOM Interaction with claude.ai ──
  function findInputField() {
    // Claude.ai uses contenteditable div or textarea — try multiple selectors
    const selectors = [
      '[contenteditable="true"].ProseMirror',
      '[contenteditable="true"]',
      'div.ProseMirror',
      'textarea',
      '[data-placeholder]',
    ];
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      if (el && isVisible(el)) return el;
    }
    return null;
  }

  function findSendButton() {
    const selectors = [
      'button[aria-label="Send Message"]',
      'button[aria-label="Enviar mensagem"]',
      'button[aria-label="Send message"]',
      'button[type="submit"]',
      'button[data-testid="send-button"]',
    ];
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      if (el) return el;
    }

    // Fallback: find send button by SVG path or position
    const buttons = document.querySelectorAll('button');
    for (const btn of buttons) {
      const svg = btn.querySelector('svg');
      if (svg && btn.closest('[class*="composer"], [class*="input"], form')) {
        const rect = btn.getBoundingClientRect();
        if (rect.width > 0 && rect.bottom > window.innerHeight * 0.5) {
          return btn;
        }
      }
    }
    return null;
  }

  function isVisible(el) {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function sendMessage(text) {
    const input = findInputField();
    if (!input) {
      showStatus('Campo de texto não encontrado');
      return;
    }

    // Insert text into input field
    if (input.contentEditable === 'true') {
      // For contenteditable (ProseMirror)
      input.focus();

      // Create a paragraph with the text
      const p = document.createElement('p');
      p.textContent = text;

      // Clear existing content and insert
      input.innerHTML = '';
      input.appendChild(p);

      // Dispatch input events to trigger framework reactivity
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
    } else {
      // For regular textarea
      input.focus();
      input.value = text;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
    }

    // Wait a bit for the framework to process, then click send
    setTimeout(() => {
      const sendBtn = findSendButton();
      if (sendBtn && !sendBtn.disabled) {
        sendBtn.click();
        showStatus('Mensagem enviada');
        setTimeout(hideStatus, 2000);
      } else {
        // Try pressing Enter
        input.dispatchEvent(new KeyboardEvent('keydown', {
          key: 'Enter',
          code: 'Enter',
          keyCode: 13,
          which: 13,
          bubbles: true,
        }));
        showStatus('Mensagem enviada');
        setTimeout(hideStatus, 2000);
      }
    }, 300);
  }

  // ── Response Detection ──
  function getResponseElements() {
    // Claude.ai response containers — try multiple selectors
    const selectors = [
      '[data-testid="chat-message-content"]',
      '[class*="message"][class*="assistant"]',
      '.font-claude-message',
      '[data-is-streaming]',
    ];

    for (const sel of selectors) {
      const els = document.querySelectorAll(sel);
      if (els.length > 0) return Array.from(els);
    }

    // Broader fallback: look for message groups
    const groups = document.querySelectorAll('[class*="response"], [class*="message"]');
    return Array.from(groups).filter(el => {
      const text = el.textContent?.trim();
      return text && text.length > 10;
    });
  }

  function isStreaming() {
    // Detect if Claude is still generating
    const indicators = [
      '[data-is-streaming="true"]',
      '.result-streaming',
      '[class*="streaming"]',
      '[class*="typing"]',
      'button[aria-label="Stop"] , button[aria-label="Parar"]',
    ];
    for (const sel of indicators) {
      if (document.querySelector(sel)) return true;
    }
    return false;
  }

  function getLastResponseText() {
    const responses = getResponseElements();
    if (responses.length === 0) return '';

    const lastResponse = responses[responses.length - 1];
    let text = '';

    if (settings.readCodeBlocks) {
      text = lastResponse.textContent || '';
    } else {
      // Skip code blocks
      const clone = lastResponse.cloneNode(true);
      clone.querySelectorAll('pre, code, .code-block').forEach(el => el.remove());
      text = clone.textContent || '';
    }

    return text.trim();
  }

  function startObserver() {
    if (observer) observer.disconnect();

    let debounceTimer = null;
    let wasStreaming = false;

    observer = new MutationObserver(() => {
      const streaming = isStreaming();

      if (streaming) {
        wasStreaming = true;
        clearTimeout(debounceTimer);
        return;
      }

      if (wasStreaming && !streaming) {
        // Just finished streaming
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          wasStreaming = false;
          onNewResponse();
        }, 500);
      }
    });

    // Observe the main content area
    const target = document.querySelector('main') || document.body;
    observer.observe(target, {
      childList: true,
      subtree: true,
      characterData: true,
    });

    // Also check periodically for response changes (backup)
    setInterval(() => {
      const responses = getResponseElements();
      if (responses.length > lastResponseCount) {
        lastResponseCount = responses.length;
        // Wait for streaming to finish
        const checkDone = () => {
          if (!isStreaming()) {
            setTimeout(onNewResponse, 800);
          } else {
            setTimeout(checkDone, 500);
          }
        };
        setTimeout(checkDone, 1000);
      }
    }, 2000);
  }

  function onNewResponse() {
    if (!settings.autoRead) return;
    if (isListening) return; // Don't read while user is talking

    const text = getLastResponseText();
    if (text && text.length > 5) {
      speakText(text);
    }
  }

  // ── Text-to-Speech ──
  function speakText(text) {
    if (isSpeaking) stopSpeaking();

    const synth = window.speechSynthesis;
    if (!synth) {
      showStatus('SpeechSynthesis não suportado');
      return;
    }

    // Split long text into chunks at sentence boundaries
    const chunks = splitIntoChunks(text, 200);

    isSpeaking = true;
    ui.micBtn.classList.add('speaking');
    ui.stopBtn.classList.add('visible');

    let chunkIndex = 0;

    function speakNext() {
      if (chunkIndex >= chunks.length || !isSpeaking) {
        stopSpeaking();
        return;
      }

      const utterance = new SpeechSynthesisUtterance(chunks[chunkIndex]);
      utterance.lang = settings.language;
      utterance.rate = settings.speechRate;

      // Set voice if specified
      if (settings.voiceName) {
        const voices = synth.getVoices();
        const voice = voices.find(v => v.name === settings.voiceName);
        if (voice) utterance.voice = voice;
      }

      utterance.onend = () => {
        chunkIndex++;
        speakNext();
      };

      utterance.onerror = (e) => {
        if (e.error !== 'interrupted') {
          console.warn('Claude Voice — TTS error:', e.error);
        }
        stopSpeaking();
      };

      synth.speak(utterance);
    }

    speakNext();
  }

  function splitIntoChunks(text, maxLength) {
    const chunks = [];
    // Split by sentences first
    const sentences = text.match(/[^.!?\n]+[.!?\n]*/g) || [text];

    let current = '';
    for (const sentence of sentences) {
      if ((current + sentence).length > maxLength && current) {
        chunks.push(current.trim());
        current = sentence;
      } else {
        current += sentence;
      }
    }
    if (current.trim()) chunks.push(current.trim());

    // Further split any chunks that are still too long
    const result = [];
    for (const chunk of chunks) {
      if (chunk.length > maxLength) {
        // Split by comma or space
        const words = chunk.split(/(?<=\s)/);
        let part = '';
        for (const word of words) {
          if ((part + word).length > maxLength && part) {
            result.push(part.trim());
            part = word;
          } else {
            part += word;
          }
        }
        if (part.trim()) result.push(part.trim());
      } else {
        result.push(chunk);
      }
    }
    return result;
  }

  function stopSpeaking() {
    isSpeaking = false;
    window.speechSynthesis?.cancel();
    ui.micBtn.classList.remove('speaking');
    ui.stopBtn.classList.remove('visible');
  }

  // ── Status ──
  function showStatus(msg) {
    if (ui?.status) {
      ui.status.textContent = msg;
      ui.status.classList.add('visible');
    }
  }

  function hideStatus() {
    if (ui?.status) {
      ui.status.classList.remove('visible');
    }
  }

  // ── Keyboard Shortcut ──
  function initShortcut() {
    document.addEventListener('keydown', (e) => {
      // Alt + Space to toggle mic (don't interfere with normal typing)
      if (e.altKey && e.code === 'Space') {
        e.preventDefault();
        toggleListening();
      }
      // Escape to stop TTS
      if (e.key === 'Escape' && isSpeaking) {
        stopSpeaking();
      }
    });
  }

  // ── Init ──
  let ui;

  function init() {
    // Don't initialize if already present
    if (document.getElementById('claude-voice-container')) return;

    loadSettings();
    ui = createUI();
    initShortcut();

    // Wait for page to fully load, then start observer
    setTimeout(() => {
      lastResponseCount = getResponseElements().length;
      startObserver();
    }, 2000);

    console.log('Claude Voice Extension — Ativo! Alt+Espaço para ativar/desativar mic.');
  }

  // Start when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
