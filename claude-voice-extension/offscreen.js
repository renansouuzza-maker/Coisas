// AI Voice — Offscreen Document for Speech Recognition
// Handles microphone access and SpeechRecognition API

const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;

let recognition = null;
let isListening = false;

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.target !== 'offscreen') return;

  switch (msg.type) {
    case 'start-stt':
      startRecognition(msg.lang || 'pt-BR');
      sendResponse({ ok: true });
      break;
    case 'stop-stt':
      stopRecognition();
      sendResponse({ ok: true });
      break;
    case 'request-mic-permission':
      requestMicPermission().then(result => sendResponse(result));
      return true; // async
  }
  return true;
});

async function requestMicPermission() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    // Stop tracks immediately — we just needed the permission grant
    stream.getTracks().forEach(t => t.stop());
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e.message };
  }
}

function startRecognition(lang) {
  if (isListening) stopRecognition();

  if (!SpeechRecognition) {
    chrome.runtime.sendMessage({
      target: 'content',
      type: 'stt-error',
      error: 'SpeechRecognition not supported'
    });
    return;
  }

  recognition = new SpeechRecognition();
  recognition.continuous = true;
  recognition.interimResults = true;
  recognition.lang = lang;
  recognition.maxAlternatives = 1;

  recognition.onstart = () => {
    isListening = true;
    chrome.runtime.sendMessage({
      target: 'content',
      type: 'stt-started'
    });
  };

  recognition.onresult = (event) => {
    let finalTranscript = '';
    let interimTranscript = '';

    for (let i = 0; i < event.results.length; i++) {
      const result = event.results[i];
      if (result.isFinal) {
        finalTranscript += result[0].transcript;
      } else {
        interimTranscript += result[0].transcript;
      }
    }

    chrome.runtime.sendMessage({
      target: 'content',
      type: 'stt-result',
      final: finalTranscript,
      interim: interimTranscript
    });
  };

  recognition.onerror = (event) => {
    if (event.error === 'no-speech' || event.error === 'aborted') return;

    chrome.runtime.sendMessage({
      target: 'content',
      type: 'stt-error',
      error: event.error
    });

    if (event.error === 'not-allowed') {
      isListening = false;
    }
  };

  recognition.onend = () => {
    if (isListening) {
      try {
        recognition.start();
      } catch (e) {
        isListening = false;
        chrome.runtime.sendMessage({
          target: 'content',
          type: 'stt-stopped'
        });
      }
    } else {
      chrome.runtime.sendMessage({
        target: 'content',
        type: 'stt-stopped'
      });
    }
  };

  try {
    recognition.start();
  } catch (e) {
    // If permission denied, try requesting it first
    requestMicPermission().then(result => {
      if (result.ok) {
        try {
          recognition.start();
        } catch (e2) {
          chrome.runtime.sendMessage({
            target: 'content',
            type: 'stt-error',
            error: e2.message
          });
        }
      } else {
        chrome.runtime.sendMessage({
          target: 'content',
          type: 'stt-error',
          error: 'not-allowed'
        });
      }
    });
  }
}

function stopRecognition() {
  isListening = false;
  if (recognition) {
    try {
      recognition.stop();
    } catch (e) { /* ignore */ }
    recognition = null;
  }
}
