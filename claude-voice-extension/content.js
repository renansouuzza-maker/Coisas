// AI Voice Extension — Content Script
// Interface de voz para chats de IA (Claude, ChatGPT, Gemini, Copilot, etc)
// STT via offscreen document, TTS via SpeechSynthesis, DOM via MutationObserver

(function () {
  'use strict';

  // Prevent double-init
  if (document.getElementById('claude-voice-container')) return;

  // ── Site Detection ──
  const hostname = location.hostname;
  const SITE = detectSite();

  function detectSite() {
    if (hostname.includes('claude.ai')) return 'claude';
    if (hostname.includes('chatgpt.com') || hostname.includes('chat.openai.com')) return 'chatgpt';
    if (hostname.includes('gemini.google.com')) return 'gemini';
    if (hostname.includes('copilot.microsoft.com')) return 'copilot';
    if (hostname.includes('perplexity.ai')) return 'perplexity';
    if (hostname.includes('poe.com')) return 'poe';
    if (hostname.includes('chat.deepseek.com')) return 'deepseek';
    if (hostname.includes('chat.mistral.ai')) return 'mistral';
    if (hostname.includes('huggingface.co')) return 'huggingface';
    return 'generic';
  }

  // ── Site-specific selectors ──
  const SITE_CONFIG = {
    claude: {
      input: [
        'div.ProseMirror[contenteditable="true"]',
        '[contenteditable="true"][data-placeholder]',
      ],
      sendButton: [
        'button[aria-label="Send Message"]',
        'button[aria-label="Send message"]',
        'button[aria-label="Enviar mensagem"]',
        'button[data-testid="send-button"]',
      ],
      responseMessage: [
        '[data-testid^="chat-message-"]',
        '.font-claude-message',
      ],
      streamingIndicator: [
        '[data-is-streaming="true"]',
        'button[aria-label="Stop Response"]',
        'button[aria-label="Stop response"]',
        'button[aria-label="Parar resposta"]',
      ],
    },
    chatgpt: {
      input: [
        '#prompt-textarea',
        'div#prompt-textarea[contenteditable="true"]',
        'textarea[data-id="root"]',
      ],
      sendButton: [
        'button[data-testid="send-button"]',
        'button[aria-label="Send prompt"]',
        'button[aria-label="Enviar prompt"]',
        'form button[data-testid="send-button"]',
      ],
      responseMessage: [
        '[data-message-author-role="assistant"]',
        'div.agent-turn',
        '[class*="assistant"]',
      ],
      streamingIndicator: [
        'button[aria-label="Stop generating"]',
        'button[aria-label="Parar de gerar"]',
        '.result-streaming',
      ],
    },
    gemini: {
      input: [
        '.ql-editor[contenteditable="true"]',
        'div.input-area [contenteditable="true"]',
        'rich-textarea [contenteditable="true"]',
        '.text-input-field [contenteditable="true"]',
      ],
      sendButton: [
        'button.send-button',
        'button[aria-label="Send message"]',
        'button[aria-label="Enviar mensagem"]',
        '.send-button-container button',
      ],
      responseMessage: [
        'message-content.model-response-text',
        '.response-container .model-response-text',
        '.conversation-container .model-response',
        'model-response',
      ],
      streamingIndicator: [
        '.loading-indicator',
        '[class*="loading"]',
        'button[aria-label="Stop"]',
      ],
    },
    copilot: {
      input: [
        '#searchbox[contenteditable="true"]',
        'textarea#searchbox',
        '[contenteditable="true"]',
        'cib-text-input textarea',
      ],
      sendButton: [
        'button[aria-label="Submit"]',
        'button[aria-label="Enviar"]',
        'cib-icon-button[aria-label="Submit"]',
      ],
      responseMessage: [
        'cib-message[type="bot"]',
        '[data-content="ai-message"]',
        '.response-message-group',
      ],
      streamingIndicator: [
        'cib-typing-indicator',
        '[class*="typing"]',
        'button[aria-label="Stop Responding"]',
      ],
    },
    perplexity: {
      input: [
        'textarea[placeholder*="Ask"]',
        'textarea[placeholder*="Pergunt"]',
        'textarea',
      ],
      sendButton: [
        'button[aria-label="Submit"]',
        'button[aria-label="Enviar"]',
        'button[type="submit"]',
      ],
      responseMessage: [
        '.prose',
        '[class*="answer"]',
        '.markdown-content',
      ],
      streamingIndicator: [
        '[class*="loading"]',
        '.animate-pulse',
      ],
    },
    poe: {
      input: [
        'textarea[class*="TextArea"]',
        'textarea',
      ],
      sendButton: [
        'button[class*="SendButton"]',
        'button[class*="send"]',
      ],
      responseMessage: [
        '[class*="Message_botMessage"]',
        '[class*="bot_message"]',
      ],
      streamingIndicator: [
        '[class*="ChatStopMessage"]',
        'button[class*="stop"]',
      ],
    },
    deepseek: {
      input: [
        '#chat-input',
        'textarea[placeholder]',
        'textarea',
      ],
      sendButton: [
        'div[class*="send"] button',
        'button[class*="send"]',
        'button[aria-label*="Send"]',
      ],
      responseMessage: [
        '.markdown-body',
        '[class*="assistant"]',
        '[class*="bot-message"]',
      ],
      streamingIndicator: [
        '[class*="stop"]',
        '.loading',
      ],
    },
    mistral: {
      input: [
        'textarea',
        '[contenteditable="true"]',
      ],
      sendButton: [
        'button[type="submit"]',
        'button[aria-label*="Send"]',
      ],
      responseMessage: [
        '[class*="assistant"]',
        '.prose',
      ],
      streamingIndicator: [
        '[class*="stop"]',
        '[class*="loading"]',
      ],
    },
    huggingface: {
      input: [
        'textarea[placeholder]',
        'textarea',
      ],
      sendButton: [
        'button[type="submit"]',
        'button[class*="send"]',
      ],
      responseMessage: [
        '.message.bot',
        '[class*="bot"]',
        '.prose',
      ],
      streamingIndicator: [
        '[class*="stop"]',
        '.generating',
      ],
    },
    generic: {
      input: [
        '[contenteditable="true"]',
        'textarea',
      ],
      sendButton: [
        'button[type="submit"]',
        'button[aria-label*="Send"]',
        'button[aria-label*="send"]',
      ],
      responseMessage: [
        '[class*="assistant"]',
        '[class*="bot"]',
        '.prose',
        '.markdown',
      ],
      streamingIndicator: [
        '[class*="stop"]',
        '[class*="loading"]',
        '[class*="streaming"]',
      ],
    },
  };

  const config = SITE_CONFIG[SITE] || SITE_CONFIG.generic;

  // ── State Machine ──
  const State = {
    IDLE: 'idle',
    LISTENING: 'listening',
    SUBMITTING: 'submitting',
    WAITING: 'waiting',
    SPEAKING: 'speaking',
  };

  let state = State.IDLE;
  let finalTranscript = '';
  let silenceTimer = null;
  let responseObserver = null;
  let lastKnownResponseCount = 0;
  let ttsChromeBugTimer = null;

  // ── Settings ──
  const DEFAULT_SETTINGS = {
    language: 'pt-BR',
    voiceName: '',
    speechRate: 1.0,
    autoSubmit: true,
    autoRead: true,
    silenceTimeout: 2000,
    readCodeBlocks: false,
  };
  let settings = { ...DEFAULT_SETTINGS };

  function loadSettings() {
    if (chrome?.storage?.sync) {
      chrome.storage.sync.get(DEFAULT_SETTINGS, (s) => {
        settings = { ...DEFAULT_SETTINGS, ...s };
      });
      chrome.storage.onChanged.addListener((changes) => {
        for (const [key, { newValue }] of Object.entries(changes)) {
          if (key in settings) settings[key] = newValue;
        }
      });
    }
  }

  // ── UI ──
  let ui = {};

  function createUI() {
    const container = document.createElement('div');
    container.id = 'claude-voice-container';

    const transcript = document.createElement('div');
    transcript.id = 'claude-voice-transcript';

    const stopBtn = document.createElement('button');
    stopBtn.id = 'claude-voice-stop-btn';
    stopBtn.title = 'Parar leitura';
    stopBtn.innerHTML = '<svg viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="2"/></svg>';
    stopBtn.addEventListener('click', () => {
      stopSpeaking();
      setState(State.IDLE);
    });

    const micBtn = document.createElement('button');
    micBtn.id = 'claude-voice-mic-btn';
    micBtn.title = 'Clique para falar (Alt+Espaço)';
    micBtn.innerHTML = `<svg viewBox="0 0 24 24">
      <path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3z"/>
      <path d="M17 11c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/>
    </svg>`;
    micBtn.addEventListener('click', onMicClick);

    const status = document.createElement('div');
    status.id = 'claude-voice-status';

    container.appendChild(transcript);
    container.appendChild(status);
    container.appendChild(stopBtn);
    container.appendChild(micBtn);
    document.body.appendChild(container);

    makeDraggable(container, micBtn);

    ui = { container, micBtn, transcript, stopBtn, status };
  }

  function makeDraggable(container, handle) {
    let isDrag = false, sx, sy, sr, sb;

    handle.addEventListener('mousedown', (e) => {
      if (e.button !== 0) return;
      isDrag = false;
      sx = e.clientX; sy = e.clientY;
      sr = parseInt(getComputedStyle(container).right) || 24;
      sb = parseInt(getComputedStyle(container).bottom) || 100;

      const onMove = (e) => {
        const dx = e.clientX - sx, dy = e.clientY - sy;
        if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
          isDrag = true;
          container.classList.add('dragging');
          container.style.right = Math.max(8, sr - dx) + 'px';
          container.style.bottom = Math.max(8, sb - dy) + 'px';
        }
      };
      const onUp = () => {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
        container.classList.remove('dragging');
        if (isDrag) {
          handle.addEventListener('click', e => e.stopImmediatePropagation(), { once: true, capture: true });
        }
      };
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }

  // ── State Management ──
  function setState(newState) {
    state = newState;
    const { micBtn, stopBtn, transcript, status } = ui;
    if (!micBtn) return;

    micBtn.classList.remove('listening', 'speaking');
    stopBtn.classList.remove('visible');

    switch (state) {
      case State.IDLE:
        transcript.classList.remove('visible');
        status.classList.remove('visible');
        break;
      case State.LISTENING:
        micBtn.classList.add('listening');
        transcript.classList.add('visible');
        transcript.textContent = 'Ouvindo...';
        showStatus('Fale agora');
        break;
      case State.SUBMITTING:
        showStatus('Enviando...');
        transcript.classList.remove('visible');
        break;
      case State.WAITING:
        showStatus('Aguardando resposta...');
        break;
      case State.SPEAKING:
        micBtn.classList.add('speaking');
        stopBtn.classList.add('visible');
        showStatus('Lendo resposta...');
        break;
    }
  }

  function showStatus(msg) {
    if (ui.status) {
      ui.status.textContent = msg;
      ui.status.classList.add('visible');
    }
  }

  // ── Mic Click Handler ──
  function onMicClick() {
    switch (state) {
      case State.IDLE:
      case State.WAITING:
        startListening();
        break;
      case State.LISTENING:
        stopListening();
        if (finalTranscript.trim()) {
          sendMessage(finalTranscript.trim());
        } else {
          setState(State.IDLE);
        }
        break;
      case State.SPEAKING:
        stopSpeaking();
        setState(State.IDLE);
        break;
      default:
        setState(State.IDLE);
    }
  }

  // ── STT via Offscreen Document ──
  function startListening() {
    finalTranscript = '';
    clearTimeout(silenceTimer);
    setState(State.LISTENING);

    chrome.runtime.sendMessage({
      target: 'offscreen',
      type: 'start-stt',
      lang: settings.language
    });
  }

  function stopListening() {
    clearTimeout(silenceTimer);
    chrome.runtime.sendMessage({
      target: 'offscreen',
      type: 'stop-stt'
    });
  }

  chrome.runtime.onMessage.addListener((msg) => {
    if (msg.target !== 'content') return;

    switch (msg.type) {
      case 'stt-result':
        handleSTTResult(msg.final, msg.interim);
        break;
      case 'stt-error':
        console.warn('AI Voice STT error:', msg.error);
        if (msg.error === 'not-allowed') {
          showStatus('Microfone bloqueado. Permita o acesso.');
          setTimeout(() => setState(State.IDLE), 3000);
        }
        break;
    }
  });

  function handleSTTResult(final, interim) {
    if (state !== State.LISTENING) return;

    finalTranscript = final || '';
    const display = finalTranscript + (interim ? ' ' + interim : '');

    const el = ui.transcript;
    el.innerHTML = '';
    if (finalTranscript) {
      const s = document.createElement('span');
      s.textContent = finalTranscript;
      el.appendChild(s);
    }
    if (interim) {
      const s = document.createElement('span');
      s.className = 'interim';
      s.textContent = (finalTranscript ? ' ' : '') + interim;
      el.appendChild(s);
    }
    if (!display.trim()) {
      el.textContent = 'Ouvindo...';
    }

    clearTimeout(silenceTimer);
    if (finalTranscript.trim() && settings.autoSubmit) {
      silenceTimer = setTimeout(() => {
        if (state === State.LISTENING && finalTranscript.trim()) {
          stopListening();
          sendMessage(finalTranscript.trim());
        }
      }, settings.silenceTimeout);
    }
  }

  // ── DOM Interaction (multi-site) ──

  function findInputField() {
    // Try site-specific selectors first, then generic fallback
    const selectors = [...config.input, 'div[contenteditable="true"]', 'textarea'];
    const seen = new Set();

    for (const sel of selectors) {
      if (seen.has(sel)) continue;
      seen.add(sel);

      const els = document.querySelectorAll(sel);
      for (const el of els) {
        const rect = el.getBoundingClientRect();
        if (rect.width > 50 && rect.height > 0 && rect.bottom > window.innerHeight * 0.3) {
          return el;
        }
      }
    }
    return null;
  }

  function findSendButton() {
    const selectors = [...config.sendButton];
    for (const sel of selectors) {
      const el = document.querySelector(sel);
      if (el && !el.disabled) return el;
    }

    // Fallback: find button near input with SVG icon
    const input = findInputField();
    if (input) {
      const parent = input.closest('form, fieldset, [class*="composer"], [class*="input"]')
        || input.parentElement?.parentElement?.parentElement;
      if (parent) {
        const buttons = parent.querySelectorAll('button');
        for (let i = buttons.length - 1; i >= 0; i--) {
          const btn = buttons[i];
          if (btn.querySelector('svg') && !btn.disabled) {
            return btn;
          }
        }
      }
    }
    return null;
  }

  function sendMessage(text) {
    const input = findInputField();
    if (!input) {
      showStatus('Campo de texto nao encontrado!');
      setTimeout(() => setState(State.IDLE), 2000);
      return;
    }

    setState(State.SUBMITTING);
    input.focus();

    const isContentEditable = input.contentEditable === 'true';
    const isTextarea = input.tagName === 'TEXTAREA';

    if (isContentEditable) {
      // ProseMirror / Quill / generic contenteditable
      const sel = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(input);
      sel.removeAllRanges();
      sel.addRange(range);
      document.execCommand('delete', false, null);
      document.execCommand('insertText', false, text);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    } else if (isTextarea) {
      // ChatGPT, Perplexity, Poe, etc use textarea with React
      const nativeSetter = Object.getOwnPropertyDescriptor(
        window.HTMLTextAreaElement.prototype, 'value'
      )?.set;
      if (nativeSetter) {
        nativeSetter.call(input, text);
      } else {
        input.value = text;
      }
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));

      // Also fire React's synthetic event
      const reactEvent = new Event('input', { bubbles: true });
      Object.defineProperty(reactEvent, 'target', { value: input });
      input.dispatchEvent(reactEvent);
    }

    // Wait for framework to process, then submit
    setTimeout(() => {
      const sendBtn = findSendButton();
      if (sendBtn && !sendBtn.disabled) {
        sendBtn.click();
        onMessageSent();
      } else {
        // Retry — button might be enabling after text input
        setTimeout(() => {
          const btn = findSendButton();
          if (btn && !btn.disabled) {
            btn.click();
            onMessageSent();
          } else {
            // Try Enter key as last resort
            const enterEvent = new KeyboardEvent('keydown', {
              key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true
            });
            input.dispatchEvent(enterEvent);
            onMessageSent();
          }
        }, 500);
      }
    }, 400);
  }

  function onMessageSent() {
    lastKnownResponseCount = getResponseElements().length;
    setState(State.WAITING);
    startWatchingForResponse();
  }

  // ── Response Detection (multi-site) ──

  function getResponseElements() {
    const selectors = [...config.responseMessage];

    for (const sel of selectors) {
      try {
        const els = document.querySelectorAll(sel);
        if (els.length > 0) return Array.from(els);
      } catch (e) { /* invalid selector */ }
    }

    // Broad fallback
    const allMessages = document.querySelectorAll('[class*="message"], [class*="response"], [class*="answer"]');
    const responses = [];
    for (const el of allMessages) {
      if (el.querySelector('p, ol, ul, h1, h2, h3, pre') && el.textContent.trim().length > 20) {
        responses.push(el);
      }
    }
    return responses;
  }

  function isStreamingActive() {
    const selectors = [...config.streamingIndicator, '[class*="streaming"]', '.animate-spin'];
    for (const sel of selectors) {
      try {
        if (document.querySelector(sel)) return true;
      } catch (e) { /* invalid selector */ }
    }
    return false;
  }

  function startWatchingForResponse() {
    if (responseObserver) responseObserver.disconnect();

    let debounceTimer = null;
    let wasStreaming = false;
    let checkCount = 0;
    const maxChecks = 120;

    responseObserver = new MutationObserver(() => {
      const streaming = isStreamingActive();

      if (streaming) {
        wasStreaming = true;
        clearTimeout(debounceTimer);
        return;
      }

      if (wasStreaming && !streaming) {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          wasStreaming = false;
          responseObserver.disconnect();
          responseObserver = null;
          onResponseComplete();
        }, 1000);
      }
    });

    const target = document.querySelector('main') || document.body;
    responseObserver.observe(target, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
    });

    // Backup polling
    const intervalId = setInterval(() => {
      checkCount++;
      if (state !== State.WAITING) {
        clearInterval(intervalId);
        return;
      }
      if (checkCount > maxChecks) {
        clearInterval(intervalId);
        setState(State.IDLE);
        return;
      }

      const responses = getResponseElements();
      if (responses.length > lastKnownResponseCount && !isStreamingActive()) {
        clearInterval(intervalId);
        if (responseObserver) {
          responseObserver.disconnect();
          responseObserver = null;
        }
        clearTimeout(debounceTimer);
        setTimeout(onResponseComplete, 800);
      }
    }, 1000);
  }

  function onResponseComplete() {
    if (state !== State.WAITING) return;

    if (!settings.autoRead) {
      setState(State.IDLE);
      return;
    }

    const text = getLastResponseText();
    if (text && text.length > 5) {
      speakText(text);
    } else {
      setState(State.IDLE);
    }
  }

  function getLastResponseText() {
    const responses = getResponseElements();
    if (responses.length === 0) return '';

    const lastResponse = responses[responses.length - 1];

    if (settings.readCodeBlocks) {
      return lastResponse.textContent?.trim() || '';
    }

    const clone = lastResponse.cloneNode(true);
    clone.querySelectorAll('pre, code, .code-block, [class*="code-block"], [class*="hljs"]').forEach(el => {
      const replacement = document.createTextNode(' bloco de codigo omitido. ');
      el.parentNode.replaceChild(replacement, el);
    });

    let text = clone.textContent || '';
    text = text.replace(/\n{3,}/g, '\n\n').trim();
    return text;
  }

  // ── Text-to-Speech ──

  function speakText(text) {
    stopSpeaking();

    const synth = window.speechSynthesis;
    if (!synth) {
      showStatus('SpeechSynthesis nao suportado');
      setState(State.IDLE);
      return;
    }

    setState(State.SPEAKING);

    let cleaned = text
      .replace(/```[\s\S]*?```/g, ' bloco de codigo omitido. ')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .replace(/[#*_~>|]/g, '')
      .replace(/\n{2,}/g, '. ')
      .replace(/\n/g, ' ')
      .replace(/\s{2,}/g, ' ')
      .trim();

    const chunks = splitIntoChunks(cleaned, 180);
    let chunkIndex = 0;

    ttsChromeBugTimer = setInterval(() => {
      if (synth.speaking && !synth.paused) {
        synth.pause();
        synth.resume();
      }
    }, 10000);

    function speakNext() {
      if (chunkIndex >= chunks.length || state !== State.SPEAKING) {
        stopSpeaking();
        setState(State.IDLE);
        return;
      }

      const utterance = new SpeechSynthesisUtterance(chunks[chunkIndex]);
      utterance.lang = settings.language;
      utterance.rate = settings.speechRate;

      if (settings.voiceName) {
        const voices = synth.getVoices();
        const voice = voices.find(v => v.name === settings.voiceName);
        if (voice) utterance.voice = voice;
      }

      utterance.onend = () => {
        chunkIndex++;
        setTimeout(speakNext, 100);
      };

      utterance.onerror = (e) => {
        if (e.error !== 'interrupted' && e.error !== 'canceled') {
          console.warn('AI Voice TTS error:', e.error);
        }
        stopSpeaking();
        setState(State.IDLE);
      };

      synth.speak(utterance);
    }

    speakNext();
  }

  function splitIntoChunks(text, maxLen) {
    const sentences = text.match(/[^.!?]+[.!?]+/g) || [text];
    const chunks = [];
    let current = '';

    for (const sentence of sentences) {
      if ((current + sentence).length > maxLen && current.trim()) {
        chunks.push(current.trim());
        current = sentence;
      } else {
        current += sentence;
      }
    }
    if (current.trim()) chunks.push(current.trim());

    const result = [];
    for (const chunk of chunks) {
      if (chunk.length > maxLen) {
        const parts = chunk.split(/(?<=[,;])\s+/);
        let part = '';
        for (const p of parts) {
          if ((part + ' ' + p).length > maxLen && part.trim()) {
            result.push(part.trim());
            part = p;
          } else {
            part += (part ? ' ' : '') + p;
          }
        }
        if (part.trim()) result.push(part.trim());
      } else {
        result.push(chunk);
      }
    }
    return result.length > 0 ? result : [text];
  }

  function stopSpeaking() {
    clearInterval(ttsChromeBugTimer);
    ttsChromeBugTimer = null;
    window.speechSynthesis?.cancel();
  }

  // ── Keyboard Shortcuts ──

  function initShortcuts() {
    document.addEventListener('keydown', (e) => {
      if (e.altKey && e.code === 'Space') {
        e.preventDefault();
        e.stopPropagation();
        onMicClick();
      }
      if (e.key === 'Escape') {
        if (state === State.SPEAKING) {
          stopSpeaking();
          setState(State.IDLE);
        } else if (state === State.LISTENING) {
          stopListening();
          setState(State.IDLE);
        }
      }
    }, true);
  }

  // ── Passive auto-read observer ──

  function startPassiveObserver() {
    let lastCount = getResponseElements().length;

    setInterval(() => {
      if (state !== State.IDLE || !settings.autoRead) return;

      const responses = getResponseElements();
      if (responses.length > lastCount && !isStreamingActive()) {
        lastCount = responses.length;
        setTimeout(() => {
          if (!isStreamingActive() && state === State.IDLE) {
            const text = getLastResponseText();
            if (text && text.length > 10) {
              speakText(text);
            }
          }
        }, 2000);
      } else {
        lastCount = responses.length;
      }
    }, 3000);
  }

  // ── Init ──

  function init() {
    loadSettings();
    createUI();
    initShortcuts();
    setState(State.IDLE);

    setTimeout(() => {
      startPassiveObserver();
    }, 3000);

    const siteNames = {
      claude: 'Claude', chatgpt: 'ChatGPT', gemini: 'Gemini',
      copilot: 'Copilot', perplexity: 'Perplexity', poe: 'Poe',
      deepseek: 'DeepSeek', mistral: 'Mistral', huggingface: 'HuggingFace',
      generic: location.hostname,
    };

    console.log(
      `%c AI Voice Extension ativo em ${siteNames[SITE]}! %c Alt+Espaco para mic.`,
      'background: #e67e22; color: white; padding: 4px 8px; border-radius: 4px;',
      'color: #888;'
    );
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
