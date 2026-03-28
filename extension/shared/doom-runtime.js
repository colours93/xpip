(() => {
  if (globalThis.XPipDoomRuntime) return;

  const SCREEN_W = 320;
  const SCREEN_H = 200;
  const TEX_SIZE = 16;
  const FOV = Math.PI / 3;
  const API = "http://127.0.0.1:51789";
  const MAP_STRINGS = [
    "1111111111111111111111111",
    "1S00000001000000000000001",
    "1000000001000000000000001",
    "1000000001000E00000000001",
    "1000000001000000000000001",
    "1000000001000000001111111",
    "1000E000010000000E1000001",
    "1000000001111110001000001",
    "1000000000000010001000001",
    "1000000000000010001000A01",
    "1111111300000010001000001",
    "1000000000000000001111121",
    "100000000E000000000000021",
    "1000H0000000000000E000021",
    "1000000000000000000000021",
    "1222111100001111100000021",
    "1000000100E00000100000021",
    "1000000100000000111211111",
    "10000001000000E0000000001",
    "1000A0010000000000000H001",
    "1000000100000000000000001",
    "1333331100000011111000001",
    "1000000000E000000010E0001",
    "1000000000000000000100001",
    "1111111111111111111111111",
  ];
  const WAD_PREFERENCE = ["freedoom2.wad", "doom2.wad", "freedoom1.wad", "doom1.wad"];

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function wrapAngle(angle) {
    while (angle <= -Math.PI) angle += Math.PI * 2;
    while (angle > Math.PI) angle -= Math.PI * 2;
    return angle;
  }

  function createTexture(fillA, fillB) {
    const out = new Uint8Array(TEX_SIZE * TEX_SIZE * 4);
    for (let y = 0; y < TEX_SIZE; y += 1) {
      for (let x = 0; x < TEX_SIZE; x += 1) {
        const stripe = ((x >> 2) + (y >> 2)) % 2;
        const accent = (x === 0 || y === 0 || x === TEX_SIZE - 1 || y === TEX_SIZE - 1);
        const c = accent ? fillB : stripe ? fillA : fillB;
        const o = (y * TEX_SIZE + x) * 4;
        out[o] = c[0];
        out[o + 1] = c[1];
        out[o + 2] = c[2];
        out[o + 3] = 255;
      }
    }
    return out;
  }

  function createSpriteTexture(fill, eye) {
    const size = 16;
    const out = new Uint8Array(size * size * 4);
    for (let y = 0; y < size; y += 1) {
      for (let x = 0; x < size; x += 1) {
        const dx = x - 7.5;
        const dy = y - 8;
        const r2 = dx * dx + dy * dy;
        const o = (y * size + x) * 4;
        if (r2 > 54) {
          out[o + 3] = 0;
          continue;
        }
        out[o] = fill[0];
        out[o + 1] = fill[1];
        out[o + 2] = fill[2];
        out[o + 3] = 255;
        if ((y === 6 || y === 7) && (x === 5 || x === 10)) {
          out[o] = eye[0];
          out[o + 1] = eye[1];
          out[o + 2] = eye[2];
        }
      }
    }
    return { data: out, width: size, height: size };
  }

  const BUILTIN_WALLS = [
    createTexture([92, 96, 110], [54, 58, 70]),
    createTexture([146, 58, 54], [88, 30, 28]),
    createTexture([56, 110, 120], [30, 64, 74]),
  ];
  const ENEMY_SPRITE = createSpriteTexture([204, 72, 54], [250, 242, 214]);
  const HEALTH_SPRITE = createSpriteTexture([80, 170, 120], [230, 255, 230]);
  const AMMO_SPRITE = createSpriteTexture([210, 168, 72], [255, 244, 214]);

  function parseMap() {
    const mapH = MAP_STRINGS.length;
    const mapW = MAP_STRINGS[0].length;
    const tiles = new Array(mapW * mapH).fill(0);
    const enemies = [];
    const items = [];
    let player = { x: 1.5, y: 1.5, angle: 0 };

    for (let y = 0; y < mapH; y += 1) {
      const row = MAP_STRINGS[y];
      for (let x = 0; x < mapW; x += 1) {
        const ch = row[x];
        const idx = y * mapW + x;
        if (ch === "1" || ch === "2" || ch === "3") {
          tiles[idx] = Number(ch);
        } else {
          tiles[idx] = 0;
          if (ch === "S") {
            player = { x: x + 0.5, y: y + 0.5, angle: 0 };
          } else if (ch === "E") {
            enemies.push({ x: x + 0.5, y: y + 0.5, health: 45, alive: true, cooldown: 0, hurt: 0 });
          } else if (ch === "H") {
            items.push({ x: x + 0.5, y: y + 0.5, kind: "health", picked: false });
          } else if (ch === "A") {
            items.push({ x: x + 0.5, y: y + 0.5, kind: "ammo", picked: false });
          }
        }
      }
    }

    return { mapW, mapH, tiles, enemies, items, player };
  }

  function isWall(state, x, y) {
    const ix = Math.floor(x);
    const iy = Math.floor(y);
    if (ix < 0 || iy < 0 || ix >= state.mapW || iy >= state.mapH) return 1;
    return state.tiles[iy * state.mapW + ix];
  }

  function walkable(state, x, y) {
    return isWall(state, x, y) === 0;
  }

  function moveWithCollision(state, dx, dy) {
    const radius = 0.18;
    const nx = state.player.x + dx;
    const ny = state.player.y + dy;
    if (walkable(state, nx + Math.sign(dx || 1) * radius, state.player.y)
      && walkable(state, nx - Math.sign(dx || 1) * radius, state.player.y)) {
      state.player.x = nx;
    }
    if (walkable(state, state.player.x, ny + Math.sign(dy || 1) * radius)
      && walkable(state, state.player.x, ny - Math.sign(dy || 1) * radius)) {
      state.player.y = ny;
    }
  }

  function canSeeTarget(state, fromX, fromY, toX, toY) {
    const dx = toX - fromX;
    const dy = toY - fromY;
    const dist = Math.hypot(dx, dy);
    const steps = Math.max(1, Math.ceil(dist * 10));
    for (let i = 1; i < steps; i += 1) {
      const t = i / steps;
      const x = fromX + dx * t;
      const y = fromY + dy * t;
      if (isWall(state, x, y) !== 0) return false;
    }
    return true;
  }

  function castRay(state, angle) {
    const dirX = Math.cos(angle);
    const dirY = Math.sin(angle);
    let mapX = Math.floor(state.player.x);
    let mapY = Math.floor(state.player.y);
    const deltaDistX = dirX === 0 ? 1e30 : Math.abs(1 / dirX);
    const deltaDistY = dirY === 0 ? 1e30 : Math.abs(1 / dirY);

    let stepX = 0;
    let stepY = 0;
    let sideDistX = 0;
    let sideDistY = 0;

    if (dirX < 0) {
      stepX = -1;
      sideDistX = (state.player.x - mapX) * deltaDistX;
    } else {
      stepX = 1;
      sideDistX = (mapX + 1 - state.player.x) * deltaDistX;
    }

    if (dirY < 0) {
      stepY = -1;
      sideDistY = (state.player.y - mapY) * deltaDistY;
    } else {
      stepY = 1;
      sideDistY = (mapY + 1 - state.player.y) * deltaDistY;
    }

    let hit = 0;
    let side = 0;
    let guard = 0;
    while (!hit && guard < 96) {
      if (sideDistX < sideDistY) {
        sideDistX += deltaDistX;
        mapX += stepX;
        side = 0;
      } else {
        sideDistY += deltaDistY;
        mapY += stepY;
        side = 1;
      }
      const tile = isWall(state, mapX + 0.001, mapY + 0.001);
      if (tile !== 0) hit = tile;
      guard += 1;
    }

    const dist = side === 0
      ? (mapX - state.player.x + (1 - stepX) / 2) / (dirX || 0.0001)
      : (mapY - state.player.y + (1 - stepY) / 2) / (dirY || 0.0001);

    let wallX = side === 0
      ? state.player.y + dist * dirY
      : state.player.x + dist * dirX;
    wallX -= Math.floor(wallX);

    return {
      dist: Math.max(dist, 0.001),
      side,
      tile: hit || 1,
      texX: Math.floor(clamp(wallX, 0, 0.999) * TEX_SIZE),
    };
  }

  function setPixel(buffer, x, y, r, g, b, a = 255) {
    if (x < 0 || y < 0 || x >= SCREEN_W || y >= SCREEN_H) return;
    const o = (y * SCREEN_W + x) * 4;
    buffer[o] = r;
    buffer[o + 1] = g;
    buffer[o + 2] = b;
    buffer[o + 3] = a;
  }

  function shade(value, factor) {
    return clamp(Math.round(value * factor), 0, 255);
  }

  function renderFrame(state) {
    const { frame, zBuffer, textures } = state;

    for (let y = 0; y < SCREEN_H; y += 1) {
      const top = y < SCREEN_H / 2;
      const shadeFactor = top
        ? 0.35 + (y / (SCREEN_H / 2)) * 0.25
        : 0.18 + ((y - SCREEN_H / 2) / (SCREEN_H / 2)) * 0.32;
      const c = top ? [18, 16, 20] : [30, 18, 14];
      for (let x = 0; x < SCREEN_W; x += 1) {
        setPixel(frame, x, y, shade(c[0], shadeFactor), shade(c[1], shadeFactor), shade(c[2], shadeFactor));
      }
    }

    for (let x = 0; x < SCREEN_W; x += 1) {
      const camera = (x / SCREEN_W) - 0.5;
      const ray = castRay(state, state.player.angle + camera * FOV);
      const lineHeight = Math.floor(SCREEN_H / ray.dist);
      const drawStart = Math.max(0, Math.floor((SCREEN_H - lineHeight) / 2));
      const drawEnd = Math.min(SCREEN_H - 1, Math.floor((SCREEN_H + lineHeight) / 2));
      const tex = textures[(ray.tile - 1) % textures.length] || BUILTIN_WALLS[0];
      zBuffer[x] = ray.dist;

      for (let y = drawStart; y <= drawEnd; y += 1) {
        const d = (y - drawStart) / Math.max(1, drawEnd - drawStart + 1);
        const texY = Math.floor(clamp(d, 0, 0.999) * TEX_SIZE);
        const src = (texY * TEX_SIZE + ray.texX) * 4;
        const fog = clamp(1 - ray.dist / 16, 0.24, 1);
        const sideShade = ray.side ? 0.78 : 1;
        setPixel(
          frame,
          x,
          y,
          shade(tex[src], fog * sideShade),
          shade(tex[src + 1], fog * sideShade),
          shade(tex[src + 2], fog * sideShade)
        );
      }
    }

    const sprites = [];
    for (const enemy of state.enemies) {
      if (!enemy.alive) continue;
      sprites.push({
        x: enemy.x,
        y: enemy.y,
        dist: Math.hypot(enemy.x - state.player.x, enemy.y - state.player.y),
        tex: ENEMY_SPRITE,
      });
    }
    for (const item of state.items) {
      if (item.picked) continue;
      sprites.push({
        x: item.x,
        y: item.y,
        dist: Math.hypot(item.x - state.player.x, item.y - state.player.y),
        tex: item.kind === "health" ? HEALTH_SPRITE : AMMO_SPRITE,
      });
    }

    sprites.sort((a, b) => b.dist - a.dist);
    for (const sprite of sprites) {
      const dx = sprite.x - state.player.x;
      const dy = sprite.y - state.player.y;
      const dist = Math.hypot(dx, dy);
      const angle = wrapAngle(Math.atan2(dy, dx) - state.player.angle);
      if (Math.abs(angle) > FOV * 0.7 || dist <= 0.2) continue;
      const size = Math.floor(SCREEN_H / dist);
      const centerX = Math.floor((0.5 + angle / FOV) * SCREEN_W);
      const startX = Math.max(0, centerX - Math.floor(size / 2));
      const endX = Math.min(SCREEN_W - 1, centerX + Math.floor(size / 2));
      const startY = Math.max(0, Math.floor((SCREEN_H - size) / 2));
      const endY = Math.min(SCREEN_H - 1, Math.floor((SCREEN_H + size) / 2));
      for (let x = startX; x <= endX; x += 1) {
        if (dist >= zBuffer[x]) continue;
        const u = Math.floor(((x - startX) / Math.max(1, endX - startX + 1)) * sprite.tex.width);
        for (let y = startY; y <= endY; y += 1) {
          const v = Math.floor(((y - startY) / Math.max(1, endY - startY + 1)) * sprite.tex.height);
          const src = (v * sprite.tex.width + u) * 4;
          const alpha = sprite.tex.data[src + 3];
          if (!alpha) continue;
          const fog = clamp(1 - dist / 14, 0.28, 1);
          setPixel(
            frame,
            x,
            y,
            shade(sprite.tex.data[src], fog),
            shade(sprite.tex.data[src + 1], fog),
            shade(sprite.tex.data[src + 2], fog),
            alpha
          );
        }
      }
    }

    if (state.damageFlash > 0.01) {
      const alpha = clamp(state.damageFlash, 0, 0.7);
      for (let y = 0; y < SCREEN_H; y += 1) {
        for (let x = 0; x < SCREEN_W; x += 1) {
          const o = (y * SCREEN_W + x) * 4;
          frame[o] = shade(frame[o] + 120, 1);
          frame[o + 1] = shade(frame[o + 1], 1 - alpha * 0.6);
          frame[o + 2] = shade(frame[o + 2], 1 - alpha * 0.6);
        }
      }
    }
  }

  function shoot(state) {
    if (state.shotCooldown > 0 || state.gameOver) return;
    if (state.ammo <= 0) return;
    state.ammo -= 1;
    state.shotCooldown = 0.24;
    state.muzzleTimer = 0.08;

    let best = null;
    let bestDist = 1e9;
    for (const enemy of state.enemies) {
      if (!enemy.alive) continue;
      const dx = enemy.x - state.player.x;
      const dy = enemy.y - state.player.y;
      const dist = Math.hypot(dx, dy);
      const angle = Math.abs(wrapAngle(Math.atan2(dy, dx) - state.player.angle));
      if (angle > 0.09) continue;
      if (!canSeeTarget(state, state.player.x, state.player.y, enemy.x, enemy.y)) continue;
      if (dist < bestDist) {
        best = enemy;
        bestDist = dist;
      }
    }

    if (best) {
      best.health -= 25;
      best.hurt = 0.18;
      if (best.health <= 0) {
        best.alive = false;
        state.kills += 1;
      }
    }
  }

  function updateState(state, dt) {
    if (state.gameOver) return;

    const moveSpeed = state.keys.ShiftLeft || state.keys.ShiftRight ? 3.5 : 2.55;
    const turnSpeed = 2.1;
    const forwardX = Math.cos(state.player.angle);
    const forwardY = Math.sin(state.player.angle);
    const strafeX = Math.cos(state.player.angle + Math.PI / 2);
    const strafeY = Math.sin(state.player.angle + Math.PI / 2);

    if (state.keys.ArrowLeft) state.player.angle -= turnSpeed * dt;
    if (state.keys.ArrowRight) state.player.angle += turnSpeed * dt;
    if (state.keys.KeyQ) state.player.angle -= turnSpeed * dt;
    if (state.keys.KeyE) state.player.angle += turnSpeed * dt;
    state.player.angle = wrapAngle(state.player.angle);

    let moveX = 0;
    let moveY = 0;
    if (state.keys.KeyW || state.keys.ArrowUp) {
      moveX += forwardX * moveSpeed * dt;
      moveY += forwardY * moveSpeed * dt;
    }
    if (state.keys.KeyS || state.keys.ArrowDown) {
      moveX -= forwardX * moveSpeed * dt;
      moveY -= forwardY * moveSpeed * dt;
    }
    if (state.keys.KeyA) {
      moveX -= strafeX * moveSpeed * dt * 0.8;
      moveY -= strafeY * moveSpeed * dt * 0.8;
    }
    if (state.keys.KeyD) {
      moveX += strafeX * moveSpeed * dt * 0.8;
      moveY += strafeY * moveSpeed * dt * 0.8;
    }
    moveWithCollision(state, moveX, moveY);

    state.shotCooldown = Math.max(0, state.shotCooldown - dt);
    state.muzzleTimer = Math.max(0, state.muzzleTimer - dt);
    state.damageFlash = Math.max(0, state.damageFlash - dt * 1.8);

    for (const enemy of state.enemies) {
      if (!enemy.alive) continue;
      enemy.cooldown = Math.max(0, enemy.cooldown - dt);
      enemy.hurt = Math.max(0, enemy.hurt - dt);
      const dx = state.player.x - enemy.x;
      const dy = state.player.y - enemy.y;
      const dist = Math.hypot(dx, dy);
      if (dist > 0.6 && dist < 8 && canSeeTarget(state, enemy.x, enemy.y, state.player.x, state.player.y)) {
        const speed = 0.72 * dt;
        const nx = enemy.x + (dx / dist) * speed;
        const ny = enemy.y + (dy / dist) * speed;
        if (walkable(state, nx, ny)) {
          enemy.x = nx;
          enemy.y = ny;
        }
      }
      if (dist < 1.15 && enemy.cooldown <= 0) {
        enemy.cooldown = 1.0;
        state.health = Math.max(0, state.health - 8);
        state.damageFlash = 0.65;
        if (state.health <= 0) {
          state.gameOver = true;
        }
      }
    }

    for (const item of state.items) {
      if (item.picked) continue;
      const dist = Math.hypot(item.x - state.player.x, item.y - state.player.y);
      if (dist > 0.6) continue;
      item.picked = true;
      if (item.kind === "health") {
        state.health = Math.min(100, state.health + 25);
      } else {
        state.ammo = Math.min(50, state.ammo + 12);
      }
    }
  }

  async function fetchArrayBuffer(url) {
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) return null;
    return res.arrayBuffer();
  }

  function readAscii(bytes, start, len) {
    let out = "";
    for (let i = 0; i < len; i += 1) {
      const value = bytes[start + i];
      if (!value) break;
      out += String.fromCharCode(value);
    }
    return out;
  }

  function decodeWadTextures(buffer) {
    const bytes = new Uint8Array(buffer);
    if (bytes.length < 12) return null;
    const view = new DataView(buffer);
    const sig = readAscii(bytes, 0, 4);
    if (sig !== "IWAD" && sig !== "PWAD") return null;
    const lumpCount = view.getInt32(4, true);
    const dirOffset = view.getInt32(8, true);
    if (dirOffset <= 0 || dirOffset + lumpCount * 16 > bytes.length) return null;

    const dir = [];
    for (let i = 0; i < lumpCount; i += 1) {
      const o = dirOffset + i * 16;
      dir.push({
        offset: view.getInt32(o, true),
        size: view.getInt32(o + 4, true),
        name: readAscii(bytes, o + 8, 8),
      });
    }

    const pal = dir.find((lump) => lump.name === "PLAYPAL" && lump.size >= 768);
    if (!pal) return null;
    const palette = bytes.slice(pal.offset, pal.offset + 768);

    let inFlats = false;
    let flatNames = dir.filter((lump) => {
      if (lump.name === "F_START" || lump.name === "FF_START") {
        inFlats = true;
        return false;
      }
      if (lump.name === "F_END" || lump.name === "FF_END") {
        inFlats = false;
        return false;
      }
      return inFlats && lump.size >= 4096;
    });
    if (!flatNames.length) {
      flatNames = dir.filter((lump) => lump.size >= 4096);
    }

    const textures = [];
    for (const lump of flatNames.slice(0, 16)) {
      const out = new Uint8Array(TEX_SIZE * TEX_SIZE * 4);
      const flat = bytes.slice(lump.offset, lump.offset + 4096);
      for (let y = 0; y < TEX_SIZE; y += 1) {
        for (let x = 0; x < TEX_SIZE; x += 1) {
          const idx = (y * 4) * 64 + (x * 4);
          const palIdx = flat[idx] * 3;
          const o = (y * TEX_SIZE + x) * 4;
          out[o] = palette[palIdx];
          out[o + 1] = palette[palIdx + 1];
          out[o + 2] = palette[palIdx + 2];
          out[o + 3] = 255;
        }
      }
      textures.push(out);
    }

    return textures.length ? textures : null;
  }

  async function loadPreferredTextures() {
    for (const name of WAD_PREFERENCE) {
      try {
        const buffer = await fetchArrayBuffer(`${API}/wads/${name}`);
        if (!buffer) continue;
        const textures = decodeWadTextures(buffer);
        if (textures && textures.length) {
          return { textures, source: name };
        }
      } catch {}
    }
    return { textures: BUILTIN_WALLS, source: "built-in" };
  }

  function installMarkup(doc) {
    doc.head.innerHTML = `
      <style>
        :root { color-scheme: dark; }
        * { box-sizing: border-box; }
        html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: #080808; color: #f5f1e7; font-family: "Menlo", "Monaco", monospace; }
        body { display: grid; grid-template-rows: 1fr auto; }
        .shell { position: relative; width: 100%; height: 100%; overflow: hidden; background:
          radial-gradient(circle at top, rgba(134, 38, 23, 0.3), transparent 48%),
          linear-gradient(180deg, #130d0a 0%, #050505 100%);
        }
        canvas { width: 100%; height: 100%; display: block; image-rendering: pixelated; }
        .hud {
          position: absolute;
          inset: auto 10px 10px 10px;
          display: flex;
          justify-content: space-between;
          gap: 12px;
          padding: 8px 10px;
          border: 1px solid rgba(255,255,255,0.14);
          background: rgba(0,0,0,0.58);
          backdrop-filter: blur(8px);
          font-size: 11px;
          letter-spacing: 0.08em;
          text-transform: uppercase;
        }
        .banner {
          position: absolute;
          top: 10px;
          left: 10px;
          right: 10px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 12px;
          font-size: 10px;
          letter-spacing: 0.12em;
          text-transform: uppercase;
          color: rgba(245, 241, 231, 0.74);
        }
        .banner .title {
          padding: 6px 10px;
          background: rgba(0,0,0,0.5);
          border: 1px solid rgba(255,255,255,0.14);
        }
        .game-over {
          position: absolute;
          inset: 0;
          display: none;
          align-items: center;
          justify-content: center;
          background: rgba(12, 0, 0, 0.72);
          font-size: 18px;
          letter-spacing: 0.16em;
          text-transform: uppercase;
        }
        .game-over.visible { display: flex; }
        .footer {
          padding: 8px 10px;
          background: #0a0a0a;
          border-top: 1px solid rgba(255,255,255,0.08);
          font-size: 10px;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          color: rgba(245, 241, 231, 0.65);
        }
      </style>
    `;
    doc.body.innerHTML = `
      <div class="shell">
        <canvas width="${SCREEN_W}" height="${SCREEN_H}"></canvas>
        <div class="banner">
          <div class="title">XPip Doom</div>
          <div class="wad"></div>
        </div>
        <div class="hud">
          <span class="health"></span>
          <span class="ammo"></span>
          <span class="kills"></span>
        </div>
        <div class="game-over">Game Over - Press R</div>
      </div>
      <div class="footer">WASD move, mouse or arrows turn, click or space shoot, Esc close</div>
    `;
  }

  function createGameState(textureSet) {
    const parsed = parseMap();
    return {
      mapW: parsed.mapW,
      mapH: parsed.mapH,
      tiles: parsed.tiles,
      enemies: parsed.enemies,
      items: parsed.items,
      player: parsed.player,
      health: 100,
      ammo: 25,
      kills: 0,
      textures: textureSet.textures,
      wadSource: textureSet.source,
      keys: Object.create(null),
      shotCooldown: 0,
      muzzleTimer: 0,
      damageFlash: 0,
      gameOver: false,
    };
  }

  async function start(pipWindow, sessionInfo = {}) {
    const doc = pipWindow.document;
    installMarkup(doc);

    const canvas = doc.querySelector("canvas");
    const ctx = canvas.getContext("2d", { alpha: false, willReadFrequently: false });
    ctx.imageSmoothingEnabled = false;
    const imageData = ctx.createImageData(SCREEN_W, SCREEN_H);

    const textureSet = await loadPreferredTextures();
    const state = createGameState(textureSet);
    state.frame = imageData.data;
    state.zBuffer = new Float32Array(SCREEN_W);
    state.lastFrame = pipWindow.performance.now();

    const healthEl = doc.querySelector(".health");
    const ammoEl = doc.querySelector(".ammo");
    const killsEl = doc.querySelector(".kills");
    const wadEl = doc.querySelector(".wad");
    const gameOverEl = doc.querySelector(".game-over");
    wadEl.textContent = `Textures: ${state.wadSource}`;

    const updateHud = () => {
      healthEl.textContent = `Health ${state.health}`;
      ammoEl.textContent = `Ammo ${state.ammo}`;
      killsEl.textContent = `Kills ${state.kills}`;
      gameOverEl.classList.toggle("visible", !!state.gameOver);
    };

    const onKeyDown = (event) => {
      state.keys[event.code] = true;
      if (event.code === "Space") {
        shoot(state);
        event.preventDefault();
      } else if (event.code === "Escape") {
        pipWindow.close();
        event.preventDefault();
      } else if (event.code === "KeyR" && state.gameOver) {
        const reset = createGameState(textureSet);
        Object.assign(state, reset, {
          frame: imageData.data,
          zBuffer: new Float32Array(SCREEN_W),
          lastFrame: pipWindow.performance.now(),
        });
        event.preventDefault();
      }
    };

    const onKeyUp = (event) => {
      state.keys[event.code] = false;
    };

    const onMouseDown = () => {
      shoot(state);
      doc.body.focus();
    };

    const onMouseMove = (event) => {
      if (typeof event.movementX === "number" && event.movementX !== 0) {
        state.player.angle = wrapAngle(state.player.angle + event.movementX * 0.0045);
      }
    };

    const onContextMenu = (event) => {
      event.preventDefault();
    };

    pipWindow.addEventListener("keydown", onKeyDown);
    pipWindow.addEventListener("keyup", onKeyUp);
    canvas.addEventListener("mousedown", onMouseDown);
    canvas.addEventListener("mousemove", onMouseMove);
    canvas.addEventListener("contextmenu", onContextMenu);
    doc.body.tabIndex = -1;
    doc.body.focus();

    const loop = (now) => {
      const dt = Math.min(0.05, (now - state.lastFrame) / 1000);
      state.lastFrame = now;
      updateState(state, dt);
      renderFrame(state);
      ctx.putImageData(imageData, 0, 0);
      updateHud();
      if (!pipWindow.closed) {
        pipWindow.requestAnimationFrame(loop);
      }
    };

    pipWindow.requestAnimationFrame(loop);
    updateHud();
  }

  globalThis.XPipDoomRuntime = {
    start,
  };
})();
