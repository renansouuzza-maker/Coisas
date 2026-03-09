// Claude Voice — Offscreen Document for Speech Recognition
// SpeechRecognition requires DOM access, which service workers don't have.
// This offscreen document handles all STT and forwards results via chrome.runtime messaging.

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
  }
  return true;
});

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
    // 'no-speech' and 'aborted' are normal, ignore them
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
    // Auto-restart if still supposed to be listening
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
    chrome.runtime.sendMessage({
      target: 'content',
      type: 'stt-error',
      error: e.message
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
