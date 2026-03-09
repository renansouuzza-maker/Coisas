// Claude Voice — Background Service Worker
// Routes messages between content script and offscreen document.
// Manages offscreen document lifecycle.

const OFFSCREEN_URL = 'offscreen.html';

// Ensure offscreen document exists
async function ensureOffscreen() {
  const contexts = await chrome.runtime.getContexts({
    contextTypes: ['OFFSCREEN_DOCUMENT'],
    documentUrls: [chrome.runtime.getURL(OFFSCREEN_URL)]
  });

  if (contexts.length > 0) return;

  await chrome.offscreen.createDocument({
    url: OFFSCREEN_URL,
    reasons: ['USER_MEDIA'],
    justification: 'Speech recognition requires microphone access via DOM API'
  });
}

// Route messages between content script and offscreen document
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.target === 'offscreen') {
    // Content script → offscreen document
    ensureOffscreen().then(() => {
      chrome.runtime.sendMessage(msg).catch(() => {});
    });
    sendResponse({ ok: true });
    return true;
  }

  if (msg.target === 'content') {
    // Offscreen document → content script (forward to all claude.ai tabs)
    chrome.tabs.query({ url: 'https://claude.ai/*' }, (tabs) => {
      for (const tab of tabs) {
        chrome.tabs.sendMessage(tab.id, msg).catch(() => {});
      }
    });
    return false;
  }
});
