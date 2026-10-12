# Cat Commando — Playable Prototype (Godot 4)

Fixed-camera 2D arena survival shooter. A cat commando fights automatically
while waves of enemies close in. Built with **zero external image assets**:
every sprite is drawn in code with Godot shapes (`_draw()`), so AI-generated
PNG sprites can replace the placeholders later.

Future goal: TikTok LIVE interactive game (viewers spawn enemies / buffs).

## Project info

- Engine: **Godot 4.x** (GL Compatibility, Windows desktop)
- Language: **GDScript**
- Base resolution: **1280×720** (`canvas_items` stretch, `keep` aspect)
- Main scene: `res://scenes/main.tscn`
- No plugins, no paid assets. Character/weapon art: local PNGs in `assets/`
  with drawn-shape fallback if a file is missing.

## Project structure

```text
project.godot
scenes/
  main.tscn        # Root (GameManager) + Arena + CatPlayer + SpawnManager + Camera + HUD
  arena.tscn       # Dark futuristic arena background (drawn in code)
  cat_player.tscn  # Cat + BodySprite + WeaponMount/WeaponSprite, circle shape
  enemy.tscn       # Enemy placeholder (drawn in code, 4 visual types incl. boss)
scripts/
  game_manager.gd  # Score, timer, game-over, restart, debug keys (E/F/R/F1-F7)
  cat_player.gd    # Auto-aim, weapon system + abilities (LIVE-bridge API), HP 100
  weapon_data.gd   # Central weapon stat table (damage, fire rate, visuals)
  enemy.gd         # chaser / speeder / tank / boss, contact damage, hit flash
  spawn_manager.gd # Edge spawning + difficulty ramp + guarded boss spawn
  hud_manager.gd   # Health, score, time, weapon, ability timers, boss bar, debug
  bullet.gd        # Lifetime-pooled bullets + capped impact flashes
  rocket.gd        # Homing rockets with capped AoE explosions
  mega_laser.gd    # Charge-up arena beam, self-freeing
  explosion.gd     # Short-lived effects + global FX cap (MAX_FX = 30)
  arena.gd         # Background/grid/neon border drawing
  live_bridge.gd   # Local TCP command bridge (127.0.0.1:8765) for LIVE gifts
tools/tiktok_bridge/
  connector.py     # TikTok LIVE -> game bridge (needs TikTokLive package)
  bridge_client.py # Stdlib-only TCP client for the game bridge
  simulate.py      # Fake-gift test script (no TikTok needed)
  gift_mapping.json# Your username + gift-name -> game-command mapping
  requirements.txt # Python dependencies (TikTokLive)
README.md
```

### Collision layers (physics)

| Layer | Who      | Mask       |
| ----- | -------- | ---------- |
| 1     | Player   | 2 (enemy)  |
| 2     | Enemy    | 1 (player) |
| 4     | Bullet   | 2 (enemy)  |

Bullets/rockets are `Area2D` on layer 4 (mask 2) and detect enemy bodies.
Contact damage uses a per-enemy 0.8 s cooldown with distance checks.
Bullets live max 2 s, rockets max 3 s, both freed outside the arena;
enemies are capped (`max_enemies = 40`, absolute debug cap 50);
projectiles capped at 150 (rockets 12); explosions capped at 30 FX nodes.

### Signals

- `CatPlayer.health_changed / died / fired / weapon_changed`
- `Enemy.died(enemy, score_value)` → `GameManager._on_enemy_died`
- `Rocket.exploded`
- `SpawnManager.enemy_count_changed`
- `GameManager.score_changed / game_over`

## How to run

The terminal in this environment could not launch executables
(`bash` tool unavailable), so a headless check was **not** performed here.
Open and run it in the Godot editor instead:

```powershell
# From the project directory (contains project.godot):
godot --path "C:\khanh\cat-commando"
# or open Godot editor → Import → select project.godot → Run (F5)
```

Exact command to open this project in Godot (Windows):

```text
godot --path "C:\khanh\cat-commando"
```

Then press **F5** (Run Project). The main scene is already set to
`scenes/main.tscn`.

## How to play

- The **cat aims and shoots automatically** at the nearest living enemy.
- Enemies spawn at the arena edges and walk toward the cat.
- Bullets kill enemies → **score increases** (chaser +1, speeder +1, tank +3, Iron Behemoth +50).
- Enemies deal contact damage (chaser 10, speeder 6, tank 20, boss 25). Cat has **100 HP**.
- Survive as long as possible. **Game over at 0 HP** → click **RESTART** (or `R`).

## Weapons (local now, TikTok-gift triggered later)

All stats live in `scripts/weapon_data.gd`. No TikTok integration yet.

| Weapon | How it feels | Key stats |
| ------ | ------------ | --------- |
| Default Gun (fallback) | Unchanged original behavior | 0.35 s interval, dmg 1 |
| Machine Gun | Faster, smaller bullets, blue-tinted gun | 0.15 s interval, radius 4, dmg 1 |
| Giant Minigun | Triple barrels, 3-bullet fan per shot, muzzle flashes, impact sparks | 0.10 s interval, dmg 1 |
| Rocket Launcher | Slow homing rockets, big AoE explosion on impact | 0.9 s interval, dmg 3 + 3 AoE (r 120) |

The cat's drawn weapon visibly changes per gun (size, barrels, colors).

## Special abilities

| Ability | Effect | Config |
| ------- | ------ | ------ |
| Rapid Fire | Fire interval ×0.35 while active, previous rate restored automatically on expiry | 5 s, `F`/`F6` |
| Giant Gun | Temporarily switches to Giant Minigun with a visible HUD countdown, then restores the previous weapon | 8 s |
| Mega Laser | 0.6 s charge-up glow, then a bright beam across the arena damaging all enemies it touches | dmg 6, 8 s cooldown, `F4` |
| Boss Summon | Summons the Iron Behemoth (see Boss section); one at a time + 20 s post-kill cooldown | `F5` |

Abilities compose safely (e.g. Rapid Fire + Giant Gun multiply); laser has a
cooldown so it can't be spammed.

## Controls

| Input              | Action                                              |
| ------------------ | --------------------------------------------------- |
| `W` `A` `S` `D` / Arrows | Move the cat (optional; combat is automatic) |
| `E`                | **Debug:** spawn one enemy immediately              |
| `F` or `F6`        | **Debug:** rapid-fire power-up for 5 s              |
| `F1`               | **Debug:** switch to Machine Gun                    |
| `F2`               | **Debug:** switch to Giant Minigun                  |
| `F3`               | **Debug:** switch to Rocket Launcher                |
| `F4`               | **Debug:** fire Mega Laser (8 s cooldown)           |
| `F5`               | **Debug:** summon Iron Behemoth (one at a time, 20 s cooldown after a kill) |
| `F7`               | **Debug:** restore Default Gun                      |
| `R`                | Restart (only after game over)                      |
| Restart button     | Restart the run (mouse / touch)                     |

> Note: `F5` is also the Godot editor's "Run" shortcut, but at game runtime it
> safely triggers the boss summon. No conflicts with the original `E`/`F`/`R`
> keys, so no remapping was needed.

HUD shows: **health bar + HP, score, elapsed time, enemy count, spawn interval,
active gun, ability timers + laser cooldown, boss bar (only while a boss is
alive), and a debug line with enemy / projectile / FX counts**.

## Boss: Iron Behemoth

Large armored monster drawn in code (dark metal plates, pauldrons, horns,
pulsing orange core) — ~2.5–3× a chaser. Reuses `enemy.tscn`, the bullet
damage system, the `died` → score signal, and the capped `Explosion` FX.

- **Stats** (`BOSS_CONFIG` in `scripts/enemy.gd`): 150 HP, speed 55,
  25 contact damage, **+50 score**, radius 40, arena-clamped chase.
- **Attacks** (chase → telegraph → execute state machine, boss holds still
  while telegraphing):
  1. **Energy Burst** — 0.8 s converging-arc telegraph, then a 5-shot orange
     fan (`scripts/enemy_bullet.gd`: dmg 8, speed 330, 2.5 s life, capped
     impact FX, auto-cleaned).
  2. **Ground Slam** — 0.7 s red-ring wind-up, shockwave (r 260) damages the
     cat **once** and only inside the ring; 7 s cooldown; used in melee range.
  3. **Enrage** — triggers **once** below 30% HP: red aura + red HUD bar +
     `BEHEMOTH ENRAGED!` banner, attacks every 2.8 s (from 5 s), 1.4× speed.
- **HUD**: big `IRON BEHEMOTH` bar near the top (polled every frame),
  `IRON BEHEMOTH INCOMING!` / `BOSS DEFEATED! +50` banners via the existing
  announcement label. No duplicate bars.
- **Death**: attacks stop, its projectiles are cleared, one big 0.8 s blast,
  score awarded exactly once (single `died` emission), 20 s cooldown before
  `F5` works again. Restart (`reload_current_scene`) and game-over
  (`bullets`-group sweep) clear all boss state.
- Normal enemy spawning continues during the fight under the existing cap.

## Difficulty

- Spawn interval starts at **1.5 s**, shrinks **0.12 s every 10 s**,
  floored at **0.35 s**.
- Enemy mix unlocks over time: speeders after ~10 s, tanks after ~25 s.
- Enemy cap keeps the frame rate safe.

## Swapping in AI sprites later (First Milestone)

Cat + guns already use PNGs (see "Character & weapon sprites" below).
Still placeholder-drawn: enemies (`_draw_chaser/_draw_speeder/_draw_tank/
_draw_boss`), bullets, background. No gameplay code depends on placeholder art.

## Character & weapon sprites

| Slot | File | Used when |
| ---- | ---- | --------- |
| Cat body | `assets/characters/cat_idle.png` | Always (if present) |
| Default gun | `assets/weapons/gun_default.png` | Default Gun equipped |
| Minigun | `assets/weapons/gun_minigun.png` | Giant Minigun active |
| Machine gun / rocket | — (no PNG yet) | Placeholder art is drawn |

How it works (`scenes/cat_player.tscn` + `scripts/cat_player.gd`):

- `BodySprite` (Sprite2D) shows the cat; `WeaponMount` (Node2D marker) +
  `WeaponSprite` (Sprite2D) shows the gun. Textures load at runtime via
  `ResourceLoader.exists()` — a missing/corrupt file logs a warning and the
  game falls back to the original drawn placeholder. Nothing crashes.
- The mount rotates to the aim angle every frame; the gun flips vertically
  and the cat flips horizontally when aiming left, so aiming never breaks
  the attachment. Firing math (spawn point, rate, damage, cooldowns) is
  untouched — only visuals switch, and the default gun returns automatically
  when Giant Gun expires.
- Tune without code edits (Godot Inspector → select `CatPlayer` → Script
  Variables → **Sprites** group): `cat_sprite_scale`, `weapon_offset`,
  `default_gun_scale`, `minigun_scale`, texture paths, or
  `use_sprites_when_available` (off = placeholder mode).

## Combat effects (all code-drawn, no assets)

| Moment | Effect | Where |
| ------ | ------ | ----- |
| Fire | Muzzle flash at the barrel tip, sized per weapon (default 14, machine gun 12, minigun 18, rocket 22 — tune `muzzle_flash_radius` in `weapon_data.gd`) | `cat_player.gd:_spawn_muzzle_flash` |
| Flight | Glowing bullet core + short trail line | `bullet.gd:_draw` |
| Hit | Small impact flash + enemy white hit-flash (0.09 s) | `bullet.gd:_spawn_impact`, `enemy.gd:take_damage` |
| Kill | Shockwave ring + flash explosion, color-coded per enemy type | `enemy.gd:_spawn_explosion` |

Safety caps (unchanged): max 30 live FX nodes (`Explosion.MAX_FX`), 150
projectiles, 12 rockets — minigun streams and default-gun flashes share the
same capped pool, so effects can't flood the renderer on a Windows PC.

## Launch + visual check

```powershell
godot --path "C:\khanh\cat-commando"
```

Press **F5** (Run Project), then verify:

1. **Character** — cat PNG visible (~collision-circle sized), flips when
   enemies approach from the left.
2. **Weapon alignment** — gun sits beside the cat and rotates to track the
   nearest enemy; not upside-down when aiming left.
3. **Automatic shooting** — bullets spawn toward enemies with no input
   (move with WASD optionally).
4. **Weapon switching** — `F2` swaps to the minigun PNG (bigger scale),
   `F7` (or Giant-Gun expiry) restores the default gun PNG; `F1`/`F3`
   show placeholder art for machine gun / rocket.
5. **Combat effects** — small flash at the barrel tip on every shot (default
   gun included); glowing bullets with short trails; white blink + spark on
   hit; ring explosion on kill. Hold `E` to spawn targets and watch with the
   minigun (`F2`) — frame rate should stay smooth (FX capped at 30).
6. **Boss checklist** —
   1. Press `F5`: `IRON BEHEMOTH INCOMING!` banner + big `IRON BEHEMOTH`
      bar near the top.
   2. Cat auto-fires at the boss (nearest-target rule, unchanged).
   3. Back away: orange 5-shot fan after converging-arc telegraph.
      Stand close: red-ring wind-up → shockwave (damage only inside).
   4. Drop it below 30% HP: `BEHEMOTH ENRAGED!`, red aura + red bar,
      faster attacks — triggers once.
   5. Kill it: `BOSS DEFEATED! +50` exactly once, big blast, bar hides,
      minions keep spawning.
   6. Die / restart mid-fight: boss, its shots, and the bar are all gone.
   7. Mash `F5`: never more than one boss (`BOSS ALREADY ACTIVE!`, then a
      20 s `BOSS RECHARGING…` cooldown after a kill).
   8. Godot debugger: no errors or invalid-instance warnings.

## Remaining manual adjustments

- [ ] Sprite scales were set blind (`cat 0.25`, `default gun 0.4`,
  `minigun 0.5`) — resize in the Inspector if the art is too big/small.
- [ ] `weapon_offset` (default `10, 8`) may need nudging so the gun grip
  meets the cat's paws for your art.
- [ ] If a gun PNG points sideways-left instead of right, rotate
  `WeaponSprite` 180° or flip it in the Inspector.
- [ ] Machine gun / rocket launcher still use placeholder art (no PNGs).

## TikTok LIVE bridge (viewers control the game with gifts)

How it works: the game listens on **127.0.0.1:8765** (`scripts/live_bridge.gd`).
A separate Python process translates TikTok gift events into game commands and
sends them over that loopback connection. Gifts reuse the exact same code paths
as the keyboard debug keys, so behavior is identical. No TikTok password,
cookies, or keys are ever needed — only your public @username.

> TikTokLive is an **unofficial, reverse-engineered library** (modified AGPL;
> it runs as a separate process and is not part of the game). TikTok may change
> its protocol at any time; connection failures are reported as errors, never
> faked as success.

Default gift examples (edit names in `tools/tiktok_bridge/gift_mapping.json`):

| Gift example | Game command | Safety |
| ------------ | ------------ | ------ |
| Rose | Rapid fire 5 s | 8 s command cooldown |
| GG | Giant minigun | 20 s cooldown, auto-restores |
| TikTok | Enemy wave (2/gift, max 10) | Enemy caps enforced |
| Money Gun / Sports Car | Minigun / rocket loadout | 5 s cooldown |
| Galaxy / Lion | Summon Iron Behemoth (queued, see below) | Max 3 active, queue 100, immediate when a slot is free |
| Universe | Mega laser | 8 s laser + 10 s command cooldown |

Streakable gifts fire the game command **once at streak end** (using the
streak's total as quantity); unmapped gifts are logged and ignored.

### Boss summon queue (Galaxy / Lion gifts)

One completed gift = exactly one summon request. The bridge ignores the
message `count` for boss summons (streak totals arrive as one final event;
the default Galaxy mapping is one gift = one boss).

- Up to **3 living bosses** at once (`SpawnManager.MAX_ACTIVE_BOSSES`).
  Gifts spawn immediately while a slot is free — no summon cooldown waits.
- 3 active → the request stays queued (max `boss_queue_max` = 100,
  Inspector-editable); each boss death spawns exactly one queued boss.
- Full queue → explicit `queue_full` error (never silent).
- Entries are removed only after `spawn_boss()` succeeds: exactly-once.
- Retried connector deliveries reuse a per-gift UUID (`event_id`); repeats
  are rejected as `duplicate_event` (seen-ID window: 500 entries / 10 min).
  Messages without an ID are never deduped, so distinct gifts from the same
  viewer are never suppressed.
- Console logs (`[BossQueue] Gift accepted / Spawned boss / Queued one boss /
  Boss died / Game over: queue cleared`) plus the in-game
  `Active Bosses: X/3 / Bosses Queued: Y/100` label and `status` counts
  (`active_bosses`, `queue_size`, `player_hp`) make every transition visible.
- Game-over clears the queue (restart recreates it empty).
- Keyboard `F5` still summons directly (refused while any boss lives) and all
  other gifts/keys are unchanged. The old 20 s post-kill timer is kept only
  for observability; it no longer gates spawns.

### 1. Run the Godot game

```powershell
godot --path "C:\khanh\cat-commando"
```

Press **F5**. The console log should show `[LiveBridge] listening on 127.0.0.1:8765`.
Keep the game window focused for keyboard tests, or unfocused — gifts work either way.

### 2. Set up Python (one time)

```powershell
cd C:\khanh\cat-commando\tools\tiktok_bridge
pip install -r requirements.txt
```

This installs only the `TikTokLive` package (plus its own dependencies).
No existing project files are touched — there were no prior Python
dependencies in this repo.

### 3. Enter your TikTok username

Either edit `gift_mapping.json` (`"tiktok_username": "YourName"`) or pass it
on the command line (recommended, no file edit):

```powershell
python connector.py --user @YourName
```

### 4. Test with fake gifts (no LIVE needed)

With the game running:

```powershell
cd C:\khanh\cat-commando\tools\tiktok_bridge
python simulate.py
```

Expect 28/28 PASS (editor/debug build required; the script resets boss
state itself, then verifies): reset to 0/0, 3× single gifts → 3 active,
4th–6th gifts queue one-by-one, run-unique event_id dedup, 96 singles fill
to exactly 100, `queue_full` on overflow, one death → 3 active/99 queued,
second death → 98, full death-drain to 0/0, plus the unchanged
ping/cooldown/wave/weapon/rejection/reconnect checks.
Replies are parsed as JSON (Godot emits compact spacing).
Then manually confirm `E/F/F1-F7/R` keys still work in the game window.

### 5. Connect to a real public LIVE session

1. Start your TikTok LIVE on your phone.
2. Run the game, then: `python connector.py --user @YourName`
3. The connector first checks you are LIVE, prints the active mappings, then
   forwards each gift (streaks resolved once at streak end).
4. Stop with Ctrl+C. If the stream ends, the connector exits cleanly.

### 6. Troubleshooting

| Symptom | Meaning / fix |
| ------- | ------------- |
| `Cannot reach the game at 127.0.0.1:8765` | Game isn't running — launch it first. |
| `@user is not LIVE right now` | Start the TikTok LIVE, then retry; or use `simulate.py`. |
| Sign/API errors from TikTokLive | TikTok changed its protocol or rate-limited signing — run `pip install -U TikTokLive`; check the TikTokLive GitHub/Discord. |
| Gifts logged as "Unmapped" | Gift name isn't in `gift_mapping.json` — add the exact name shown in the log. |
| Commands rejected `on_cooldown` | Working as designed (anti-spam); wait or lower cooldowns in the Inspector (`LiveBridge` node → Script Variables). |
| Port already in use | Stop the other bridge/sim, or change the port on the `LiveBridge` node in the Inspector and pass the same `--port` to the Python scripts. |

## Verification status

- [x] All required files created, no external asset references.
- [x] Main scene configured in `project.godot`.
- [x] Weapon/ability/boss code inspected for syntax, node paths, groups and caps.
- [x] Combat effects audit: muzzle/trail/hit/kill FX verified in code,
  default-gun muzzle flash added, node paths checked.
- [x] Iron Behemoth: state machine, 3 attacks, enrage-once, death cleanup,
  cooldown, HUD bar/title/banners inspected; node paths and groups verified.
- [x] LIVE bridge: GDScript + Python code re-read for syntax, API names
  verified against project code and TikTokLive 7.x docs; no gameplay edits
  beyond a 3-line bridge hook; keyboard controls untouched.
- [x] Boss queue v3 (one gift = one request): quantity fan-out removed,
  game-over queue clear, death-transition logging, run-isolated 28-check
  simulator suite (reset phase, exact-count asserts) — all re-read; no shell
  to execute anything.
- [ ] **Not run-tested here** — shell is unavailable in this environment
  (`spawn EFTYPE`), so the simulator could not be executed and no Godot
  headless check was possible. **28/28 is expected, not measured.** Run
  `python tools/tiktok_bridge/simulate.py` with the game open and report.
