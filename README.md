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
| Right click (hold) | Skill in the RMB slot (Heavy Strike): click an enemy to walk up and hit it, or click the ground to swing in place | **Working** |
| Q W E R T | Skill slots (Q = Cleave, W = Leap Slam). Click a slot on the skill bar to change its skill | **Working** |
| 1 / 2 | Health potion / mana potion | **Working** |
| 3–5 | Future potions | Bound, no behavior yet |
| I / C / P | Inventory / character / passives | Bound, no behavior yet |
| Alt (hold) | Show labels for normal items too; in a tooltip, show each affix's tier | **Working** |
| Left click a ground label | Walk over and pick the item up | **Working** |
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
  - Skills work while walking. Melee swings slow Werdna to 35% speed instead of stopping him, and he keeps facing the swing. Leap Slam works mid-walk, and holding left click keeps walking after landing.
  - Holding right click keeps attacking. While holding left click, attacks hit in place toward the target instead of walking to it. A new move click cancels a pending attack.
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

## Milestone 3: "Gems and potions"

- **Gems** are resources in `data/gems/`: `GemData` is the base, and `SkillGem` is an active skill.
  Supports and sockets come in Milestone 4.
- **Skill damage** is the weapon roll (9–15 on the placeholder weapon, set on the `Melee` node)
  times the gem's multiplier:

| Gem | Slot | Mana | Cooldown | Damage | Behavior |
|---|---|---|---|---|---|
| Heavy Strike | RMB | 0 | – | 140% | Hits the closest enemy in front |
| Cleave | Q | 5 | – | 90% | Hits every enemy in a 160° arc, reach 2.2 |
| Leap Slam | W | 10 | 1.5 s | 100% | Jumps up to 8 units toward the cursor and hits everything within 2 units of the landing spot |

- **Skill bar** (`SkillBar`) has six slots: RMB and Q–T. It tracks cooldowns and checks mana.
  Clicking a slot on the HUD cycles it through the known gems. Out of mana or on cooldown, a
  warning appears above the skill bar.
- **Mana** is 50, regenerating 2 per second.
- **Potions** are resources in `data/potions/`:
  - Health (key 1) restores 50 life over 1 s.
  - Mana (key 2) restores 30 mana over 2 s.
  - Each holds 30 charges and uses 10 per drink.
  - Kills add 3 charges to each potion, and respawning refills them.
  - The HUD shows each potion's fill beside the life bar.

## Milestone 4a: "Items and drops"

- **Item data lives in JSON**, so a large table stays readable and easy to tune in one place:
  - `data/items/bases.json` has 50 bases: axes, swords and maces (one- and two-handed), 2
    shields, chest, helm, gloves and boots in AR/EV/ES and hybrid versions, 6 rings, 4 amulets,
    4 charms and 8 orbs.
  - `data/items/affixes.json` has 40 affixes with 2–6 tiers each.
  - `ItemDB` loads and caches both.
- **Rolling** (`ItemGenerator`):
  - Rarity weights are normal 62%, magic 30%, rare 7.5% and legendary 0.5%.
  - Affix counts: magic 1–2 (up to 1 prefix and 1 suffix), rare 3–4 (up to 2/2), legendary
    4–6 (up to 3/3).
  - Each tier needs a minimum item level. No affix group appears twice on one item.
  - Legendaries weight tiers by `1 + 0.5 × tier rank`.
  - Sockets are weighted 40/30/20/10 for 1–4, capped by the base.
  - Rares get random two-word names.
- **Mod identity comes from tags:** an affix lists the item tags it can roll on, with weight
  multipliers. Bleed needs `bladed` (axes and swords). Stun and area of effect need `mace`. Crit
  multiplier is weighted toward axes; attack speed, crit chance and accuracy toward swords.
  Charms have their own tags, so they only roll charm mods: culling strike, rarity and quantity,
  recoup, movement speed, cooldowns, on-kill effects and more.
- **Drops:** each goblin (`LootDropper`) has a 35% item chance and a 15% currency chance. Item
  level is the area level, set by the `AreaInfo` node (5 in the test arena).
- **On the ground:**
  - Items show as a tile coloured by rarity. Rares and legendaries also get a light beam.
  - `GroundLabels` draws clickable labels and pushes overlapping ones upward.
  - Hovering a label shows the item tooltip; holding Alt adds each affix's tier.
  - Clicking a label walks Werdna over, and the item goes into his inventory.
- **Inventory** (`Inventory`) is a PoE-style 12×5 grid. Items fill column by column and
  currency stacks. The inventory screen comes in 4b.

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

Run the headless Milestone 3 test:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_skills.gd
```

The skills test checks the loadout, Cleave hitting multiple enemies, Heavy Strike hitting one,
Leap Slam's movement, damage and cooldown, refusal when out of mana, mana regeneration, both
potions, empty potions, and charges gained from kills.

Run the headless Milestone 4a test:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_loot.gd
```

The loot test covers the data tables, 3,000 random drops checked against every affix rule,
weapon mod identity, charm-only mods, item-level gating, legendary tier bias, socket
distribution, names, the inventory grid and stacking, and drop-and-pickup in the arena.

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
