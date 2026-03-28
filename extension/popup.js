// Inject game icons
document.querySelectorAll('.game-card[data-icon]').forEach(card => {
  const key = card.getAttribute('data-icon');
  const iconEl = card.querySelector('.game-icon');
  if (GAME_ICONS[key] && iconEl) iconEl.innerHTML = GAME_ICONS[key];
});

// Settings toggle
const settingsToggle = document.getElementById('settingsToggle');
const settingsPanel = document.getElementById('settingsPanel');
settingsToggle.addEventListener('click', () => {
  settingsToggle.classList.toggle('open');
  settingsPanel.classList.toggle('open');
});

const API = "http://127.0.0.1:51789";
const XPIP_SOURCE = globalThis.XPipBrowserEnv?.source ?? "chrome";

async function executeOnActiveTab(func, options = {}) {
  return globalThis.XPipBrowserEnv?.executeOnActiveTab?.({
    func,
    allFrames: options.allFrames ?? true,
  });
}

const els = {
  status: document.getElementById("daemonStatus"),
  statusLabel: document.querySelector("#daemonStatus .label"),
  toggle: document.getElementById("enableToggle"),
  glow: document.getElementById("glowToggle"),
  seg: document.getElementById("cornerZone"),
  pipBtn: document.getElementById("pipBtn"),
  doomBtn: document.getElementById("doomBtn"),
};

const zoneBtns = els.seg.querySelectorAll("button");
let pipIsActive = false;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------------------
//  Color accent system
// ---------------------------------------------------------------------------

const COLOR_ACCENTS = {
  purple:  { accent: "#b355ff", glow: "rgba(179,85,255,0.3)" },
  blue:    { accent: "#3388ff", glow: "rgba(51,136,255,0.3)" },
  red:     { accent: "#ff3333", glow: "rgba(255,51,51,0.3)" },
  green:   { accent: "#1ae664", glow: "rgba(26,230,100,0.3)" },
  rainbow: { accent: "#ff66cc", glow: "rgba(255,102,204,0.3)" },
};

function applyColorAccent(color) {
  const c = COLOR_ACCENTS[color];
  if (!c) return;
  document.documentElement.style.setProperty("--accent", c.accent);
  document.documentElement.style.setProperty("--accent-glow", c.glow);
}

// ---------------------------------------------------------------------------
//  PiP control -- enter-only and exit-only (never blindly toggle)
// ---------------------------------------------------------------------------

async function enterPip() {
  try {
    await executeOnActiveTab(() => {
      const video = Array.from(document.querySelectorAll("video"))
        .filter((v) => v.readyState > 0 && !v.disablePictureInPicture)
        .sort(
          (a, b) =>
            b.clientWidth * b.clientHeight - a.clientWidth * a.clientHeight
        )[0];
      if (video && !document.pictureInPictureElement) {
        video.requestPictureInPicture().catch(() => {});
      }
    });
  } catch (e) {
    console.error("PiP enter failed:", e);
  }
}

async function exitPip() {
  try {
    await executeOnActiveTab(() => {
      if (document.pictureInPictureElement) {
        document.exitPictureInPicture().catch(() => {});
      }
    });
  } catch (e) {
    console.error("PiP exit failed:", e);
  }
}

// ---------------------------------------------------------------------------
//  Startup -- check daemon, auto-enter PiP if not active
// ---------------------------------------------------------------------------

async function ensureStarted() {
  let status = await fetchStatus();

  if (!status) {
    els.statusLabel.textContent = "Starting daemon...";

    // If daemon is reachable-but-unhealthy, this nudges launchd restart.
    try {
      await fetch(`${API}/restart`, { method: "POST" });
    } catch {}

    for (let i = 0; i < 10; i += 1) {
      await sleep(350);
      status = await fetchStatus();
      if (status) break;
    }
  }

  if (!status) return false;

  if (!status.videoPipActive) {
    await enterPip();

    // Wait for PiP window creation and daemon discovery.
    for (let i = 0; i < 8; i += 1) {
      await sleep(300);
      const refreshed = await fetchStatus();
      if (refreshed?.videoPipActive) return true;
    }
  }

  return true;
}

async function ensureDaemonOnline() {
  let status = await fetchStatus();

  if (!status) {
    els.statusLabel.textContent = "Starting daemon...";

    try {
      await fetch(`${API}/restart`, { method: "POST" });
    } catch {}

    for (let i = 0; i < 10; i += 1) {
      await sleep(350);
      status = await fetchStatus();
      if (status) break;
    }
  }

  return status;
}

async function init() {
  await ensureDaemonOnline();
}

init();

// ---------------------------------------------------------------------------
//  PiP button -- context-aware start/stop
// ---------------------------------------------------------------------------

function updatePipButton() {
  els.pipBtn.textContent = pipIsActive ? "Stop PiP" : "Start PiP";
  els.pipBtn.classList.toggle("active", pipIsActive);
}

function updateDoomButton(isRunning) {
  if (!els.doomBtn) return;
  const label = els.doomBtn.querySelector(".game-label");
  label.textContent = isRunning ? "Stop Doom" : "Doom";
  els.doomBtn.classList.toggle("active", !!isRunning);
  els.doomBtn.disabled = XPIP_SOURCE !== "chrome";
}

els.pipBtn.addEventListener("click", async () => {
  if (pipIsActive) {
    await exitPip();
    setTimeout(fetchStatus, 400);
  } else {
    await ensureStarted();
  }
});

async function toggleDoomContent() {
  const status = await ensureDaemonOnline();
  if (!status) return;

  try {
    await globalThis.XPipBrowserEnv?.executeOnActiveTab?.({
      files: [
        "shared/browser-env.js",
        "shared/runtime-fetch.js",
        "shared/content-session.js",
        "shared/doom-runtime.js",
        "shared/doom-pip.js",
      ],
      allFrames: false,
    });
    await executeOnActiveTab(() => {
      globalThis.XPipDoomPiP?.toggle({
        apiBase: "http://127.0.0.1:51789",
        source: globalThis.XPipBrowserEnv?.source ?? "chrome",
      });
    }, { allFrames: false });
    setTimeout(fetchStatus, 500);
  } catch (e) {
    console.error("Doom launch failed:", e);
  }
}

if (els.doomBtn) {
  els.doomBtn.addEventListener("click", async () => {
    els.doomBtn.classList.add("launching");
    setTimeout(() => els.doomBtn.classList.remove("launching"), 300);
    await toggleDoomContent();
  });
}

// ---------------------------------------------------------------------------
//  Games -- data-driven handlers for all mini-games
// ---------------------------------------------------------------------------

const games = [
  { id: "pipongBtn", key: "pipong", label: "PiPong", stopLabel: "Stop PiPong" },
  { id: "pipong2Btn", key: "pipong2", label: "PiPong 2", stopLabel: "Stop PiPong 2" },
  { id: "flappyBtn", key: "flappy", label: "FlaPiPy Bird", stopLabel: "Stop FlaPiPy" },
  { id: "bounceBtn", key: "bounce", statusKey: "bounceAuto", label: "Bounce", stopLabel: "Stop Bounce" },
  { id: "bouncePaddleBtn", key: "bounce-paddle", statusKey: "bouncePaddle", label: "Bounce Paddle", stopLabel: "Stop Paddle" },
  { id: "invadersBtn", key: "invaders", label: "Space Invaders", stopLabel: "Stop Invaders" },
  { id: "froggerBtn", key: "frogger", label: "Frogger", stopLabel: "Stop Frogger" },
  { id: "runnerBtn", key: "runner", label: "Runner", stopLabel: "Stop Runner" },
  { id: "snakeBtn", key: "snake", label: "Snake", stopLabel: "Stop Snake" },
  { id: "breakoutBtn", key: "breakout", label: "Breakout", stopLabel: "Stop Breakout" },
  { id: "asteroidsBtn", key: "asteroids", label: "Asteroids", stopLabel: "Stop Asteroids" },
  { id: "cursorhuntBtn", key: "cursorhunt", label: "Cursor Hunt", stopLabel: "Stop Hunt" },
  { id: "doodlejumpBtn", key: "doodlejump", label: "Doodle Jump", stopLabel: "Stop Doodle" },
  { id: "pacmanBtn", key: "pacman", label: "Pac-Man", stopLabel: "Stop Pac-Man" },
];

function resetGameButtons(exceptKey) {
  for (const g of games) {
    const el = document.getElementById(g.id);
    if (g.key !== exceptKey) {
      el.querySelector(".game-label").textContent = g.label;
      el.classList.remove("active");
    }
  }
}

function syncGameButtons(data) {
  for (const g of games) {
    const key = g.statusKey || g.key;
    if (data[key] !== undefined) {
      const el = document.getElementById(g.id);
      el.querySelector(".game-label").textContent = data[key] ? g.stopLabel : g.label;
      el.classList.toggle("active", !!data[key]);
    }
  }
}

for (const game of games) {
  const el = document.getElementById(game.id);
  el.addEventListener("click", async () => {
    // Launch animation
    el.classList.add("launching");
    setTimeout(() => el.classList.remove("launching"), 300);

    if (!pipIsActive) {
      const started = await ensureStarted();
      if (!started) return;
    }
    try {
      const res = await fetch(`${API}/${game.key}?source=${XPIP_SOURCE}`, { method: "POST" });
      const data = await res.json();
      if (data && typeof data === "object") {
        const isRunning = !!data[game.statusKey || game.key];
        el.querySelector(".game-label").textContent = isRunning
          ? game.stopLabel
          : game.label;
        el.classList.toggle("active", isRunning);
        if (isRunning) resetGameButtons(game.key);
      }
    } catch (e) {
      console.error(`Game toggle failed (${game.key}):`, e);
    }
  });
}

// ---------------------------------------------------------------------------
//  Audio controls
// ---------------------------------------------------------------------------

const audioEls = {
  controls: document.getElementById("audioControls"),
  muteBtn: document.getElementById("muteBtn"),
  slider: document.getElementById("volumeSlider"),
  value: document.getElementById("volumeValue"),
};

let _audioDragging = false;
let _audioCurrentMuted = false;

audioEls.slider.addEventListener("mousedown", () => { _audioDragging = true; });
audioEls.slider.addEventListener("mouseup", () => { _audioDragging = false; });

audioEls.slider.addEventListener("change", () => {
  _audioDragging = false;
  sendAudioCommand({ volume: Number(audioEls.slider.value) / 100 });
});

audioEls.muteBtn.addEventListener("click", () => {
  sendAudioCommand({ muted: !_audioCurrentMuted });
});

async function sendAudioCommand(cmd) {
  try {
    await fetch(`${API}/audio-cmd?source=${XPIP_SOURCE}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(cmd),
    });
  } catch (e) {
    console.error("Audio command failed:", e);
  }
}

function updateAudioUI(audioData) {
  if (!audioData || !audioData[XPIP_SOURCE]) {
    hideAudioUI();
    return;
  }
  const state = audioData[XPIP_SOURCE];
  audioEls.controls.classList.add("visible");

  _audioCurrentMuted = !!state.muted;
  const pct = Math.round((state.volume ?? 1) * 100);

  if (!_audioDragging) {
    audioEls.slider.value = pct;
  }
  audioEls.value.textContent = pct + "%";

  if (state.muted) {
    audioEls.muteBtn.textContent = "\u{1F507}";
    audioEls.muteBtn.classList.add("muted");
  } else {
    audioEls.muteBtn.textContent = "\u{1F50A}";
    audioEls.muteBtn.classList.remove("muted");
  }
}

function hideAudioUI() {
  audioEls.controls.classList.remove("visible");
}

// ---------------------------------------------------------------------------
//  Status -- click to restart only when offline
// ---------------------------------------------------------------------------

els.status.addEventListener("click", async () => {
  if (els.status.classList.contains("offline")) {
    els.statusLabel.textContent = "Restarting...";
    try {
      await fetch(`${API}/restart`, { method: "POST" });
    } catch (e) {
      console.error("Restart request failed:", e);
    }
    await new Promise((r) => setTimeout(r, 800));
    fetchStatus();
  }
});

// ---------------------------------------------------------------------------
//  Settings
// ---------------------------------------------------------------------------

function setActiveZone(value) {
  zoneBtns.forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.value === String(value));
  });
}

function closestZone(px) {
  const zones = [60, 100, 150];
  return zones.reduce((prev, curr) =>
    Math.abs(curr - px) < Math.abs(prev - px) ? curr : prev
  );
}

async function updateSettings(changes) {
  try {
    await fetch(`${API}/settings`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(changes),
    });
  } catch (e) {
    console.error("Settings update failed:", e);
  }
}

els.toggle.addEventListener("change", () => {
  updateSettings({ enabled: els.toggle.checked });
});

els.glow.addEventListener("change", () => {
  updateSettings({ glow: els.glow.checked });
});

const colorDots = document.querySelectorAll("#colorPicker .color-dot");

colorDots.forEach((dot) => {
  dot.addEventListener("click", () => {
    colorDots.forEach((d) => d.classList.remove("active"));
    dot.classList.add("active");
    applyColorAccent(dot.dataset.color);
    updateSettings({ glowColor: dot.dataset.color });
  });
});

function setActiveColor(color) {
  colorDots.forEach((d) => {
    d.classList.toggle("active", d.dataset.color === color);
  });
}

zoneBtns.forEach((btn) => {
  btn.addEventListener("click", () => {
    setActiveZone(btn.dataset.value);
    updateSettings({ cornerSize: Number(btn.dataset.value) });
  });
});

// ---------------------------------------------------------------------------
//  Hotkey recorder
// ---------------------------------------------------------------------------

const hotkeyBtn = document.getElementById("hotkeyBtn");
let recording = false;

const KEY_NAMES = {
  0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
  8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
  16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
  23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
  30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
  38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
  45: "N", 46: "M", 47: ".", 49: "Space", 50: "`", 53: "Esc",
  122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
  98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
};

function flagsToSymbols(f) {
  let s = "";
  if (f & 0x100) s += "\u2318";
  if (f & 0x008) s += "\u2325";
  if (f & 0x004) s += "\u2303";
  if (f & 0x002) s += "\u21E7";
  return s;
}

function formatHotkey(code, flags) {
  return flagsToSymbols(flags) + (KEY_NAMES[code] || `key${code}`);
}

hotkeyBtn.addEventListener("click", () => {
  recording = true;
  hotkeyBtn.textContent = "Press keys...";
  hotkeyBtn.classList.add("recording");
});

document.addEventListener("keydown", (e) => {
  if (!recording) return;
  e.preventDefault();
  if (["Shift", "Control", "Alt", "Meta"].includes(e.key)) return;

  let flags = 0;
  if (e.metaKey) flags |= 0x100;
  if (e.altKey) flags |= 0x008;
  if (e.ctrlKey) flags |= 0x004;
  if (e.shiftKey) flags |= 0x002;

  if (flags === 0) return;

  const code = e.keyCode;
  const MAC_CODES = {
    65: 0, 66: 11, 67: 8, 68: 2, 69: 14, 70: 3, 71: 5, 72: 4, 73: 34,
    74: 38, 75: 40, 76: 37, 77: 46, 78: 45, 79: 31, 80: 35, 81: 12,
    82: 15, 83: 1, 84: 17, 85: 32, 86: 9, 87: 13, 88: 7, 89: 16, 90: 6,
    48: 29, 49: 18, 50: 19, 51: 20, 52: 21, 53: 23, 54: 22, 55: 26,
    56: 28, 57: 25, 32: 49, 27: 53, 192: 50, 189: 27, 187: 24, 219: 33,
    221: 30, 186: 41, 222: 39, 188: 43, 190: 47, 191: 44, 220: 42,
    112: 122, 113: 120, 114: 99, 115: 118, 116: 96, 117: 97, 118: 98,
    119: 100, 120: 101, 121: 109, 122: 103, 123: 111,
  };

  const macCode = MAC_CODES[code];
  if (macCode === undefined) return;

  recording = false;
  hotkeyBtn.classList.remove("recording");
  hotkeyBtn.textContent = formatHotkey(macCode, flags);
  updateSettings({ hotkeyCode: macCode, hotkeyFlags: flags });
});

// ---------------------------------------------------------------------------
//  Status polling
// ---------------------------------------------------------------------------

async function fetchStatus() {
  try {
    const res = await fetch(`${API}/status?source=${XPIP_SOURCE}`);
    const data = await res.json();
    if (!data || typeof data !== "object" || data.enabled === undefined) {
      throw new Error("Invalid status response");
    }

    pipIsActive = !!data.videoPipActive;
    updatePipButton();
    updateDoomButton(!!data.doomContent);

    if (data.doomContent) {
      els.statusLabel.textContent = "Doom PiP active";
    } else if (data.videoPipActive) {
      els.statusLabel.textContent = "PiP active";
    } else {
      els.statusLabel.textContent = "Online";
    }
    els.status.className = "status online";

    els.toggle.checked = data.enabled;
    els.glow.checked = data.glow;
    setActiveZone(closestZone(data.cornerSize));
    if (data.hotkeyCode !== undefined) {
      hotkeyBtn.textContent = formatHotkey(data.hotkeyCode, data.hotkeyFlags);
    }
    syncGameButtons(data);
    updateAudioUI(data.audio);
    if (data.glowColor) {
      setActiveColor(data.glowColor);
      applyColorAccent(data.glowColor);
    }

    return data;
    } catch {
      els.statusLabel.textContent = "Offline \u2014 click to restart";
      els.status.className = "status offline";
      pipIsActive = false;
      updatePipButton();
      updateDoomButton(false);
      hideAudioUI();
      return null;
    }
}

setInterval(fetchStatus, 2000);
