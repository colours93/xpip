(() => {
  if (globalThis.XPipBrowserEnv) return;

  const runtime = (() => {
    try {
      if (typeof browser !== "undefined" && browser.runtime) return browser.runtime;
    } catch {}
    try {
      if (typeof chrome !== "undefined" && chrome.runtime) return chrome.runtime;
    } catch {}
    return null;
  })();

  const tabs = (() => {
    try {
      if (typeof browser !== "undefined" && browser.tabs) return browser.tabs;
    } catch {}
    try {
      if (typeof chrome !== "undefined" && chrome.tabs) return chrome.tabs;
    } catch {}
    return null;
  })();

  const hasScripting = (() => {
    try {
      return !!(typeof chrome !== "undefined" && chrome.scripting && chrome.scripting.executeScript);
    } catch {
      return false;
    }
  })();

  const source = (() => {
    try {
      if (typeof browser !== "undefined" && browser.runtime && browser.runtime.id) return "safari";
    } catch {}
    return "chrome";
  })();

  async function getActiveTab() {
    if (!tabs || typeof tabs.query !== "function") return null;
    const result = await tabs.query({ active: true, currentWindow: true });
    return Array.isArray(result) ? result[0] ?? null : null;
  }

  async function executeOnActiveTab({ func, files, allFrames = true }) {
    const tab = await getActiveTab();
    if (!tab) return;

    if (Array.isArray(files) && files.length > 0) {
      if (hasScripting) {
        return chrome.scripting.executeScript({
          target: { tabId: tab.id, allFrames },
          files,
        });
      }

      for (const file of files) {
        await tabs.executeScript(tab.id, { file, allFrames });
      }
      return;
    }

    if (typeof func !== "function") return;

    if (hasScripting) {
      return chrome.scripting.executeScript({
        target: { tabId: tab.id, allFrames },
        func,
      });
    }

    return tabs.executeScript(tab.id, {
      code: `(${func.toString()})()`,
      allFrames,
    });
  }

  globalThis.XPipBrowserEnv = {
    runtime,
    tabs,
    hasScripting,
    source,
    getActiveTab,
    executeOnActiveTab,
  };
})();
