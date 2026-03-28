(() => {
  if (globalThis.XPipDoomPiP) return;

  async function toggle(options = {}) {
    const source = options.source ?? (globalThis.XPipBrowserEnv?.source ?? "chrome");
    const contentSession = globalThis.XPipContentSession;
    const doomRuntime = globalThis.XPipDoomRuntime;

    if (source !== "chrome") {
      throw new Error("Doom-in-PiP is currently Chrome-only");
    }
    if (!contentSession || !doomRuntime) {
      throw new Error("Doom runtime is unavailable");
    }

    const existing = contentSession.getWindow("doom");
    if (existing) {
      await contentSession.close("doom", options);
      return { active: false };
    }

    const pipWindow = await contentSession.open("doom", {
      apiBase: options.apiBase ?? "http://127.0.0.1:51789",
      source,
      name: "doom",
      width: 720,
      height: 480,
    });
    await doomRuntime.start(pipWindow, { source });
    return { active: true };
  }

  globalThis.XPipDoomPiP = {
    toggle,
  };
})();
