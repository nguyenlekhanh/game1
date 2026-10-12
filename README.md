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
- Bullets kill enemies → **score increases** (chaser +1, speeder +1, tank +3, boss +20).
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
| Boss Summon | Spawns one crowned boss (60 HP, fast for its size, 25 contact dmg, +20 score) with a HUD boss bar; only one boss at a time | `F5` |

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
| `F5`               | **Debug:** summon boss (one at a time)              |
| `F7`               | **Debug:** restore Default Gun                      |
| `R`                | Restart (only after game over)                      |
| Restart button     | Restart the run (mouse / touch)                     |

> Note: `F5` is also the Godot editor's "Run" shortcut, but at game runtime it
> safely triggers the boss summon. No conflicts with the original `E`/`F`/`R`
> keys, so no remapping was needed.

HUD shows: **health bar + HP, score, elapsed time, enemy count, spawn interval,
active gun, ability timers + laser cooldown, boss bar (only while a boss is
alive), and a debug line with enemy / projectile / FX counts**.

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

## Remaining manual adjustments

- [ ] Sprite scales were set blind (`cat 0.25`, `default gun 0.4`,
  `minigun 0.5`) — resize in the Inspector if the art is too big/small.
- [ ] `weapon_offset` (default `10, 8`) may need nudging so the gun grip
  meets the cat's paws for your art.
- [ ] If a gun PNG points sideways-left instead of right, rotate
  `WeaponSprite` 180° or flip it in the Inspector.
- [ ] Machine gun / rocket launcher still use placeholder art (no PNGs).

## Verification status

- [x] All required files created, no external asset references.
- [x] Main scene configured in `project.godot`.
- [x] Weapon/ability/boss code inspected for syntax, node paths, groups and caps.
- [x] Combat effects audit: muzzle/trail/hit/kill FX verified in code,
  default-gun muzzle flash added, node paths checked.
- [ ] **Not run-tested here** — Godot executable check was impossible in this
  environment (shell tool error `spawn EFTYPE`). See "Launch + visual check"
  and "Remaining manual adjustments" above.
