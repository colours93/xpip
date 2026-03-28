# XPip

A macOS daemon + Chrome extension that makes Picture-in-Picture windows dodge your mouse cursor — and turns them into retro arcade machines.

XPip watches your cursor at 60 fps and flings PiP windows away when you approach from the side. Sneak in from a corner to interact with playback controls. Toggle an animated RGB glow border. Or launch one of 15 built-in mini-games that use the PiP window as a game object bouncing around your screen.

## Features

- **Smart dodge** — PiP jumps to the farthest screen corner on side-edge entry, allows corner-zone interaction for playback controls
- **Animated glow border** — 1px rotating conic gradient in purple, blue, red, green, or rainbow
- **15 arcade games** — PiPong, PiPong 2, Flappy Bird, Bounce (auto + paddle), Space Invaders, Frogger, Runner, Snake, Breakout, Asteroids, Cursor Hunt, Doodle Jump, Pac-Man, Mario, Doom
- **Chrome extension** — popup UI for PiP control, game launcher, settings, and per-PiP volume
- **Auto-PiP** — automatically enters PiP when switching tabs (via Media Session API)
- **Global hotkey** — configurable keyboard shortcut (default: Cmd+Shift+D)
- **Sound effects** — 5 SFX events mapped to system sounds
- **Launchd integration** — auto-starts on login, logs to `~/.xpip/xpip.log`
- **Zero dependencies** — pure Swift, compiled with `swiftc`, only system frameworks

## Install

### Quick (dev)

```bash
bash dev.sh
```

Compile + sign + restart. Preserves Accessibility TCC grant.

### Full

```bash
bash install.sh
```

Full pipeline: compile, sign with hardened runtime, generate extension icons, install launchd agent.

### Distribution

```bash
NOTARIZE=1 APPLE_ID=... TEAM_ID=... APP_PASSWORD=... bash install.sh   # notarize
DMG=1 bash install.sh                                                    # build .dmg
```

## Chrome Extension

Load unpacked from the `extension/` directory. The extension communicates with the daemon over HTTP on `localhost:51789`.

Features: start PiP on any video, launch/stop games, toggle dodge + glow, set glow color, adjust volume, configure hotkey and corner zone size.

## Accessibility

The daemon needs Accessibility permission to move PiP windows.

System Settings > Privacy & Security > Accessibility > add `~/.xpip/xpip.app`

An onboarding window guides first-time users through this.

## Architecture

```
daemon/                  Swift macOS daemon (pure swiftc, no Xcode)
  DodgeDaemon.swift      Core dodge logic, PiP tracking, animation
  ControlServer.swift    HTTP API (port 51789) for Chrome extension
  MenuBarController.swift  Menu bar icon + settings + game launcher
  Games/Arcade/          15 built-in mini-games
  Games/GameBase.swift   Shared game infrastructure
extension/               Chrome extension (popup, background, content scripts)
safari/                  Safari web extension (stub)
docs/                    Architecture documentation
install.sh               Full build + sign + launchd install
dev.sh                   Fast dev rebuild
uninstall.sh             Standalone uninstall
```

## License

MIT
