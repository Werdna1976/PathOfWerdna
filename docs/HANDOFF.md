# Path of Werdna: handoff notes

Paused on 2026-09-27. Read this first when picking the project back up, then `DESIGN.md` (the
design, the source of truth) and `README.md` (systems, controls and tests).

## Where things stand

**Playable:**
- **Start:** the game runs from `scenes/main.tscn` (Godot 4.7.2) and starts in Werdna's Camp.
- **Controls:** click to move, right click to attack, QWERT for skills, 1–2 for potions,
  I/C for the inventory and character sheet, Alt for mod tiers.
- **Combat:** Heavy Strike, Cleave and Leap Slam as socketable gems, with 5 support gems. Mana
  and potions work. Goblins fight back and drop loot.
- **Loot:** PoE-style items: item levels, prefixes and suffixes, rarities, local and global mods,
  and about 186 bases with tiered affixes up to item level 84. Orb crafting works for all 8 orbs.
- **Items:** a 12×5 grid inventory, 10 equipment slots, sockets, and a character sheet with
  skill DPS.
- **Town:** Werdna's Camp is safe, with a gear vendor, a gem vendor, buying and selling for orbs
  and shards, and a gate to the Goblin Shore (area level 3).
- **Look:** a procedural world kit (textures, props, particles, biomes, a scatter tool), 3D
  models for Werdna and the goblin, and item icons. See `docs/WORLD_KIT.md`.
- **Sound:** layered recipes of recorded CC0 samples (`data/audio/recipes.json`, credits in
  `assets/audio/CREDITS.md`). Hits depend on the weapon, with armour and crit layers, and there
  are equip sounds by item type.
- **Music:** generated placeholder tracks for the town and Shore.

**Tests:** 13 headless suites in `tests/`, all passing at the last commit. Run each with:

```bash
C:/GoDot/Godot_v4.7.2-stable_win64.exe --headless --path C:/GoDot/Projects/Godot-Opus-ARPG -s res://tests/test_<name>.gd
```

## Open work, in suggested order

1. **Potion sound, and more voice variety.**
   - The potion still uses the generated sound.
   - The CC0 drink set (qubodup, "Liquid Bottle Drink Set") and 15 male strain sounds
     (qubodup, "slightscreams") are downloaded as FLAC in `.tmp_dl/`. That folder is gitignored,
     so it only exists on this PC; re-download from OpenGameArt if it's gone.
   - Godot can't import FLAC, so they need converting to WAV first. That needs a converter:
     `pip install soundfile` was proposed but not yet approved.
   - Then add them to `recipes.json`: `potion_drink` becomes swallow + bottle-open, and the
     strain sounds join `player_hurt`.
2. **Tune the audio by ear.** All volumes and pitches in `recipes.json` were set without
   listening.
3. **Real music.** Candidate CC0 tracks, all on OpenGameArt:
   - "The Longing" for the town
   - "Memories", "Together" or "From Here to Where?" for the Shore
   - These were proposed but not downloaded. The Audio autoload loads WAV loops from
     `assets/audio/music/<id>.wav`, so it would need small changes to load OGG/MP3.
4. **Stash and portal.** DESIGN.md has a shared stash and a free portal skill. Neither is built.
5. **Milestone 6, progression:** character XP and levels (cap 100), gem XP and levels,
   attribute growth, and the warrior region of the passive tree.
6. **Later:**
   - monster rarity (magic and rare packs with mods)
   - bleed, stun and the other `*` stats that roll on gear but do nothing yet
   - the tutorial zone
   - procedural maps and the map device
   - dual wielding
   - save slots

## Working notes

- **GitHub:** `Werdna1976/PathOfWerdna`. Check `git log origin/main..main` for unpushed commits.
- **Unattended scheduled runs:** the permission rules in `~/.claude/settings.json` must use
  `//c/...` paths, and the tasks should use only command forms already tested. The first
  overnight run stalled on one unapproved command.
- **Audio startup:** the Audio autoload hooks nodes that already exist at startup, because in a
  normal launch the main scene loads before autoloads are ready.
- **Asset scripts:** kept in the repo so assets can be regenerated: `tools/gen_*.gd` (textures,
  audio, icons) and `tools/slice_wav.gd`.
