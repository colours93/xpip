(() => {
  if (globalThis.XPipRuntimeFetch) return;

  function proxyFetchJson(url, options = {}) {
    const runtime = options.runtime || globalThis.XPipBrowserEnv?.runtime;
    if (!runtime || typeof runtime.sendMessage !== "function") {
      return Promise.resolve(null);
    }

    return new Promise((resolve) => {
      runtime.sendMessage(
        {
          type: "xpip-fetch",
          url,
          method: options.method || "GET",
          headers: options.headers || {},
          body: options.body || undefined,
        },
        (response) => {
          if (response && response.ok) {
            resolve(response.data);
          } else {
            resolve(null);
          }
        }
      );
    });
  }

  globalThis.XPipRuntimeFetch = { proxyFetchJson };
})();
