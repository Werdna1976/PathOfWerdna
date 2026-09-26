# Path of Werdna

An isometric action RPG in the spirit of Path of Exile, built in **Godot 4.7.2**.
See [DESIGN.md](DESIGN.md) for the full design; this README covers how to run what exists today.

## Running

1. Open Godot 4.7.2, choose **Import**, and select this folder's `project.godot`.
2. Press **F5** (Run Project). The main scene is `scenes/levels/test_arena.tscn`.

From a terminal:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --path C:/GoDot/Projects/Godot-Opus-ARPG
```

## Controls

| Input | Action | Status |
|---|---|---|
| Left click (hold) | Move to the cursor | **Working** |
| Right click (hold) | Heavy Strike: click an enemy to walk up and hit it, or click the ground to swing in place | **Working** |
| Q W E R T | Skill slots 1–5 | Bound, no behavior yet |
| 1–5 | Potions 1–5 | Bound, no behavior yet |
| I / C / P | Inventory / character / passives | Bound, no behavior yet |
| Alt (hold) | Show ground-item labels | Bound, no behavior yet |
| Esc | Menu | Bound, no behavior yet |

Keys are bound by physical location, so they stay in the same place on non-QWERTY layouts.

## Milestone 1: "Walk"

- **Test arena** (`scenes/levels/test_arena.tscn`): a 40×40 stone floor with perimeter walls, a
  center wall, four crates and four pillars, all primitive placeholder meshes.
- **Navigation:** a `NavigationRegion3D` (`scripts/systems/runtime_nav_baker.gd`) bakes its navmesh
  from the child static colliders when the level loads, then waits until the navigation map
  contains it before emitting `navigation_ready`.
- **Lighting:** very dim cool ambient light, a weak moonlight, exponential depth fog plus
  volumetric fog, ACES tonemapping and light glow. Four warm torches with shadows sit on the
  pillars, and Werdna carries a faint lantern so they stay readable between torch pools.
- **Player** (`scenes/player/player.tscn`): a capsule with a red "nose" showing facing.
  - `NavMovement` moves the body along a `NavigationAgent3D` path at 5 units/s, turns
    smoothly, and stops at the target. It's written so enemies can reuse it.
  - `ClickMoveInput` raycasts from the camera on left click and keeps updating the target
    while the button is held.
  - A ring marker (`scenes/ui/click_marker.tscn`) grows and fades where you click.
- **Camera** (`scripts/components/follow_camera.gd`): fixed at 55° pitch and 45° yaw, 22 units
  away, following Werdna smoothly. It never rotates.

## Milestone 2: "Fight"

- **Heavy Strike** (the `HeavyStrike` node, a `MeleeAttack`) deals 12–20 damage with a 0.22 s
  wind-up and 0.3 s recovery. It hits the closest living enemy in a 110° arc in front of Werdna.
  - Movement is locked during a swing, and a move ordered mid-swing starts when the swing ends.
  - Holding right click keeps attacking. Left click cancels a pending attack.
- **Goblins** (`scenes/enemies/goblin.tscn`) have 40 life and deal 4–7 damage with a slow club
  swing. `EnemyAI` keeps them idle until the player comes within 11 units or hits them, then
  they chase and attack.
  - `EnemySpawner` keeps one goblin at each marker, and respawns it 8 s after it dies.
- **Feedback:**
  - Floating damage numbers: white for damage you deal, red for damage you take.
  - A short hit flash, and a sword or club sweep during swings.
  - Enemy health bars appear once an enemy is damaged.
  - The HUD shows a life bar in the bottom-left.
- **Death:** there's no penalty. Werdna collapses, then respawns at the start point with full life
  after 3 s. Goblins stop chasing when he's dead.
- **Reusable components:** `Health`, `MeleeAttack` and `NavMovement` are shared by the player and
  the goblins.

### Why a perspective camera

The camera uses **perspective with a narrow 35° FOV** instead of orthographic because:
- Depth fog and volumetric fog depend on distance from the camera. They behave oddly with an
  orthographic camera, and the dark, foggy tone relies on them.
- A slight perspective gives tall objects like pillars and walls a sense of height, while the narrow
  FOV keeps the classic isometric feel with little distortion at the screen edges.

### Implementation notes

- **Physics layers** follow DESIGN.md: 1 world, 2 player, 3 enemy, 4 player_attack and 5 enemy_attack.
- **Physics interpolation** is on, so movement stays smooth on high-refresh monitors. The camera
  follows the player's interpolated transform.
- **Navigation cell height** is 0.1 in both the navmesh and the project's default map settings.
  Recast lifts the navmesh two cells above the floor (0.2), so the agent's `path_height_offset`
  is set to 0.2 to keep its waypoint checks accurate.

## Tests

Run the headless Milestone 1 test:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_walk.gd
```

Run the headless Milestone 2 test:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_fight.gd
```

The fight test checks spawning, goblin aggro and chase, killing a goblin with Heavy Strike,
goblins hitting back, corpse cleanup, swinging in place, and death and respawn.

It checks that:
- every Input Map action exists and is bound
- the navmesh bakes
- Werdna walks from one side of the center wall to the other, reaching the target within 0.5 units
- the capsule never overlaps the wall, so the path goes around it
- Werdna stays on the floor

It prints `PASS` or `FAIL` for each check and exits with code 0 when everything passes, or 1 when anything fails.

Optional visual check (needs a window and GPU, so it doesn't run headless):

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/capture_screenshot.gd
```

This saves the game camera's view to `tests/screenshot_m1.png`.

## Layout

```
scenes/   player/, levels/, ui/
scripts/  components/ (reusable node behaviors), systems/ (level-wide services)
data/     .tres game data (from Milestone 3 on)
assets/   art and audio (placeholders for now)
tests/    headless test scripts
```
