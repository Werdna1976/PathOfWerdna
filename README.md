# Path of Werdna

An isometric action RPG in the spirit of Path of Exile, built in **Godot 4.7.2**.
See [DESIGN.md](DESIGN.md) for the full design; this README covers how to run what exists today.

## Running

1. Open Godot 4.7.2, choose **Import**, and select this folder's `project.godot`.
2. Press **F5** (Run Project). The main scene is `scenes/main.tscn`, which starts in Werdna's Camp.

From a terminal:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --path C:/GoDot/Projects/Godot-Opus-ARPG
```

## Controls

| Input | Action | Status |
|---|---|---|
| Left click (hold) | Move to the cursor | **Working** |
| Right click (hold) | Skill in the RMB slot (Heavy Strike): click an enemy to walk up and hit it, or click the ground to swing in place | **Working** |
| Q W E R T | Skill slots, filled from socketed gems (Q = Cleave, W = Leap Slam to start). Click a slot on the skill bar to change its skill | **Working** |
| 1 / 2 | Health potion / mana potion | **Working** |
| 3–5 | Future potions | Bound, no behavior yet |
| I | Inventory: click to pick up, place, swap or equip; right-click to quick equip or unequip; click the world while holding an item to drop it | **Working** |
| C | Character sheet (starts with each slotted skill's DPS) | **Working** |
| Right click an orb, then left click an item | Craft; hold Shift to keep using the orb, right click or Esc to stop | **Working** |
| Hover a skill bar slot | Skill tooltip with damage per hit, crits, uses per second and DPS | **Working** |
| P | Passive tree | Bound, no behavior yet |
| Alt (hold) | In a tooltip, show each affix's tier | **Working** |
| Left click a ground label | Walk over and pick the item up | **Working** |
| Esc | Close panels (menu later) | Partly working |

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
- **Player** (`scenes/player/player.tscn`): now Werdna's procedural model (see Characters); it
  started as a capsule with a red "nose" showing facing.
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
  - `data/items/bases.json` has 186 bases, with drop levels from 1 to about 62:
    - 5 tiers for each weapon class: one- and two-handed axes, swords and maces (for example
      Rusted Hatchet → Jade Hatchet → Boarding Axe → Cleaver → Broad Axe).
    - 4 tiers of shields for each defence type: tower (AR), buckler (EV), spirit (ES), round
      (AR/EV), kite (AR/ES) and spiked (EV/ES).
    - 4 tiers of chest, helm, gloves and boots for each of AR, EV, ES and the three hybrids.
    - 11 rings, 8 amulets and 8 charms, with fitting implicits (rarity, mana, crit, life,
      recoup and so on).
    - 9 currency items: the 8 orbs and the Transmutation Shard.
    - Base damage and defences grow with drop level.
  - `data/items/affixes.json` has 46 affixes with 3–8 tiers each. Every top tier needs item
    level 75–84. Newer affixes:
    - local % Armour, % Evasion and % Energy Shield
    - Stun Threshold
    - Rarity on rings and amulets
    - Life on Kill
  - `ItemDB` loads and caches both. Every base can set an `icon` (see Item icons below).
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
  - Items show as a tile glowing in their rarity colour, with the item's icon floating above.
    Rares and legendaries also get a light beam.
  - `GroundLabels` draws clickable labels and pushes overlapping ones upward.
  - Hovering a label shows the item tooltip; holding Alt adds each affix's tier.
  - Clicking a label walks Werdna over, and the item goes into his inventory.
- **Inventory** (`Inventory`) is a PoE-style 12×5 grid. Items fill column by column and
  currency stacks. The inventory screen comes in 4b.

## Milestone 4b: "Inventory and equipment"

- **Equipment** (`Equipment`) has 10 slots: weapon, off hand, helm, body armour, gloves, boots,
  two rings, amulet and charm.
  - A two-hander uses both hands. Equipping one displaces the off hand, and equipping a shield
    displaces the two-hander.
  - Off hands hold shields only for now; there's no dual wielding yet.
  - Werdna starts with a Rusted Hatchet.
- **Stats** (`CharacterStats`) add up base values, attributes and gear, then apply the results
  to the other components:
  - **Attributes:** STR +0.5 life and +0.2% melee physical damage per point. DEX +2 accuracy
    and +0.2% evasion. INT +0.5 mana and +0.2% energy shield. Werdna's base attributes are
    STR 20, DEX 14 and INT 14.
  - **Life and mana:** 100 life and 50 mana at the start. When the maximum changes, the current
    value keeps its percentage. Mana regenerates 4% of its maximum per second.
  - **Weapon damage** uses local mods (% physical, added physical), plus added damage to
    attacks from jewellery and gloves. Attack speed is weapon APS × increases; it shortens skill
    wind-up and recovery against a 1.5 APS baseline. Unarmed damage is 2–6.
  - **Crits:** 5% base chance, scaled by increases, with a 150% multiplier.
  - **Other stats applied:** area of effect scales area skills' radius; movement speed, life
    regeneration, life on hit, culling strike, potion charges on kill, mana on kill, cooldown
    recovery, and item rarity and quantity all work.
- **Defences** (`Defenses`) are applied in this order:
  - **Block:** shields block the whole hit.
  - **Evasion:** dodges physical hits, with a chance of evasion / (evasion + 250), max 75%.
  - **Armour:** reduces physical hits by A / (A + 5 × damage), max 90%.
  - **Resistances:** capped at 75%.
  - **Energy shield:** absorbs damage before life and recharges after 2 s without damage.
  - **Life recoup:** heals back a share of damage taken over 4 s.
  - Avoided hits pop "Block" or "Evade" text. A thin light-blue bar above life shows energy
    shield.
- **Inventory screen** (I) is custom-drawn with the PoE paper-doll layout above the 12×5 grid.
  - Items are coloured by rarity and show their socket count.
  - Hovering an item shows its tooltip to the left of the panel; hold Alt to see affix tiers.
- **Character sheet** (C) lists attributes, offence, defence and utility stats. Stats marked
  `*` roll on gear but don't do anything in combat yet: bleed, stun, avoid stun or ailments,
  explode on kill and Onslaught.

## Milestone 4c: "Sockets and gems"

- **Gems are items:** 1×1, with a teal name. Supports are `SupportGem` resources in
  `data/gems/`, and `ItemDB.make_gem(id)` creates a gem item.
- **Sockets:** every socket on an item is linked. In the inventory screen:
  - Sockets are circles on the item. Active gems show as solid red, supports as a ring.
  - Holding a gem, click a socket to socket it, swapping with any gem already there. With
    nothing held, click a filled socket to take the gem out.
  - Hovering a socket shows that gem's tooltip. Item tooltips list their socketed gems.
- **Skill bar** (`SkillBar`) builds a `SkillInstance` for each active gem in equipped gear,
  supported by compatible supports in the same item.
  - Slot assignments are kept across changes. New skills fill the first empty slot. A slot the
    player cleared stays clear.
  - With nothing on right click, Werdna uses **Default Attack** (100% damage, no cost).
- **Supports:**

| Support | Effect | Mana | Supports |
|---|---|---|---|
| Added Fire Damage | Gain 25% of physical as extra fire | ×1.2 | attacks |
| Melee Splash | Also hits enemies within 1.8 of the target for 60% damage | ×1.4 | strikes (Heavy Strike) |
| Faster Attacks | 30% faster attacks | ×1.2 | attacks |
| Life Leech | Heal 5% of damage dealt | ×1.1 | attacks |
| Brutality | 40% more physical damage, no elemental damage | ×1.2 | attacks |

- **Starting kit** (`Equipment.STARTING_KIT`): a Rusted Hatchet with 2 sockets holding Heavy
  Strike and Cleave, and a Plate Vest with 3 sockets holding Leap Slam. All five supports start
  in the bag until vendors and quests exist.
- **Gem levels** always show 1. Gem XP arrives with character XP in Milestone 5.

## Crafting and skill damage

- **Orbs** (`Crafting`): right click an orb in the inventory, then left click an item. Shift
  keeps the orb on the cursor. A wrong target shows why and doesn't spend the orb.
  - **Transmutation:** normal → magic.
  - **Augmentation:** adds a mod to a magic item with room.
  - **Alteration:** rerolls a magic item.
  - **Regal:** magic → rare, keeping its mods and adding one.
  - **Chaos:** rerolls a rare or legendary.
  - **Ascension:** rare → legendary, keeping its mods and adding 1–2 with the tier bias.
  - **Scouring:** removes all mods, keeping the implicit.
  - **Jeweller's:** always changes the socket count. Gems in removed sockets go back to the
    bag.
- **Skill damage** (`MeleeAttack.estimate`) uses the same formula as real hits. It includes
  weapon and gear damage, supports, crits, attack speed and cooldowns. It appears on skill bar
  tooltips, on tooltips of active gems socketed in gear, and as a Skills section at the top of
  the character sheet.

## Town, vendors and zones

- **The game runs from `scenes/main.tscn`** (`Game`). It holds the player, camera and UI, and
  loads one zone at a time underneath them.
  - Each zone is its own scene with navigation, lighting, an `AreaInfo` (name, level, whether it's
    a town), entry markers under `Entries/`, and `ZoneExit` doorways under `Exits/`.
  - Walking into a doorway unloads the zone and loads the next one at the matching entry.
  - Items dropped on the ground stay in the zone they were dropped in.
  - Dying respawns you at the entrance of the current zone.
- **Werdna's Camp** (`scenes/levels/town.tscn`) is safe: there are no monsters, and skills can't
  be used there. The gate on the east side leads to the Shore.
  - **Greta the Smith** sells 12 normal and magic items at item level 3 for 1 Transmutation or 1
    Alteration Orb each. Her stock rerolls every time the town loads, so it refreshes after each
    trip.
  - **Ilsa the Gemcutter** always has every gem:
    - Actives cost 1 Transmutation Orb; Leap Slam costs 2.
    - Supports cost 1 Alteration Orb; Melee Splash and Brutality cost 2.
  - Click a vendor to walk over and open the shop; the inventory opens beside it. Click stock to
    buy. Pick up an inventory item and click the Sell box to sell it; socketed gems come back to
    your bag.
  - **Sell prices:**
    - Normal items and gems: 1 Transmutation Shard.
    - Magic items: 2 shards.
    - Rare items: 1 Alteration Orb.
    - Legendary items: 1 Chaos Orb.
  - 5 shards combine into an Orb of Transmutation automatically.
- **The Goblin Shore** (`scenes/levels/shore.tscn`) is area level 3: a sandy beach by the sea,
  with rocks, a wreck and 10 goblins that respawn after 45 s. The gate on the west side leads
  back to camp.
- **Starting orbs:** Werdna starts with 4 Transmutation and 2 Alteration Orbs to try the shops.
- **Both zones are built with the world kit** (see below), and they can be edited in the Godot
  editor like any scene. `scenes/levels/test_arena.tscn` stays as the standalone arena the older
  tests use.

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

## World kit

Reusable building blocks for zones live in `scripts/kit/`, `scenes/kit/`, `assets/` and
`data/biomes/`. See [docs/WORLD_KIT.md](docs/WORLD_KIT.md) for how to build a new zone and how to
swap in real art later.

- **Materials:** tools/gen_textures.gd generates 11 tileable textures, each with a normal map
  derived from its height field: sand, wet sand, dirt, packed earth, grass, stone, cobbles,
  planks, cliff rock, bark and cloth. Their triplanar materials multiply in vertex colour, so
  one material serves many tints.
- **Shaders:**
  - water, with swell, depth colour and a glowing surf line
  - foliage sway and cloth sway
  - a two-material ground blend that follows a gradient, a circle or a painted mask
- **24 props** (`KitProp`) built from low-poly procedural meshes:
  - torches (post and wall), a campfire and a brazier, each with a flickering light and
    flame, ember and smoke particles
  - boulders, rock clusters, cliff chunks and pebbles
  - dead trees and pines, bushes and grass
  - tents, palisades and gates
  - crates, barrels, sacks and market stalls
  - driftwood, a shipwreck and banners
  - `variant` changes each prop's shape, and `collision` off makes it decorative.
- **Atmosphere** (`AmbientEffect`): dust motes, fireflies, ground mist, falling ash and sea spray.
- **Biomes** (`data/biomes/camp.tres`, `shore.tres`, `forest.tres`): environment, fog and light
  colours, ground materials, prop and scatter lists, ambient effects, and music and ambience ids.
- **PropScatter:** fills a rectangle or polygon with weighted props. It's deterministic from a
  seed, avoids ScatterExclusion areas, markers, exits and vendors, and places decorative props
  without colliders.
- **Zone and template:** a `Zone` root applies its biome. `scenes/kit/zone_template.tscn` is the
  starting point for new zones.

## Characters

- **Werdna** (`WarriorModel`) and the **goblin** (`GoblinModel`) are low-poly procedural models on
  a small joint rig. They sit at `Visual/Body` in the player and goblin scenes, and the right
  arm lives in `Visual/WeaponPivot`, so SwingAnimator's sweep reads as a slash.
- **EquipmentVisuals** follows `Equipment.changed`:
  - a weapon model for each type, one- or two-handed (axe, sword or mace)
  - a shield model in the left hand
  - an armour style for the body armour's defence type: plate (AR), leather (EV), robe (ES),
    scale, chain with a tabard, or padded
  - helm, glove and boot styles in the same way
- **CharacterAnimator** adds a walk cycle driven by velocity, a hip bob and lean, idle
  breathing, a torso twist into swings, a raised blade at rest, and footstep events. Deaths and
  leaps still use the existing tweens on `Visual`.
- **HitFeedback** flashes the whole model through a temporary additive overlay.
- **Readability:** rim lighting, a glowing visor slit and robe trim, and the goblins' glowing
  eyes keep the models readable in the dark.
- **Vendors** reuse the warrior model: Greta wears leather and holds a hammer, and Ilsa wears a
  robe and circlet.

## Item icons

- tools/gen_icons.gd writes 60 stylised SVG icons into `assets/icons/`:
  - every weapon class, one- and two-handed
  - six shield styles
  - chest, helm, gloves and boots for each defence type and hybrid
  - ring, amulet and the four charms
  - every orb and the shard
  - each active and support gem
- **ItemIcons** picks an icon in this order: the base's `icon` field, then a file named after
  the base id, then its slot, type and defence tags. New bases get a sensible default, and
  per-base art can be dropped in later.
- Icons show in the inventory and vendor screens (framed by rarity colour, with currency stack
  counts), on ground labels, and as a floating billboard over ground items.

## Audio

- tools/gen_audio.gd synthesizes everything in `assets/audio/`:
  - **40 sound effects:**
    - combat: swings, flesh and armour hits, crits, blocks and evades
    - voices: goblin grunts and death, player hurt and death
    - loot: drops by rarity, with chimes for rares and legendaries, the orb clink and pickup
    - the potion, the skill-fail buzz and zone travel
    - vendor coins and UI clicks, including inventory open and close
    - footsteps on sand and dirt
  - **Two original 120 s looping tracks:**
    - the camp: a Karplus-Strong plucked guitar arpeggio in D minor over a low drone, with echoes
    - the shore: a dark drone, a low string pad, surf and distant bells
  - **Ambience loops:** campfire, sea and wind.
- **The `Audio` autoload** (`scripts/systems/audio.gd`):
  - It uses the Music, SFX and Ambience buses (`default_bus_layout.tres`), with music under
    the effects.
  - Music and ambience crossfade on zone change, from the Biome or AreaInfo ids.
  - Positional effects come from a pool of AudioStreamPlayer3D with random pitch, and the
    listener follows the player.
  - It hooks itself to the existing signals as nodes enter the tree, so no scene needs audio
    nodes. The hooks cover swings, hits, damage and deaths, blocks, drops, pickups, potions,
    skill failures, zone travel, buying and selling, the inventory and footsteps.
- **Headless runs** set up every stream but never start playback.

## Regenerating assets

Every generated asset has its generator in `tools/`. After regenerating, run the import:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tools/gen_textures.gd
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tools/gen_icons.gd
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tools/gen_audio.gd
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG --import
```

Review tools:
- `tools/screenshot.gd` takes a windowed screenshot of any scene, or of the game at a spot in
  a zone. Its options include `--zone`, `--at`, `--inventory` and `--drops`, and it prints FPS
  and draw calls.
- `tools/character_preview.tscn` lines up every armour style and some goblins.
- `tools/icon_sheet.gd` renders all icons on one sheet.
- `tools/audio_report.gd` prints levels and loop seams and draws spectrograms.

Screenshots are saved in `tests/shots/`.

## Tests

Run every suite:

```bash
for t in walk fight skills loot equipment gems crafting town kit models icons audio zones; do C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_$t.gd | grep RESULT; done
```

The art and audio suites cover:
- `test_kit`: materials, all props, decorative collision, scatter determinism and exclusions,
  biomes, and the zone template's navmesh
- `test_models`: the model contract, equipment visuals for each weapon, shield and armour
  type, the walk animation and hit flashes
- `test_icons`: every base, orb and gem has an icon, and icons show on ground items and labels
- `test_audio`: the autoload, buses, every stream and loop, and zone music changes
- `test_zones`: reachability of every exit, spawn and vendor from every entry, markers clear of
  props, scatter coverage, and the shadowed-light budget

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

Run the headless Milestone 4b test:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_equipment.gd
```

The equipment test covers slot rules and two-handed conflicts, life, mana and attribute
maths, weapon damage and attack speed, armour, energy shield absorption and recharge, block and
evasion rates, the resistance cap, charm stats, and every inventory screen action.

Run the headless Milestone 4c test:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_gems.gd
```

The gems test covers the starting kit, socketing and swapping, support compatibility, mana
cost multipliers, the skill bar following gem changes, exact damage with Added Fire and
Brutality, Melee Splash, Life Leech, Default Attack, and gem tooltips.

Run the crafting test:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_crafting.gd
```

Run the town test (it uses the real game scene):

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_town.gd
```

It covers town safety, buying and selling at both vendors, prices, shards combining into orbs,
the shop closing when you walk away, travelling both ways, zone-local drops, respawning at the
zone entry, and gear stock refreshing after a trip.

The crafting test covers every orb's rules and results, keeping mods on upgrades, item level limits on
rerolls, Jeweller's ejecting gems, the inventory crafting flow with Shift, and the damage and
DPS estimates.

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
scenes/   player/, enemies/, levels/, ui/, kit/ (props, effects, zone template)
scripts/  components/ (reusable node behaviors), systems/ (level-wide services, Audio),
          characters/ (models, gear models, animator), kit/ (world kit), items/, ui/
data/     items/ JSON tables, gems/, potions/, biomes/
assets/   textures/, materials/, shaders/, icons/, audio/ (all generated by tools/)
tools/    asset generators and review tools
docs/     WORLD_KIT.md
tests/    headless test scripts; shots/ for screenshots
```
