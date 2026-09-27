# Path of Werdna — Design Notes

An isometric action RPG in the spirit of Path of Exile, built in **Godot 4.7.2**. Werdna is the hero.

## Decisions so far
- **Engine:** Godot 4.7.2, 3D, placeholder shapes until the gameplay feels good.
- **Tone:** relatively dark. Low light, torch pools, fog and muted colors.
- **Scope:** a light version of Path of Exile, not a full clone.
- **Starting class:** Warrior (STR). Later classes are an archer or thief (DEX) and a spellcaster (INT).
- **Level requirements:** deferred for now.

## Controls
| Input | Action |
|---|---|
| Left click (hold) | Move to the cursor, pick up an item or talk |
| Right click (hold) | Primary attack toward the cursor |
| Q W E R T | Skill slots 1–5 |
| 1 / 2 | Health potion / mana potion |
| 3–5 | Reserved for future potions |
| I / C / P | Inventory / character sheet / skill tree |
| Alt (hold) | Show ground-item labels |
| Esc | Menu |

Holding left click on an enemy moves you instead of attacking. Right click always attacks, which makes kiting reliable.

## Attributes
| Attribute | Per point (starting values) | Main user |
|---|---|---|
| **STR** | +0.5 max life, +0.2% melee physical damage | Warrior |
| **DEX** | +2 accuracy, +0.2% evasion | Archer or thief |
| **INT** | +0.5 max mana, +0.2% energy shield | Spellcaster |

## Damage and defense
- **Damage types:** physical, fire, cold, lightning and chaos.
- **Resistances:** fire, cold, lightning and chaos, each capped at 75% by default.
- **Defenses:**
  - **Armour** comes from STR gear and reduces physical hits.
  - **Evasion** comes from DEX gear and gives a chance to avoid hits.
  - **Energy shield** comes from INT gear. It is a recharging buffer that absorbs damage before life.
- **Armour bases:** each slot has pure bases (AR, EV or ES) and hybrid bases (AR/EV, AR/ES or EV/ES).

## Gear
**Slots (10):** main hand, off hand, chest, helm, gloves, boots, ring ×2, amulet and charm.
A two-handed weapon uses both hand slots.

### Item level and mod pools
- Every item drops with an **item level (iLvl)** equal to the level of the area or monster it came from.
- Each affix has **tiers**, and each tier has a minimum iLvl. A higher iLvl unlocks stronger tiers.
- Each base has **tags** such as `body_armour`, `str_armour`, `ring` or `two_hand_weapon`. An affix can only roll on items whose tags match its pool. For example, attack speed can't roll on a chest.
- An item can't roll the same affix twice.

### Implicit mods
- Some bases have one fixed **implicit** mod, which doesn't count toward the affix limits. Example: a Coral Ring has +life, and a Jade Amulet has +DEX.
- Not every base has an implicit. Most armour pieces don't, while rings, amulets and some weapons do.
- Implicits can make similar bases feel different from each other.

### Rarity
| Rarity | Prefixes | Suffixes | Notes |
|---|---|---|---|
| Common | 0 | 0 | Base stats only |
| Magic | 0–1 | 0–1 | At least 1 affix |
| Rare | 0–2 | 0–2 | Randomly named |
| Legendary | 0–3 | 0–3 | Same pools and iLvl limits as rares, but tier weights are biased upward |

**Legendary tier bias:** when a legendary rolls or rerolls an affix, the weights of the higher tiers are multiplied by a bias factor. The starting idea is `weight × (1 + 0.5 × tier_rank)`, where the best tier has the highest rank. Legendaries still can't exceed the iLvl limit.

### Crafting orbs
Upgrade orbs **keep the existing affixes and add new ones**. Reroll orbs replace everything.

| Orb | Effect |
|---|---|
| Transmutation | Common → magic. Adds 1–2 affixes. |
| Augmentation | Magic: adds 1 affix if a slot is open. |
| Alteration | Magic: rerolls all affixes. |
| Regal | Magic → rare. Keeps affixes and adds 1. |
| Chaos | Rare: rerolls all affixes (3–4). |
| Ascension | Rare → legendary. Keeps affixes and adds 1 or more with the legendary tier bias. |
| Scouring | Any → common. Removes all affixes but keeps the implicit. |
| Jeweller's | Rerolls the socket count. |

- Legendary rerolls, such as a Chaos Orb used on a legendary, also get the legendary tier bias. The exact rules come in the Loot milestone.

### Charms (special mod table)
- There are several **charm bases**, and each base has its own mod pool. Each charm rolls up to 2 prefixes and 2 suffixes.
- Charm mods should feel like mechanics, not stat sticks. Candidate mods:
  - **Culling strike:** kills enemies below 10% life.
  - **Item rarity** and item quantity.
  - **Life recoup:** a portion of damage taken comes back as life over time.
  - **Movement speed.**
  - **Potion charges** gained on kill, or potion effect.
  - **On-kill effects:** chance to explode, gain a frenzy or endurance buff, or gain mana.
  - **Cooldown recovery.**
  - **Stun duration** or stun threshold.
  - **Onslaught** (a speed buff) on kill.
  - **Chance to avoid** being stunned or elemental ailments.
- Example charm bases:
  - **Bone Charm:** on-kill effects and culling strike.
  - **Iron Charm:** recoup and defensive utility.
  - **Gilded Charm:** rarity and quantity.
  - **Swift Charm:** movement and cooldowns.

## Sockets and gems
- Sockets are **colorless**, and every socket on an item is linked. Supports only affect active gems on the same item.

| Item | Sockets |
|---|---|
| Body armour | up to 4 |
| Two-handed weapon | up to 4 |
| Helm, gloves, boots | up to 2 |
| One-handed weapon, shield | up to 2 |
| Rings, amulet, charm | 0 |

- **Socket count** is random from 1 up to the slot's maximum, biased toward fewer sockets. For example, the weights for a 4-socket item could be 1s: 40, 2s: 30, 3s: 20, 4s: 10. A Jeweller's Orb rerolls the count with the same weights.
- **Gem acquisition:** gems come from **quest rewards and vendors only**. Monsters never drop them.

- **Active gems** (3 to start):
  - **Heavy Strike:** a single-target melee hit.
  - **Cleave:** an arc hit on several enemies.
  - **Leap Slam:** jump to a spot and damage enemies around it.
- **Support gems** (5 to start):
  - **Added Fire:** adds fire damage.
  - **Melee Splash:** damages enemies near the target.
  - **Faster Attacks:** increases attack speed.
  - **Life Leech:** heals you for part of the damage you deal.
  - **Brutality:** more physical damage, but no elemental damage.
- **Skill bar:** RMB and QWERT bind to any socketed active gem.
- Gems gain XP and level up, which improves damage and cost. There's no gem quality for now.

## Potions
- **Health (key 1)** and **mana (key 2)**.
- A potion restores its amount over a short duration. Using it again while active refreshes it.
- Charges are gained on kills and fully refill in town.

## Skill tree
- One shared tree with **STR**, **DEX** and **INT** regions. Each class starts in its own region, and the regions between them allow hybrid builds.
- Players earn 1 point per level, plus a few points from quests.
- **Node types:** small nodes (minor stats), notables (named rewards), and keystones (rule-changing tradeoffs).
- Build the **warrior region first**, with about 30–40 nodes.
- **Data model:** each `PassiveNode` resource has an id, position, modifiers and connections. The whole tree is one resource.

## World structure
**Tutorial zone: "Goblin Hollow"**
- The zone is handmade and linear, with dark woods leading into a goblin camp.
- It should take about 10–15 minutes and bring Werdna from level 1 to level 3.
- **Enemies:** goblin grunts (melee), goblin slingers (ranged), and a goblin chieftain as a small boss at the end.
- **Loot:** guaranteed early drops so the player learns the systems:
  - a magic item
  - a 2-socket item
  - a few Transmutation Orbs
- **Quest rewards:**
  - the first active gem (Heavy Strike) at the start
  - a support gem for killing the chieftain
- The end of the zone leads into the first procedural map.

**Procedural maps (after the tutorial)**
- Maps are built from **handmade room and corridor chunks** that snap together at connectors. This keeps the look and lighting controlled while still giving variety.
- **Area level** sets monster level and iLvl, and it goes up as the player progresses.
- Each map has a few monster packs, an optional rare or boss at the end, and an exit to the next map.
- Later, maps could have mods like PoE maps (for example, "monsters deal extra fire damage" in exchange for more item quantity).

**Hub town: "Werdna's Camp"**
- A small, safe camp with vendors, the shared stash and a map device.
- **Portal:** a free, unlimited skill (no scroll item) that opens a portal back to camp. The portal stays open, so the player can return to the same map.
- **Vendors** sell gear and gems for orbs. There is no gold.
  - **Gear vendor:**
    - sells common and magic bases
    - buys items and pays in orb shards, e.g. 5 Transmutation shards make 1 orb
    - uses a rotating stock that refreshes when the player levels up or finishes a map
  - **Gem vendor:** sells active and support gems. The price scales with how powerful the gem is.
- Gems still come only from quests and vendors.

## Monsters
- **Rarity:** normal, magic and rare. Later, uniques for bosses.
  - **Magic monsters:** come in packs, with 1–2 monster mods and more life.
  - **Rare monsters:** have 2–4 monster mods and much more life, and usually lead a pack.
- **Example monster mods:**
  - Hasted
  - Extra Fire Damage
  - Armoured
  - Regenerating
  - Vampiric
  - Frenzied
  - Explodes on Death
- **Drop rates:** higher rarity means more item quantity and rarity, and a better chance at orbs.
- **Orbs** drop from monsters. The rarest orbs, such as Ascension, are very uncommon.

## Weapons (warrior)
| Type | One-handed | Two-handed | Mod identity |
|---|---|---|---|
| Axe | ✓ | ✓ | Bleed, physical damage, crit multiplier |
| Sword | ✓ | ✓ | Bleed, attack speed, accuracy, crit chance |
| Mace | ✓ | ✓ | Stun (duration and threshold), area of effect, physical damage |

- Each weapon type has its own affix pool and weights. Axes and swords share a `bladed` tag, which is how bleed rolls on both.
- One-handed weapons can be paired with a shield. Two-handed weapons have higher base damage and up to 4 sockets.
- Later we can add more types and more complex rules.

## Progression and meta
- **Level cap:** 100. The XP curve is steep enough that level 100 is only for extremely dedicated play.
- **Death penalty:** none. You respawn at the last checkpoint or in town.
- **Save slots:** 3 characters.
- **Stash:** shared between all characters. It's stored in its own file, separate from character saves.

## Stats model
Each modifier is `{stat, type: flat | increased | more, value}`.
The final value is `(base + Σflat) × (1 + Σincreased) × Π(1 + more)`.
Attributes, gear, passives, gems and buffs all feed the same pipeline.

## Godot architecture
- An isometric `Camera3D` with a `NavigationRegion3D` for click-to-move.
- **Item bases and affixes are JSON** in `data/items/`. Large tables are easier to read and tune as JSON. Everything else uses `.tres` resources.
- **Data as `.tres` resources:** `ItemBase`, `AffixDef` (with tiers), `AffixPool`, `GemData`, `PassiveNode`, `EnemyData`.
- **An item instance:** `{base_id, ilvl, rarity, affixes: [AffixRoll], sockets: [gem or null]}`.
- **Autoloads:** `Game`, `Events` (a signal bus) and `LootTables`.
- **Input Map actions:** `move`, `attack`, `skill_1..5` and `potion_1..5`.
- **Combat detection:** `Area3D` hitboxes and hurtboxes on the physics layers player, enemy, player_attack, enemy_attack and world.

```
res://
  scenes/   (player, enemies, levels, ui)
  scripts/  (components, systems)
  data/     (bases, affixes, gems, passives, enemies, charms)
  assets/
```

## Milestones
1. **Walk:** camera, click-to-move, and a dark test arena with lighting.
2. **Fight:** Heavy Strike (hardcoded), one enemy type, health bars and death.
3. **Gems and potions:** the gem data model, the 3 actives on the skill bar, mana, and both potions.
4. **Loot**, split into three parts:
   - **4a, items and drops:** item levels, bases, affix rolling, drops, ground labels and pickup. *(Done.)*
   - **4b, inventory and equipment:** the inventory screen, equipping the 10 slots, and gear stats applying to Werdna. *(Done.)*
   - **4c, sockets and gems:** socketing gems, support gems, and the skill bar drawing from socketed gems. *(Done. Gem XP moved to Milestone 5.)*
5. **Town and zones (done early):** Werdna's Camp with a gear vendor and a gem vendor, and zone travel to the Goblin Shore. The stash and the portal skill come later.
6. **Progression:** XP, levels, gem XP and levels, attributes, and the warrior region of the skill tree.
7. **Content:** more enemies, a boss, and procedural map pieces.

## Future polish
- **Item art:** inventory icons and distinct ground models per item type. Items are coloured boxes with names for now.

## Open questions
1. **Orb economy:** exact drop rates, vendor prices, and how shards work. These will be tuned during the Loot milestone.
2. **Bleed and stun rules:** how bleed damage and stun thresholds are calculated. This is decided in the Fight and Skills milestones.
3. **Map device:** does it use map items, as in PoE, or just generate the next map at a higher area level?
