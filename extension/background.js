if (typeof importScripts === "function") {
  importScripts("shared/browser-env.js");
}

if (typeof chrome !== "undefined" && chrome.commands && chrome.commands.onCommand) {
  chrome.commands.onCommand.addListener(async (command) => {
    if (command !== "toggle-pip") return;
    const tab = await globalThis.XPipBrowserEnv?.getActiveTab?.();
    if (!tab) return;
    await chrome.scripting.executeScript({
      target: { tabId: tab.id, allFrames: true },
      files: ["shared/video-pip.js", "content.js"],
    });
  });
}

// ---------------------------------------------------------------------------
//  Proxy fetch for content scripts (bypasses Safari mixed content block)
// ---------------------------------------------------------------------------

const _runtime = globalThis.XPipBrowserEnv?.runtime
  || ((typeof browser !== "undefined" && browser.runtime)
    ? browser.runtime
    : chrome.runtime);

_runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type !== "xpip-fetch") return false;

  fetch(message.url, {
    method: message.method || "GET",
    headers: message.headers || {},
    body: message.body || undefined,
  })
    .then((res) => res.json())
    .then((data) => sendResponse({ ok: true, data }))
    .catch(() => sendResponse({ ok: false, data: null }));

  return true; // keep channel open for async sendResponse
});
