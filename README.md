# Brainrot Blast — roblox-brainrot-01

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/Bozet404/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/Bozet404/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

A 3D Roblox brainrot game, built from scratch in Luau with Rojo. Absurd
characters walk down a trail from the Brainrot Gate, you catch them, keep
them on your base, and they earn money every second while you climb a ladder
of rarities, mutations and rebirths — and while other players try to steal
them and a tsunami sweeps the map.

## How it plays

| Step | What happens |
|---|---|
| Catch | A brainrot walks the trail from the north gate. Walk close and press **E**, or click / tap it, to buy it for its price. |
| Earn | It stands on a slot in your base and pays its $/second into your Cash, every second, forever. |
| Climb | 12 original characters across 6 rarities: Common → Rare → Epic → Legendary → Mythic → Brainrot God ($5/s up to $8000/s). |
| Mutate | Every catch can roll Golden (x2), Diamond (x4) or Rainbow (x8) $/second. |
| Rebirth | The HUD **REBIRTH** button resets your cash and brainrots for a permanent +50% income multiplier per rebirth. |
| Steal | Press **E** (or the **CURI** button) near a brainrot on someone else's base to grab it — you walk slow while carrying it, the owner gets an alert, and you have 15 seconds to reach your base. |
| Survive | Every 90 seconds a tsunami warning sounds; 10 seconds later a wave sweeps the trail. Anyone outside their base is flung and drops what they stole. |

## Controls

| Control | What it does |
|---|---|
| **E** | Catch the nearest walking brainrot, or steal the nearest brainrot on another player's base |
| Click / tap a brainrot | Same as E, on that brainrot |
| **REBIRTH** button | Rebirth (needs cash for the threshold and at least 1 brainrot) |
| **CURI** button | Steal the nearest stealable brainrot (touch-friendly) |
| Arrow keys / WASD | Move your character through the 3D world |

## Layout

- `src/shared/BrainrotData.luau` — the catalogue: rarities, 12 characters, prices, $/second, mutation rolls, rebirth rules. Server and client share it.
- `src/server/World.luau` — builds the 3D world at runtime: plaza, trail, spawn gate, 8 player bases with 6 slots each, trees, lamps, tsunami wave.
- `src/server/Brainrots.luau` — builds each brainrot as a 3D model of Parts (body, head, eyes, accessory, rarity ring, name tag).
- `src/server/Main.server.luau` — economy, spawner, catch / steal / rebirth remotes, tsunami, leaderstats Cash. Every rule is checked server-side.
- `src/client/Main.client.luau` — HUD (cash, $/second, brainrot count, rebirth), E key via ContextActionService, buttons, tsunami banner, steal alerts.
- `main.ts` — hands the game in: copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output` and writes `dossier.json` with `vendor/makefun-roblox.ts` (unchanged kit copy).

## Build and hand in

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

## Status

- Rojo build and local `main.ts` run: done, dossier written.
- Screenshots: **blocked** — no Roblox Studio on this Linux VM, so no real gameplay captures exist yet. `screenshots/` is empty on purpose; no fake or AI image was substituted. Captures must be taken in Studio.
- Publish / `PLAY.json`: **blocked** — no Roblox account for this game was provided, so the place is not published and `PLAY.json` still holds the placeholder ids (0, 0). Publish from Studio, then fill in the real place and universe ids.
- Icon / thumbnail: **blocked** — uploaded on the Creator Dashboard by the account owner after publish; the thumbnail must match one of the screenshots.
- Live play-test: **not possible** without Studio. Every control is wired (see table above) but marked UNVERIFIED for live play until a human play-tests it in Studio.
