// AI Voice — Background Service Worker
// Routes messages between content script and offscreen document.
// Manages offscreen document lifecycle.

const OFFSCREEN_URL = 'offscreen.html';
let creatingOffscreen = null;

async function ensureOffscreen() {
  // Avoid race conditions with parallel creation
  if (creatingOffscreen) {
    await creatingOffscreen;
    return;
  }

  try {
    const contexts = await chrome.runtime.getContexts({
      contextTypes: ['OFFSCREEN_DOCUMENT'],
      documentUrls: [chrome.runtime.getURL(OFFSCREEN_URL)]
    });

    if (contexts.length > 0) return;

    creatingOffscreen = chrome.offscreen.createDocument({
      url: OFFSCREEN_URL,
      reasons: ['USER_MEDIA'],
      justification: 'Speech recognition requires microphone access via DOM API'
    });

    await creatingOffscreen;
  } catch (e) {
    // Document might already exist
    if (!e.message?.includes('already exists')) {
      console.error('Failed to create offscreen document:', e);
    }
  } finally {
    creatingOffscreen = null;
  }
}

// Route messages between content script and offscreen document
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.target === 'offscreen') {
    // Content script → offscreen document
    ensureOffscreen().then(() => {
      // Forward message to offscreen
      chrome.runtime.sendMessage(msg).catch((e) => {
        // If offscreen doc is not ready, retry once
        console.warn('Failed to reach offscreen doc, retrying:', e);
        setTimeout(() => {
          chrome.runtime.sendMessage(msg).catch(() => {});
        }, 500);
      });
    });
    sendResponse({ ok: true });
    return true;
  }

  if (msg.target === 'content') {
    // Offscreen document → content script (forward to matching tabs)
    const urlPatterns = [
      'https://claude.ai/*',
      'https://chatgpt.com/*',
      'https://chat.openai.com/*',
      'https://gemini.google.com/*',
      'https://copilot.microsoft.com/*',
      'https://www.perplexity.ai/*',
      'https://poe.com/*',
      'https://chat.deepseek.com/*',
      'https://chat.mistral.ai/*',
      'https://huggingface.co/chat/*',
    ];

    // Query all supported tabs and forward
    chrome.tabs.query({}, (tabs) => {
      for (const tab of tabs) {
        if (tab.url && urlPatterns.some(pattern => {
          const regex = new RegExp('^' + pattern.replace(/\*/g, '.*'));
          return regex.test(tab.url);
        })) {
          chrome.tabs.sendMessage(tab.id, msg).catch(() => {});
        }
      }
    });
    return false;
  }
});

// Pre-create offscreen document on install/startup for faster first use
chrome.runtime.onInstalled.addListener(() => {
  ensureOffscreen();
});

chrome.runtime.onStartup.addListener(() => {
  ensureOffscreen();
});
