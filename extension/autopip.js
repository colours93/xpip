// Auto-PiP: when you switch tabs while a video is playing, it pops into PiP automatically
navigator.mediaSession.setActionHandler("enterpictureinpicture", async () => {
  await globalThis.XPipVideoPiP?.requestLargestVideoPiP({ requirePlaying: true });
});

// ---------------------------------------------------------------------------
//  Per-PiP Audio Volume Control
// ---------------------------------------------------------------------------

const _XPIP_AUDIO_API = "http://127.0.0.1:51789";
const _XPIP_SOURCE = globalThis.XPipBrowserEnv?.source ?? "chrome";

// Route fetch through background script to bypass Safari mixed content block
async function _xpipFetch(url, options) {
  return globalThis.XPipRuntimeFetch?.proxyFetchJson(url, options) ?? null;
}

let _xpipAudioInterval = null;
let _xpipAudioVideo = null;

function xpipStartAudioReporting(video) {
  xpipStopAudioReporting();
  _xpipAudioVideo = video;

  _xpipAudioInterval = setInterval(async () => {
    if (!_xpipAudioVideo) {
      xpipStopAudioReporting();
      return;
    }
    try {
      const data = await _xpipFetch(
        `${_XPIP_AUDIO_API}/audio?source=${_XPIP_SOURCE}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            volume: _xpipAudioVideo.volume,
            muted: _xpipAudioVideo.muted,
          }),
        }
      );
      if (!data) return;
      // Apply desired state from daemon
      if (typeof data.volume === "number") {
        if (Math.abs(_xpipAudioVideo.volume - data.volume) > 0.005) {
          _xpipAudioVideo.volume = data.volume;
        }
      }
      if (typeof data.muted === "boolean") {
        if (_xpipAudioVideo.muted !== data.muted) {
          _xpipAudioVideo.muted = data.muted;
        }
      }
    } catch {}
  }, 1500);
}

function xpipStopAudioReporting() {
  if (_xpipAudioInterval) {
    clearInterval(_xpipAudioInterval);
    _xpipAudioInterval = null;
  }
  _xpipAudioVideo = null;
}

function xpipSignalPipEnded() {
  _xpipFetch(`${_XPIP_AUDIO_API}/audio?source=${_XPIP_SOURCE}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ pipEnded: true }),
  }).catch(() => {});
}

function xpipWatchVideos() {
  const videos = document.querySelectorAll("video");
  videos.forEach((video) => {
    if (video._xpipWatched) return;
    video._xpipWatched = true;

    video.addEventListener("enterpictureinpicture", () => {
      xpipStartAudioReporting(video);
    });

    video.addEventListener("leavepictureinpicture", () => {
      xpipStopAudioReporting();
      xpipSignalPipEnded();
    });
  });
}

// Watch for new video elements added to the DOM
const _xpipObserver = new MutationObserver(() => {
  xpipWatchVideos();
});
_xpipObserver.observe(document.documentElement, {
  childList: true,
  subtree: true,
});

// Initial scan
xpipWatchVideos();

// Check if PiP is already active on load
if (document.pictureInPictureElement) {
  xpipStartAudioReporting(document.pictureInPictureElement);
}
