(() => {
  if (globalThis.XPipVideoPiP) return;

  function findLargestVideo({ requirePlaying = false } = {}) {
    return Array.from(document.querySelectorAll("video"))
      .filter((video) => {
        if (video.readyState <= 0 || video.disablePictureInPicture) return false;
        if (requirePlaying && video.paused) return false;
        return true;
      })
      .sort(
        (a, b) =>
          b.clientWidth * b.clientHeight - a.clientWidth * a.clientHeight
      )[0];
  }

  async function requestLargestVideoPiP(options = {}) {
    const video = findLargestVideo(options);
    if (!video) return false;

    try {
      await video.requestPictureInPicture();
      return true;
    } catch {
      return false;
    }
  }

  async function exitCurrentPiP() {
    if (!document.pictureInPictureElement) return false;

    try {
      await document.exitPictureInPicture();
      return true;
    } catch {
      return false;
    }
  }

  async function toggleLargestVideoPiP() {
    const video = findLargestVideo();
    if (!video) return false;

    if (document.pictureInPictureElement === video) {
      await exitCurrentPiP();
      return true;
    }

    if (!document.pictureInPictureElement) {
      return requestLargestVideoPiP();
    }

    return false;
  }

  globalThis.XPipVideoPiP = {
    findLargestVideo,
    requestLargestVideoPiP,
    exitCurrentPiP,
    toggleLargestVideoPiP,
  };
})();
