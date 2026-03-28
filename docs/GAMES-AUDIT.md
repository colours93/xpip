# XPip Games — Implementation Audit

Deep-dive audit of the daemon game engine and all game implementations. Analysis was performed by subagents across infrastructure, per-game behavior, and the sprite/pixel-art pipeline.

---

## Executive Summary

| Area | Score (1–10) | Summary |
|------|--------------|---------|
| **Infrastructure (GameBase, LayerPool)** | **7.5** | Solid protocol + base class, mach-time delta, consistent AX/NS handling. Gaps: no game calls `verifyPipAlive()`, `stop()` re-entrancy from `gameTick()` is fragile. |
| **Per-game implementation** | **B+** | All games use `deltaTime()` and correct coordinate handling. None use `verifyPipAlive()`; none use SoundKit; only 4 games use the layer pool. State and collision helpers are used well where applicable. |
| **Sprites / pixel-art** | **7** | Single pipeline, baked-at-load, no hot-path allocation. Unused `pixelArtLayer`; PerkSprites outside `Sprites/`; scale 2 vs 3 inconsistent. |

**Top recommendations:** (1) Add `verifyPipAlive()` at top of every `gameTick()` (or in base). (2) Use `checkGameOverTimeout()` in Flappy/PacMan instead of custom delays. (3) Consider SoundKit for key events. (4) Use layer pool in Flappy (pipes), Breakout (bricks), PacMan (dots). (5) Harden `stop()` re-entrancy (e.g. set `active = false` and return immediately when `stop()` is invoked from `gameTick()`).

---

## 1. Infrastructure Audit (GameBase, LayerPool, Lifecycle)

### 1.1 Architecture (8/10)

- **Protocol + base class:** `MiniGame` defines `active`, `lastBounds`, `start`, `stop`. `GameBase` implements them and adds mach time, timer, overlays, border sync, PiP movement, collision helpers, pixel-art helpers. Games subclass `GameBase` and override `onStart`, `onStop`, `gameTick`. Clear split.
- **Lifecycle:** `start(screen:pip:border)` sets refs, `screenH`, `lastMach`, calls `onStart`, sets `active = true`, starts timer. `stop()` cancels timer, restores PiP position, clears border, calls `onStop()`, `layerPool.drain()`, orders out score overlay.
- **Timer:** Each game has its own `DispatchSourceTimer` on `.main` with configurable `timerIntervalMs` and 100µs leeway. No shared game clock; each game uses `deltaTime()` from mach time.

**Strengths:** Single extension point; central registry `Games.create(name)`; `otherActivePipBounds` for multi-PiP.

**Weaknesses:** Game list duplicated (names + switch in `Games.swift`; route order in ControlServer); `lastBounds` not enforced by base.

### 1.2 Correctness (7/10)

- **deltaTime:** Clamped to 50 ms; prevents physics spikes on stall. Correct.
- **AX/NS:** `screenH` and `axToNS` usage are consistent across games. No AX/NS mix-up found.
- **verifyPipAlive:** Implemented in GameBase but **no game calls it** in `gameTick()`. PiP liveness is only detected when `movePip()` or other AX calls fail. Doc suggests “call at top of gameTick()”; currently optional and unused.
- **stop() re-entrancy:** If `stop()` is called from inside `gameTick()` (e.g. from `movePip()`), the rest of the same tick can still run with partially torn-down state. Fragile.

### 1.3 Performance (7/10)

- **Layer pool:** Used in Runner, PiPong, Asteroids, Invaders. Flappy (pipes), Breakout (bricks), Snake (tail windows), PacMan (dots) do not use it.
- **CATransaction:** `withTransaction` used consistently; batching and no implicit animations.
- **Sprites:** Baked at load; no per-tick allocation in pixel-art path.

### 1.4 Maintainability (8/10)

- Clear structure, shared helpers, good docs. Adding a game requires editing `Games.swift` and route ordering in ControlServer.

---

## 2. Per-Game Implementation Audit

### 2.1 Summary Table

| Game     | verifyPip / deltaTime   | Collision helpers   | Layer pool | SoundKit | State/cleanup        | Coord handling | Grade |
|----------|-------------------------|---------------------|------------|----------|------------------------|----------------|-------|
| PiPong   | deltaTime ✓, verify ✗   | No (manual rects)   | Yes        | No       | Custom match only      | OK             | B     |
| PiPong2  | (same pattern)          | —                   | —          | No       | —                      | OK             | B     |
| Flappy   | deltaTime ✓, verify ✗   | Yes                 | No         | No       | Yes (delay ≠ base)     | OK             | B+    |
| Snake    | deltaTime ✓, verify ✗   | Partial (wrap)      | No         | No       | Yes                    | OK             | B+    |
| Breakout | deltaTime ✓, verify ✗   | Yes                 | No         | No       | Yes                    | OK             | A-    |
| Bounce   | deltaTime ✓, verify ✗   | Yes                 | N/A        | No       | N/A (endless)          | OK             | A    |
| PacMan   | deltaTime ✓, verify ✗   | Partial (distance)  | No         | No       | Inlined timeout        | OK             | B    |
| Invaders | deltaTime ✓, verify ✗   | Yes                 | Yes        | No       | Yes                    | OK             | A-   |
| Frogger  | deltaTime ✓, verify ✗   | Yes                 | No         | No       | Yes                    | OK             | B+   |
| Runner   | deltaTime ✓, verify ✗   | Yes                 | Yes        | No       | Yes                    | OK             | A-   |
| Asteroids| deltaTime ✓, verify ✗   | Yes                 | Yes        | No       | Yes                    | OK             | A-   |
| CursorHunt | deltaTime ✓, verify ✗ | Yes                 | No         | No       | Yes                    | OK             | B+   |
| DoodleJump | deltaTime ✓, verify ✗  | Yes                 | No         | No       | Yes                    | OK             | B+   |

### 2.2 Findings by Game

- **PiPong:** Uses layer pool for trail; manual paddle/ball rect checks (could use `rectsCollide`); no SoundKit; custom match flow.
- **Flappy:** Uses `rectsCollide` for pipes; `onStop()` closes `pipeOverlay`; dead phase uses fixed delay instead of `checkGameOverTimeout()`.
- **Snake:** Wrap-aware collision is custom by design; good use of state and `triggerGameOver`/`checkGameOverTimeout`.
- **Breakout:** Clear structure; `rectsCollide` for bricks; good state handling; brick layers not pooled.
- **Bounce:** Uses `rectsCollide` and `distance`; no game over by design.
- **PacMan:** Uses `distance` for ghost/player; inlined game-over timeout instead of `checkGameOverTimeout()`; dot layers not pooled.
- **Invaders / Runner / Asteroids:** Use layer pool; state and collision aligned with base.

### 2.3 Cross-Cutting Recommendations

1. **verifyPipAlive:** Call at the very start of every `gameTick()` (or in a base `gameTick()` wrapper that subclasses call).
2. **checkGameOverTimeout:** Use in Flappy and PacMan instead of fixed/inlined delay.
3. **SoundKit:** Add at least one SFX for central events (flap, hit, game over, pellet) where desired.
4. **Layer pool:** Use in Flappy (pipes), Breakout (bricks), PacMan (dots) where layers are created/destroyed frequently.
5. **Standardize tick preamble:** e.g. `guard verifyPipAlive() else { return }`; `let dt = deltaTime()`; then game-specific setup.

---

## 3. Sprites & Pixel-Art Audit

### 3.1 Sprite Files

| File / enum        | Exports |
|--------------------|--------|
| AsteroidsSprites   | Large/medium/small asteroid variants, bullet; scale 3 (small 2). |
| BounceSprites      | Paddle colors; scale 3. |
| BreakoutSprites    | Paddle, bricks (normal/damaged), row colors; scale 3. |
| DoodleJumpSprites  | Normal/moving platform images; scale 3. |
| FlappySprites      | Pipe cap/body images; scale 3. |
| FroggerSprites     | Motorcycles, cars, trucks; scale 2. |
| InvadersSprites    | Squid/crab/skull frames, UFO, bullets; scale 3. |
| PacManSprites      | Ghosts (Blinky/Pinky/Inky/Clyde), scared/eaten; no player sprite; scale 3. |
| RunnerSprites      | Zone tiles + caps; scale 3. |
| SnakeSprites       | Apple, head/mid/tail body; scale 3. |
| PerkSprites (BouncePerks+Sprites) | 12 perk icons; not under `Sprites/`. |

### 3.2 Pipeline

- **renderPixelArt:** 2D `[[UInt32]]` → `CGImage`; `0` = transparent; optional ARGB; scale = nearest-neighbor block. Correct and consistent.
- **pixelArtLayer:** Present in GameBase but **unused** (dead code).
- All games use Sprites enums; no inline pixel arrays in game files. Baked at load; no per-frame sprite allocation.

### 3.3 Rating: 7/10

**Strengths:** Single pipeline; baked once; clear transparency and scaling.

**Weaknesses:** `pixelArtLayer` unused; PerkSprites not in `Sprites/`; scale 2 vs 3 ad hoc; PacMan has no player sprite in PacManSprites.

### 3.4 Recommendations

1. Move PerkSprites under `Sprites/` or document why it stays with Bounce.
2. Remove or use `pixelArtLayer` (e.g. one shared “sprite layer” helper).
3. Shared default scale constant (e.g. 3); use 2 only where needed (Frogger, Asteroids small).
4. Add Pac-Man player sprite to PacManSprites if the player is drawn as pixel art.

---

## 4. Implementation Ratings (Consolidated)

| Game       | Implementation grade | Notes |
|------------|----------------------|--------|
| PiPong     | B                    | Pool ✓; no verifyPip, no collision helpers, no Sound. |
| PiPong2    | B                    | Same family as PiPong. |
| Flappy     | B+                   | rectsCollide ✓; use checkGameOverTimeout, consider pipe pool. |
| Snake      | B+                   | State ✓; wrap collision justified; add verifyPip, optional SFX. |
| Breakout   | A-                   | Strong use of base; add verifyPip, SFX, brick pool. |
| Bounce     | A                    | Good collision/distance; add verifyPip, optional SFX. |
| PacMan     | B                    | Use checkGameOverTimeout, verifyPip, optional SFX, dot pool. |
| Invaders   | A-                   | Pool ✓; state ✓; add verifyPip, optional SFX. |
| Frogger    | B+                   | Coords and state OK; add verifyPip, optional SFX. |
| Runner     | A-                   | Pool ✓; add verifyPip, optional SFX. |
| Asteroids  | A-                   | Pool ✓; add verifyPip, optional SFX. |
| CursorHunt | B+                   | Add verifyPip, optional SFX. |
| DoodleJump | B+                   | Add verifyPip, optional SFX. |

---

## 5. Document History

- **2025-03-05:** Initial audit from subagent deep dives (infrastructure, per-game, sprites).
