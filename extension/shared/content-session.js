(() => {
  if (globalThis.XPipContentSession) return;

  const activeWindows = new Map();

  async function notify(action, { apiBase, source, name }) {
    const runtimeFetch = globalThis.XPipRuntimeFetch?.proxyFetchJson;
    if (typeof runtimeFetch !== "function") return null;
    return runtimeFetch(`${apiBase}/content-session/${action}?source=${encodeURIComponent(source)}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
  }

  function track(name, pipWindow, options) {
    activeWindows.set(name, pipWindow);
    let stopped = false;

    const stop = async () => {
      if (stopped) return;
      stopped = true;
      if (activeWindows.get(name) === pipWindow) {
        activeWindows.delete(name);
      }
      await notify("stop", options);
    };

    pipWindow.addEventListener("pagehide", stop, { once: true });
    pipWindow.addEventListener("beforeunload", stop, { once: true });
    return stop;
  }

  async function open(name, options) {
    if (!window.documentPictureInPicture?.requestWindow) {
      throw new Error("Document Picture-in-Picture is unavailable");
    }

    const existing = activeWindows.get(name);
    if (existing && !existing.closed) {
      existing.focus();
      return existing;
    }

    const pipWindow = await window.documentPictureInPicture.requestWindow({
      width: options.width ?? 640,
      height: options.height ?? 400,
    });

    activeWindows.set(name, pipWindow);
    await notify("start", options);
    const stop = track(name, pipWindow, options);
    pipWindow.__xpipStopSession = stop;
    return pipWindow;
  }

  async function close(name, options) {
    const existing = activeWindows.get(name);
    if (!existing) {
      await notify("stop", options);
      return false;
    }

    activeWindows.delete(name);
    if (typeof existing.__xpipStopSession === "function") {
      await existing.__xpipStopSession();
    } else {
      await notify("stop", options);
    }
    if (!existing.closed) existing.close();
    return true;
  }

  function getWindow(name) {
    const existing = activeWindows.get(name);
    if (existing && !existing.closed) return existing;
    activeWindows.delete(name);
    return null;
  }

  globalThis.XPipContentSession = {
    open,
    close,
    getWindow,
  };
})();
