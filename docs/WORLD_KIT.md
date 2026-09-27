# World kit

The world kit is a set of reusable building blocks for zones. It includes materials, shaders,
props, atmosphere effects, biomes, a prop scatter tool and a zone template. It's all generated
procedurally inside Godot, so nothing needs downloading, and every piece can be swapped for
real art later without touching the zones that use it.

```
assets/textures/   generated tileable albedo + normal PNGs (tools/gen_textures.gd)
assets/materials/  StandardMaterial3D and ShaderMaterial .tres files
assets/shaders/    water, foliage_sway, cloth_sway, ground_blend
scripts/kit/       KitProp, KitMesh, KitMaterials, KitFx, FlickerLight, AmbientEffect,
                   Biome, ScatterEntry, ScatterExclusion, PropScatter, KitGround, Zone
scripts/kit/props/ one small script per prop
scenes/kit/props/  one scene per prop (just the script plus export values)
scenes/kit/effects/ dust_motes, fireflies, ground_mist, falling_ash, sea_spray
scenes/kit/        zone_template.tscn, kit_showcase.tscn, water_plane.tscn
data/biomes/       camp.tres, shore.tres, forest.tres
```

## Build a new zone

1. **Duplicate** `scenes/kit/zone_template.tscn` into `scenes/levels/`. Rename the root node;
   the game and tests refer to zones by root name.
2. **Pick a biome** on the root `Zone` node, for example `data/biomes/forest.tres`. The zone
   then creates its `WorldEnvironment` (background, ambient light, fog and volumetric fog)
   and `Moonlight`, and spawns the biome's ambient effects across `bounds`. Set `bounds` to
   the playable area.
3. **Fill in `AreaInfo`:** the zone name, the area level, and whether it's a town. Its
   `music_id` and `ambience_id` override the biome's if they're set.
4. **Size the ground.** `NavigationRegion3D/Ground` is a `KitGround`. It uses the biome's
   ground material unless you give it one.
5. **Place entries and exits.**
   - Add a `Marker3D` under `Entries/` for every way into the zone. Other zones name these as
     their `target_entry`.
   - Add a `ZoneExit` (scripts/systems/zone_exit.gd) under `Exits/` for every way out.
   - Put a `GateProp` over an exit to make it look like a gate. The gate's opening has no
     collider.
6. **Scatter props.**
   - The template's `NavigationRegion3D/PropScatter` places the biome's **props** (rocks,
     trees). These block movement, and the navmesh bakes around them.
   - `Decor` places the biome's small decorative **scatter** (grass, pebbles, bushes). It has
     no colliders.
   - Both avoid every `Marker3D` (entries, spawn points), every `ZoneExit`, vendors and any
     `ScatterExclusion`. Draw a `ScatterExclusion` path along roads and around plazas.
   - Change `scatter_seed` for a different layout, or press **Regenerate** in the inspector.
     Layouts are deterministic, so the zone looks the same every run.
7. **Hand-place hero props** under `NavigationRegion3D/Props` if they should block movement.
   Put them anywhere else if they shouldn't. Examples: a campfire, tents, stalls, a wreck.
8. **Light it.** Add `TorchProp`s, braziers and campfires. Each carries its own
   `FlickerLight`, so turn off `shadows` on the less important ones for performance.
9. **Add gameplay** as usual: an `EnemySpawner` with markers, vendors and so on.

The navmesh bakes at load from every static collider under `NavigationRegion3D` on the world
layer (layer 1). That's why collidable props and scatters must live there.

## Pieces

### Props (`KitProp`)
Each prop builds its meshes, lights, particles and colliders in `_build()`. Its generated
nodes are rebuilt on load, in the editor too, and never saved.

- **`variant`** seeds the random shape. Props with the same settings and variant share one
  cached mesh.
- **`collision`** off makes a prop decorative. `PropScatter` switches it off for decorative
  entries.
- **Pivots** are at ground level, and each prop script's header documents its orientation.

| Scene | Script | Notes |
|---|---|---|
| torch, wall_torch | TorchProp | post or wall bracket, FlickerLight, flame/ember/smoke particles |
| campfire | CampfireProp | stone ring, logs, coals, big fire, strong light |
| brazier | BrazierProp | iron bowl on legs |
| boulder, rock_cluster, cliff_chunk, pebbles | RockProp | `style`, `size`, `tint` |
| dead_tree, pine | TreeProp | `kind`, `height`, bark and foliage tints; pines sway |
| bush, dry_bush | BushProp | walk-through, sways |
| grass_clump, dune_grass | GrassProp | decorative, sways |
| tent | TentProp | A-frame, open at +Z |
| palisade | PalisadeProp | a `length`-metre run along X; chain segments |
| gate | GateProp | walkable opening, posts, skull, optional torches |
| crate, barrel, sack | CrateProp, BarrelProp, SackProp | |
| market_stall | MarketStallProp | counter at +Z; the vendor stands behind it |
| driftwood | DriftwoodProp | bleached log |
| shipwreck | WreckProp | hull ribs, planks, fallen mast |
| banner | BannerProp | cloth_sway shader, per-instance colour |

### Materials and shaders
- `KitMaterials.named("stone")` loads `assets/materials/stone.tres`. `flat()`, `iron()` and
  `glow()` make cached colour materials.
- Kit materials use triplanar mapping, so procedural meshes need no UVs. They also multiply
  vertex colour into the albedo, so tints don't need extra materials.
- **`ground_blend.gdshader`** blends two ground materials with a noisy edge, using a straight
  gradient, a circle, or a painted mask. See `ground_shore.tres`, `ground_camp.tres` and
  `ground_forest.tres`.
- **`water.gdshader`** has a vertex swell, scrolling normals, depth colour and shoreline foam.
  It needs opaque geometry under the surface, and a sloping seabed gives the best shoreline.
- **`foliage_sway.gdshader`** and **`cloth_sway.gdshader`** handle wind.

### Atmosphere (`AmbientEffect`)
- One GPUParticles3D script with five kinds: dust, fireflies, mist, ash and sea spray.
- `density` is in particles per 100 m², so an effect scales with its box.
- A Zone stretches biome effects over its bounds. Effects with `fit_to_zone` off, like sea
  spray, are placed by hand.

### Biomes (`Biome`)
A biome holds:
- sky and fog settings, and ambient and moonlight colours
- its ground, path and cliff materials
- its `props` and `scatter` lists (`ScatterEntry`: scene, weight, scale range, tilt,
  decorative, spacing, variants, property overrides)
- its ambient effects
- its music and ambience ids

To add a biome, duplicate one in `data/biomes/`.

## Regenerating assets

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tools/gen_textures.gd
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG --import
```

Texture recipes live in `tools/gen_textures.gd`, one `_make_<name>()` function each. The first
run writes `.import` files so textures import as mipmapped, VRAM-compressed 3D textures.

To look at the kit, take a windowed screenshot of the showcase:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tools/screenshot.gd -- --scene=res://scenes/kit/kit_showcase.tscn --at=0,0,2 --distance=30
```

## Swapping in real art later

- **Textures:** overwrite the PNGs in `assets/textures/` with the same names, or point a
  material in `assets/materials/` at new textures. Every prop and zone updates.
- **Materials:** replace a `.tres` in `assets/materials/` with any Material of the same name.
- **Props:** replace a scene in `scenes/kit/props/` with an imported model scene.
  - Keep the pivot at ground level and centred, keep the same footprint, and add a
    StaticBody3D on layer 1 if it should block movement.
  - Biome scatter lists and zones reference the scene path, so they pick up the new model.
  - For decorative use, PropScatter clears the collision layers of non-kit scenes.
- **Effects:** replace a scene in `scenes/kit/effects/` with any GPUParticles3D scene.
- **Biomes:** point ScatterEntry scenes at new props, or add entries.
