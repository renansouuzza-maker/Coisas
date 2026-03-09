// Claude Voice Extension — Content Script
// Interface de voz para claude.ai
// STT via offscreen document, TTS via SpeechSynthesis, DOM via MutationObserver

(function () {
  'use strict';

  // Prevent double-init
  if (document.getElementById('claude-voice-container')) return;

  // ── State Machine ──
  // IDLE → LISTENING → SUBMITTING → WAITING → SPEAKING → IDLE
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
        showStatus('🎤 Fale agora');
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

    // Send message to background → offscreen to start STT
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

  // Listen for STT results from offscreen document
  chrome.runtime.onMessage.addListener((msg) => {
    if (msg.target !== 'content') return;

    switch (msg.type) {
      case 'stt-result':
        handleSTTResult(msg.final, msg.interim);
        break;
      case 'stt-error':
        console.warn('Claude Voice STT error:', msg.error);
        if (msg.error === 'not-allowed') {
          showStatus('Microfone bloqueado. Permita o acesso.');
          setTimeout(() => setState(State.IDLE), 3000);
        }
        break;
      case 'stt-started':
        // STT is running
        break;
      case 'stt-stopped':
        // STT stopped
        break;
    }
  });

  function handleSTTResult(final, interim) {
    if (state !== State.LISTENING) return;

    finalTranscript = final || '';
    const display = finalTranscript + (interim ? ' ' + interim : '');

    // Update transcript UI
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

    // Silence detection → auto-submit
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

  // ── DOM Interaction with claude.ai ──

  function findInputField() {
    // Claude.ai uses ProseMirror contenteditable div
    const selectors = [
      'div.ProseMirror[contenteditable="true"]',
      '[contenteditable="true"][data-placeholder]',
      'div[contenteditable="true"]',
      'textarea',
    ];
    for (const sel of selectors) {
      const els = document.querySelectorAll(sel);
      for (const el of els) {
        const rect = el.getBoundingClientRect();
        // Must be visible and in the bottom half of the page (input area)
        if (rect.width > 100 && rect.height > 0 && rect.bottom > window.innerHeight * 0.4) {
          return el;
        }
      }
    }
    return null;
  }

  function findSendButton() {
    // Try aria-labels first
    const ariaSelectors = [
      'button[aria-label="Send Message"]',
      'button[aria-label="Send message"]',
      'button[aria-label="Enviar mensagem"]',
      'button[aria-label="Enviar Mensagem"]',
      'button[data-testid="send-button"]',
    ];
    for (const sel of ariaSelectors) {
      const el = document.querySelector(sel);
      if (el) return el;
    }

    // Fallback: find the button near the input area that has an SVG (send icon)
    const input = findInputField();
    if (input) {
      const parent = input.closest('form, fieldset, [class*="composer"], [class*="input-area"]') || input.parentElement?.parentElement?.parentElement;
      if (parent) {
        const buttons = parent.querySelectorAll('button');
        // The send button is usually the last enabled button with an SVG
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

    // Focus and clear
    input.focus();

    if (input.contentEditable === 'true') {
      // ProseMirror: use execCommand for proper framework detection
      // Select all existing content first
      const sel = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(input);
      sel.removeAllRanges();
      sel.addRange(range);

      // Delete existing content
      document.execCommand('delete', false, null);

      // Insert new text via execCommand — this triggers ProseMirror's input handling
      document.execCommand('insertText', false, text);

      // Dispatch events as backup
      input.dispatchEvent(new Event('input', { bubbles: true }));
    } else {
      // Regular textarea fallback
      const nativeSetter = Object.getOwnPropertyDescriptor(
        window.HTMLTextAreaElement.prototype, 'value'
      )?.set;
      if (nativeSetter) {
        nativeSetter.call(input, text);
      } else {
        input.value = text;
      }
      input.dispatchEvent(new Event('input', { bubbles: true }));
    }

    // Wait for framework to process, then submit
    setTimeout(() => {
      const sendBtn = findSendButton();
      if (sendBtn && !sendBtn.disabled) {
        sendBtn.click();
        onMessageSent();
      } else {
        // Retry after a bit more time (button might be enabling)
        setTimeout(() => {
          const btn = findSendButton();
          if (btn && !btn.disabled) {
            btn.click();
            onMessageSent();
          } else {
            // Try Enter key
            input.dispatchEvent(new KeyboardEvent('keydown', {
              key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true
            }));
            onMessageSent();
          }
        }, 500);
      }
    }, 400);
  }

  function onMessageSent() {
    // Count current responses before waiting for new one
    lastKnownResponseCount = getResponseElements().length;
    setState(State.WAITING);
    startWatchingForResponse();
  }

  // ── Response Detection ──

  function getResponseElements() {
    // Try multiple selectors for Claude's response messages
    const selectorGroups = [
      '[data-testid^="chat-message-"]',
      '.font-claude-message',
      '[class*="message"][class*="assistant"]',
      '[data-is-streaming]',
    ];

    for (const sel of selectorGroups) {
      const els = document.querySelectorAll(sel);
      if (els.length > 0) return Array.from(els);
    }

    // Broader fallback: look for response-like containers
    // Claude typically renders responses in divs with markdown content
    const allMessages = document.querySelectorAll('[class*="message"], [class*="response"]');
    const responses = [];
    for (const el of allMessages) {
      // Filter: must have substantial text, and contain markdown-rendered content
      if (el.querySelector('p, ol, ul, h1, h2, h3, pre') && el.textContent.trim().length > 20) {
        responses.push(el);
      }
    }
    return responses;
  }

  function isStreamingActive() {
    const indicators = [
      '[data-is-streaming="true"]',
      '.result-streaming',
      '[class*="streaming"]',
      // "Stop" button presence indicates streaming
      'button[aria-label="Stop Response"]',
      'button[aria-label="Stop response"]',
      'button[aria-label="Parar resposta"]',
      'button[aria-label="Stop"]',
      'button[aria-label="Parar"]',
    ];
    for (const sel of indicators) {
      if (document.querySelector(sel)) return true;
    }
    return false;
  }

  function startWatchingForResponse() {
    if (responseObserver) responseObserver.disconnect();

    let debounceTimer = null;
    let wasStreaming = false;
    let checkCount = 0;
    const maxChecks = 120; // 2 minutes max wait (at 1s interval)

    // MutationObserver for detecting streaming start/end
    responseObserver = new MutationObserver(() => {
      const streaming = isStreamingActive();

      if (streaming) {
        wasStreaming = true;
        clearTimeout(debounceTimer);
        return;
      }

      if (wasStreaming && !streaming) {
        // Streaming just ended
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          wasStreaming = false;
          responseObserver.disconnect();
          responseObserver = null;
          onResponseComplete();
        }, 1000); // Wait 1s after streaming stops to be sure
      }
    });

    const target = document.querySelector('main') || document.body;
    responseObserver.observe(target, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ['data-is-streaming', 'class'],
    });

    // Backup: periodic check in case MutationObserver misses it
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
        // Give extra time for final render
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

    // Clone and remove code blocks
    const clone = lastResponse.cloneNode(true);
    clone.querySelectorAll('pre, code, .code-block, [class*="code"]').forEach(el => {
      const replacement = document.createTextNode(' bloco de código omitido. ');
      el.parentNode.replaceChild(replacement, el);
    });

    // Clean markdown artifacts
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

    // Clean text for natural speech
    let cleaned = text
      .replace(/```[\s\S]*?```/g, ' bloco de código omitido. ')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .replace(/[#*_~>|]/g, '')
      .replace(/\n{2,}/g, '. ')
      .replace(/\n/g, ' ')
      .replace(/\s{2,}/g, ' ')
      .trim();

    const chunks = splitIntoChunks(cleaned, 180);
    let chunkIndex = 0;

    // Chrome bug workaround: synthesis pauses after ~15s
    // Keep it alive with pause/resume cycling
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

      // Select voice
      if (settings.voiceName) {
        const voices = synth.getVoices();
        const voice = voices.find(v => v.name === settings.voiceName);
        if (voice) utterance.voice = voice;
      }

      utterance.onend = () => {
        chunkIndex++;
        // Small pause between chunks for naturalness
        setTimeout(speakNext, 100);
      };

      utterance.onerror = (e) => {
        if (e.error !== 'interrupted' && e.error !== 'canceled') {
          console.warn('Claude Voice TTS error:', e.error);
        }
        stopSpeaking();
        setState(State.IDLE);
      };

      synth.speak(utterance);
    }

    speakNext();
  }

  function splitIntoChunks(text, maxLen) {
    // Split by sentences
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

    // Split any remaining long chunks by commas/spaces
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
      // Alt+Space → toggle mic
      if (e.altKey && e.code === 'Space') {
        e.preventDefault();
        e.stopPropagation();
        onMicClick();
      }
      // Escape → stop TTS or stop listening
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

  // ── Auto-read for non-voice responses (passive mode) ──

  function startPassiveObserver() {
    let lastCount = getResponseElements().length;

    setInterval(() => {
      // Only auto-read when idle and autoRead is on
      if (state !== State.IDLE || !settings.autoRead) return;

      const responses = getResponseElements();
      if (responses.length > lastCount && !isStreamingActive()) {
        lastCount = responses.length;
        // Wait a bit to make sure streaming is fully done
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

    // Start passive observer after page settles
    setTimeout(() => {
      startPassiveObserver();
    }, 3000);

    console.log('%c Claude Voice Extension ativo! %c Alt+Espaço para mic.',
      'background: #e67e22; color: white; padding: 4px 8px; border-radius: 4px;',
      'color: #888;');
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
