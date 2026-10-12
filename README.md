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
- No plugins, no paid assets, no external images.

## Project structure

```text
project.godot
scenes/
  main.tscn        # Root (GameManager) + Arena + CatPlayer + SpawnManager + Camera + HUD
  arena.tscn       # Dark futuristic arena background (drawn in code)
  cat_player.tscn  # Orange cat commando (drawn in code)
  enemy.tscn       # Enemy placeholder (drawn in code, 3 visual types)
scripts/
  game_manager.gd  # Score, timer, game-over, restart, debug keys
  cat_player.gd    # Auto-aim + auto-shoot, WASD movement, HP 100, rapid fire
  enemy.gd         # chaser / speeder / tank, contact damage, hit flash, explosion
  spawn_manager.gd # Edge spawning + difficulty ramp (1.5s -> 0.35s min, max 40)
  hud_manager.gd   # Health, score, time, enemy count, game-over + restart button
  bullet.gd        # Pooled by lifetime; auto-freed, never accumulates
  explosion.gd     # Short-lived hit explosion effect
  arena.gd         # Background/grid/neon border drawing
README.md
```

### Collision layers (physics)

| Layer | Who      | Mask       |
| ----- | -------- | ---------- |
| 1     | Player   | 2 (enemy)  |
| 2     | Enemy    | 1 (player) |
| 4     | Bullet   | 2 (enemy)  |

Bullets are `Area2D` and detect enemy bodies. Contact damage uses a
per-enemy 0.8 s cooldown with distance checks. Bullets live max 2 s and are
freed outside the arena; enemies are capped (`max_enemies = 40`, absolute
debug cap 50); explosions free themselves after 0.35 s.

### Signals

- `CatPlayer.health_changed / died / fired`
- `Enemy.died(enemy, score_value)` → `GameManager._on_enemy_died`
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
- Bullets kill enemies → **score increases** (chaser +1, speeder +1, tank +3).
- Enemies deal contact damage (chaser 10, speeder 6, tank 20). Cat has **100 HP**.
- Survive as long as possible. **Game over at 0 HP** → click **RESTART** (or `R`).

## Controls

| Input              | Action                                              |
| ------------------ | --------------------------------------------------- |
| `W` `A` `S` `D` / Arrows | Move the cat (optional; combat is automatic) |
| `E`                | **Debug:** spawn one enemy immediately              |
| `F`                | **Debug:** rapid-fire power-up for 5 s              |
| `R`                | Restart (only after game over)                      |
| Restart button     | Restart the run (mouse / touch)                     |

HUD shows: **health bar + HP, score, elapsed time, enemy count, spawn interval**,
plus a controls hint line and a rapid-fire notice.

## Difficulty

- Spawn interval starts at **1.5 s**, shrinks **0.12 s every 10 s**,
  floored at **0.35 s**.
- Enemy mix unlocks over time: speeders after ~10 s, tanks after ~25 s.
- Enemy cap keeps the frame rate safe.

## Swapping in AI sprites later (First Milestone)

Graphics are isolated in `_draw()` functions:

- Cat → `scripts/cat_player.gd` (`CatPlayer._draw`)
- Enemies → `scripts/enemy.gd` (`_draw_chaser/_draw_speeder/_draw_tank`)
- Bullets → `scripts/bullet.gd` (`_draw`)
- Background → `scripts/arena.gd` (`_draw`)

To replace with PNGs: add `Sprite2D` nodes under the same roots, assign the
textures, and delete/skip the `_draw()` bodies. No gameplay code depends on
the placeholder art.

## Verification status

- [x] All required files created, no external asset references.
- [x] Main scene configured in `project.godot`.
- [ ] **Not run-tested here** — Godot executable check was impossible in this
  environment (shell tool error `spawn EFTYPE`). Please run F5 in the editor
  and report any errors; likely spots to check are the `[input]` map block
  and HUD node paths.
