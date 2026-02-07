# AoE2 Clone - Roadmap

**Last updated:** 2026-02-03 (Phase 3 replaced by Phase 3.1 rule-based AI)

## Goal

Faithfully reproduce Age of Empires 2 as defined by the AoE2 manual (`docs/AoE_manual/`). We aim to implement all core systems, units, buildings, and mechanics from the original game.

We're happy to stop earlier if we reach diminishing returns (e.g., obscure features, excessive complexity). But the target is full reproduction, not a "lite" version.

## Design Principles

1. **Each phase = playable game** - Never break what works
2. **Gameplay before polish** - Colored rectangles are fine until Phase 10
3. **AI reproduces original behavior** - Match AoE2's AI as closely as possible
4. **All 4 ages** - Dark, Feudal, Castle, Imperial (added incrementally)

## Out of Scope

The following features from the original AoE2 are intentionally excluded:

| Feature | Reason |
|---------|--------|
| **Online multiplayer** | Networking, lobbies, chat - focus is single-player vs AI |
| **Campaigns** | Historical campaigns (Joan of Arc, etc.) - content-heavy, not core gameplay |
| **Scenario/Map Editor** | Custom map creation tools |
| **Campaign Editor** | Custom campaign creation tools |
| **Custom AI scripting** | CPSB-style AI behavior scripting |
| **Recording/Replay system** | Game recording and playback |
| **Female villagers** | Cosmetic gender variation |
| **Hero units** | Special named campaign units |
| **Online encyclopedia** | Civilization histories, Middle Ages reference content - low priority |
| **Lock game speed** | Less relevant for single-player vs AI |

These may be reconsidered if core gameplay reaches completion.

---

## Phases Overview

| Phase | Name | Core Focus |
|-------|------|------------|
| 0 | MVP | Playable foundation: 2 resources, basic units, AI opponent, win condition |
| 1 | Complete Economy | 4 resources, drop-off buildings, trading |
| 2 | Military Foundation | Combat triangle, fog of war, counter-units |
| 2.5 | Bug Fixes & Core Mechanics | Production queue, villager-based building, pathfinding fixes |
| 2.6 | UI Overhaul | AoE2-style bottom panel, minimap, context-sensitive cursors |
| 3 | ~~Strong AI~~ | *(Replaced - see Phase 3.1)* |
| 3.1 | Rule-Based AI | Competitive AI using AoE2-style rule system |
| 4 | Age System | Dark → Feudal → Castle progression |
| 5 | Tech & Upgrades | Blacksmith, unit upgrades, research system |
| 6 | Monks & Relics | Conversion, healing, relic victory |
| 7 | Walls & Basic Defense | Walls, gates, basic towers, garrison |
| 8 | Advanced Defense & Siege | University, siege units, advanced towers |
| 9 | Imperial Age | 4th age, late-game units, Wonder victory |
| 10 | Polish & UX | Control groups, formations, audio, minimap modes |
| 11 | Naval Economy | Dock, fishing, transport (Optional) |
| 12 | Naval Combat | Warships, water maps (Optional) |
| 13 | Civilizations | 13 civs, unique units, tech trees (Optional) |
| 14 | Team Games & Allied AI | Multiple AI, team battles, allied mechanics (Optional) |

---

## Phase 0: MVP (Complete)
**Goal:** Playable game foundation with basic economy, combat, and AI opponent

**Tier 1: Foundation**
- [x] Map: 60x60 tiles, green grass ColorRect
- [x] Camera: WASD/arrow keys + edge scrolling, clamped to map bounds
- [x] Resources: Trees (100 wood), Berry bushes (75 food), shrink as depleted
- [x] Units: Villager with states (IDLE, MOVING, GATHERING, RETURNING)
- [x] Buildings: Town Center (trains villagers), House (+5 pop cap)
- [x] Selection: Click select, box select, right-click commands
- [x] HUD: Resource display, population, Build buttons, TC panel, Info panel
- [x] Visual Feedback: Villagers change color when carrying resources

**Tier 2: Gameplay (Combat & Economy)**
- [x] Barracks building (100 wood, 3x3, trains militia)
- [x] Militia unit (60 food + 20 wood, 50 HP, 5 damage, attack states)
- [x] Combat system (HP, take_damage, die, attack command)
- [x] Farm building (50 wood, 2x2, infinite food at 0.5/sec)
- [x] Team system (`@export var team: int = 0` on Unit)
- [x] Building collision detection
- [x] Militia uses NavigationAgent2D for pathfinding

**Tier 3: Game Loop (AI & Win Condition)**
- [x] AI resource tracking (separate from player)
- [x] AI Controller spawns base at (1700, 1700)
- [x] AI villagers auto-gather and deposit to AI TC
- [x] AI builds houses when pop capped
- [x] AI builds barracks when wood > 100
- [x] AI trains militia
- [x] AI attacks when military >= 3
- [x] Building HP (200 default, 500 for TC)
- [x] Buildings have team property
- [x] Militia can attack buildings
- [x] Win condition: Enemy TC destroyed
- [x] Lose condition: Player TC destroyed
- [x] Victory/Defeat overlay with restart button
- [x] Team colors: Player = Blue, AI = Red


**Done when:** Player can defeat AI opponent by destroying their Town Center.

---

## Phase 1: Complete Economy (Complete)
**Goal:** Establish full 4-resource economy with trading

| Feature | Type | Notes |
|---------|------|-------|
| Stone resource | Resource | New resource nodes on map |
| Gold resource | Resource | New resource nodes on map |
| Mining Camp | Building | Drop-off for stone/gold |
| Lumber Camp | Building | Drop-off for wood |
| Mill | Building | Drop-off for food, farms built around mills |
| Fish Trap | Building | Deferred to Phase 10 (requires Fishing Ship + water terrain) |
| Market | Building | Commodity trading (buy/sell resources) |
| Dynamic market pricing | Mechanic | Prices fluctuate based on all players' buy/sell activity |
| Trade Cart | Unit | Generate passive gold via trade routes |
| Trade distance scaling | Mechanic | Longer trade routes = more gold per trip |
| Tribute system | Mechanic | Send resources to other players (30% fee) |
| Sheep stealing | Mechanic | Sheep change ownership if enemy sees them without friendly units nearby |
| Sheep herding AI | Mechanic | Villagers auto-herd sheep to drop-off before killing |
| Resource depletion notification | UI | Villagers go idle + notification when resource depletes |

**Food Sources (from manual):**
| Source | Type | Notes |
|--------|------|-------|
| Sheep | Herdable | Neutral until seen; can be stolen; villagers herd to drop-off then kill |
| Deer | Huntable | Food source, villagers must hunt |
| Wild Boar | Huntable | High food, but attacks back - use multiple villagers |
| Shore Fish | Gatherable | Villagers can fish from shore (requires water terrain - Phase 10) |
| Wolves | Hazard | Attack units, yield no food - environmental danger |

**AI updates:** AI gathers all 4 resources, builds camps near resource clusters, uses market, herds sheep.

**Done when:** Player and AI both manage 4-resource economy with drop-off optimization and trading.

**Basic Sprites (end of Phase 1):**

| Feature | Type | Notes |
|---------|------|-------|
| Asset folder structure | Setup | `assets/sprites/` with units/, buildings/, resources/ subfolders |
| Basic unit sprites | Art | Placeholder sprites for villager, militia. Distinguishable, not polished. |
| Basic building sprites | Art | Town Center, House, Barracks, Farm, Mill, Lumber Camp, Mining Camp, Market |
| Basic resource sprites | Art | Trees, berries, gold, stone |

*This is for testability, not polish. Full art pass remains in Phase 9.*

---

## Phase 2: Military Foundation + Fog of War
**Goal:** Rock-paper-scissors combat with counter-units and information warfare

**Sub-phases (approved 2026-01-30, updated 2026-01-30):**
- **2A**: Archery Range + Archer (ranged combat foundation) — *Complete*
- **2B**: Stable + Scout Cavalry + Spearman + armor system + bonus damage system — *Complete*
- **2C**: AI Economic Foundation (make AI functional with existing features) — *Complete*
- **2D**: Skirmisher + Cavalry Archer (complete combat triangle) — *Complete*
- **2E**: Fog of War + basic stances + AI military behavior + attack notifications — *Complete*

**All Phase 2 Features:**

| Feature | Type | Sub-phase | Notes |
|---------|------|-----------|-------|
| Archer | Unit | 2A | Ranged, beats infantry at distance |
| Archery Range | Building | 2A | Trains archers, skirmishers |
| Spearman | Unit | 2B | At Barracks, cheap counter to cavalry |
| Scout Cavalry | Unit | 2B | Fast, good LOS, resistant to conversion |
| Stable | Building | 2B | Trains cavalry units |
| Skirmisher | Unit | 2D | Anti-archer unit, cheap, bonus vs archers |
| Cavalry Archer | Unit | 2D | Mobile ranged, hit-and-run |
| Fog of War | System | 2E | Unexplored = black, explored but unseen = fog, visible = clear |
| Basic stances | Mechanic | 2E | Aggressive, Defensive, Stand Ground, No Attack |
| Terrain bonuses | Mechanic | 2E | Units firing from elevation get attack bonus |
| Attack notifications | Audio | 2E | Horn for military under attack, bell for villagers/buildings |

**Combat triangle:**
```
Infantry (Militia) -> baseline, good vs buildings
Archers -> shred infantry, die to skirmishers and cavalry
Skirmishers -> counter archers, weak to infantry
Spearmen -> destroy cavalry, die to archers
Cavalry -> fast, crush archers, die to spears
Cavalry Archers -> mobile ranged, weak to skirmishers
```

**AI updates:** AI builds mixed army, scouts the map, attempts to counter player composition.

**Done when:** Battles feel tactical - unit composition matters. Scouting matters.

---

### Sub-phase 2C: AI Economic Foundation

Makes the AI functional by using all available Phase 0-2B features. Without this, the AI auto-loses because it never grows its economy.

| Feature | Priority | Notes |
|---------|----------|-------|
| Train villagers continuously | Critical | Target 20+ villagers before heavy military |
| Build farms | Critical | Sustainable food when berries/sheep depleted |
| Build mills | High | Drop-off efficiency for food/farms |
| Economic growth targets | High | Don't attack until economy established |
| Build multiple barracks | Medium | Scale military production |
| Build multiple camps | Medium | Expand to new resource areas |
| Rebuild destroyed buildings | Medium | Recover from raids |
| Build Archery Range + train archers | Medium | Use Phase 2A content |
| Build Stable + train scouts/spearmen | Medium | Use Phase 2B content |
| Villager allocation ratios | Medium | Balance gatherers across resources |
| Trade cart usage | Low | Passive gold when market exists |

**2C Done when:** AI booms to 20+ villagers, builds farms, uses all military buildings, presents a real challenge.

---

## Phase 2.5: Bug Fixes & Core Mechanics
**Goal:** Fix outstanding bugs and add core AoE2 mechanics that were deferred

This is a cleanup phase before moving to Strong AI. Addresses bugs discovered during Phase 2 playtesting and adds fundamental mechanics that should have been in earlier phases.

**Sub-phases (approved 2026-01-31):**
- **2.5A**: Bug fixes + Production queue
- **2.5B**: Villager-based building construction

---

### Phase 2.5A: Bug Fixes + Production Queue

| Feature | Type | Notes |
|---------|------|-------|
| Enemy building label | UI | Show "Enemy" label when clicking enemy buildings |
| Unit status live update | Bug fix | Info panel updates in real-time when selected unit's state changes (e.g., IDLE → ATTACKING) |
| Pathfinding blocking fix | Bug fix | Units path around other units/animals instead of getting stuck |
| Production queue | Mechanic | Queue up to 15 units per building; resources deducted when queued, refunded if cancelled |

**2.5A Done when:** Bugs are fixed, production queue works for all training buildings.

---

### Phase 2.5B: Villager-Based Building Construction

| Feature | Type | Notes |
|---------|------|-------|
| Build commands on villager | UI | Build buttons appear when villager selected (not global panel) |
| Build categories | UI | Economic (Mill, Lumber Camp, Mining Camp, Farm, Market) vs Military (Barracks, Archery Range, Stable) |
| BUILDING villager state | Mechanic | Villager walks to build site and constructs |
| Construction time | Mechanic | Buildings start at 1 HP, HP increases over time as villager works |
| Multi-villager construction | Mechanic | Additional villagers speed up construction |
| Construction cancellation | Mechanic | Partially built buildings can be deleted (no resource refund) |
| AI builder behavior | AI | AI villagers use same construction system |

**2.5B Done when:** Buildings are constructed by villagers over time, matching AoE2 behavior.

---

## Phase 2.6: UI Overhaul
**Goal:** Modernize the HUD to match AoE2's classic layout with bottom panel, minimap, and context-sensitive cursors

This phase consolidates the scattered floating panels into a unified AoE2-style interface. Reference screenshot: `images/screenshots/aoe_screenshot.jpeg`

**Sub-phases (approved 2026-02-01):**
- **2.6A**: Bottom panel layout + minimap + basic aesthetics — *Complete*
- **2.6B**: Context-sensitive cursor system — *Complete*

**Key files to read first:**
- `scripts/ui/hud.gd` + `scenes/ui/hud.tscn` - Current HUD (floating panels to consolidate)
- `scripts/fog_of_war.gd` - Fog system for minimap visibility integration
- `images/screenshots/aoe_screenshot.jpeg` - Visual reference for layout

---

### Phase 2.6A: Bottom Panel + Minimap

| Feature | Type | Notes |
|---------|------|-------|
| Bottom panel layout | UI | ~150px tall panel replacing floating panels |
| Left section: Unit info | UI | Unit/building name, HP bar, attack/armor stats |
| Center section: Actions | UI | Context-sensitive text buttons (train, build, stance) |
| Right section: Minimap | UI | Terrain, resources, units, buildings with fog overlay |
| Top bar cleanup | UI | Resource icons, population, "Dark Age" placeholder |
| Basic aesthetics | Art | Stone/marble borders, muted parchment colors |
| Minimap click-to-pan | Input | Click location on minimap moves camera there |
| Minimap fog integration | System | Black = unexplored, dim = fog, bright = visible |

**2.6A Done when:** All UI consolidated into bottom panel, minimap shows game state with fog of war.

---

### Phase 2.6B: Cursor System

| Feature | Type | Notes |
|---------|------|-------|
| Cursor manager | System | Changes cursor based on hover context |
| cursor_default | Cursor | Normal pointer state |
| cursor_attack | Cursor | Hovering over enemy (with unit selected) |
| cursor_gather | Cursor | Hovering over tree with villager selected (axe) |
| cursor_hand | Cursor | Hovering over gold/stone/farm/sheep with villager selected |
| cursor_build | Cursor | Building placement mode (hammer) |
| cursor_forbidden | Cursor | Invalid placement location or action |

Cursor sprites location: `assets/sprites_extracted/cursors/`

**2.6B Done when:** Cursor changes contextually based on selection and hover target.

---

## Phase 3: Strong AI (Replaced)

The original Phase 3 implementation used procedural/imperative code that became unmaintainable. See `docs/ai_player_designs/phase3_failure_summary.md` for details.

Archived checkpoint docs: `docs/phase_checkpoints/archive/phase-3.0a.md` through `phase-3.0e.md`

**Replaced by Phase 3.1 below.**

---

## Phase 3.1: Rule-Based AI
**Goal:** Competitive AI using AoE2-style rule-based system

This phase re-implements the AI using independent rules that fire when conditions match, inspired by the original AoE2 AI scripting system.

**Key architecture:**
- Rules are independent - they don't call each other
- All matching rules fire each tick
- Clear conditions and actions per rule
- Easy to add/modify behaviors without cascading effects

**Reference docs:**
- `docs/ai_player_designs/aoe2_ai_rule_system.md` - How the real AoE2 AI works
- `docs/ai_player_designs/aoe2_strategic_numbers.md` - Tunable parameters

**Implementation design:** See `docs/ai_player_designs/godot_rule_implementation.md`

**Sub-phases (approved 2026-02-03):**
- **3.1A**: Core infrastructure + MVP behavior (rule engine, basic economy, militia, attack)
- **3.1B**: Full economy (4 resources, drop-offs, farms, animals, market)
- **3.1C**: Full military + intelligence (all units, scouting, defense, mixed composition)

---

### Phase 3.1A: Core Infrastructure + MVP Behavior

| Feature | Type | Notes |
|---------|------|-------|
| AIGameState | System | Wrapper exposing game state to rules (resources, unit counts, can_train, can_build, etc.) |
| AIRule base class | System | Interface for conditions() and actions() |
| Rule engine | System | Evaluates all rules each tick, handles action de-duplication |
| Strategic numbers | System | Dictionary of tunable parameters with AoE2-style defaults |
| Train villager rule | Rule | Train villagers up to target count |
| Build house rule | Rule | Build house when housing headroom < 5 |
| Gather food rule | Rule | Assign villagers to food |
| Gather wood rule | Rule | Assign villagers to wood |
| Build barracks rule | Rule | Build barracks when none exists and can afford |
| Train militia rule | Rule | Train militia from barracks |
| Attack rule | Rule | Attack when military >= threshold |

**3.1A Done when:** AI plays at MVP level using rule-based system - trains villagers, builds houses/barracks, gathers resources, trains militia, attacks.

---

### Phase 3.1B: Full Economy

| Feature | Type | Notes |
|---------|------|-------|
| 4-resource gathering | Rules | Gather gold and stone based on strategic number percentages |
| Build lumber camp rule | Rule | Build near trees when drop distance too far |
| Build mining camp rule | Rule | Build near gold/stone when drop distance too far |
| Build mill rule | Rule | Build near berries/hunt |
| Build farm rule | Rule | Build farms when natural food depleted |
| Sheep herding | Rule | Gather sheep, herd to TC |
| Hunting | Rule | Hunt deer/boar |
| Market buy/sell | Rules | Conservative trading when surplus/shortage |

**3.1B Done when:** AI manages full 4-resource economy with drop-off optimization and farms.

---

### Phase 3.1C: Full Military + Intelligence

| Feature | Type | Notes |
|---------|------|-------|
| Build archery range rule | Rule | Build when barracks exists |
| Build stable rule | Rule | Build when barracks exists |
| Train archer rule | Rule | Train archers |
| Train spearman rule | Rule | Train spearmen (counter to cavalry) |
| Train scout cavalry rule | Rule | Train scouts for scouting |
| Train skirmisher rule | Rule | Train skirmishers (counter to archers) |
| Train cavalry archer rule | Rule | Train cavalry archers |
| Scouting behavior | Rules | Send scout to explore, track enemy positions |
| Defense rules | Rules | Respond to threats, defend base when attacked |
| Mixed army composition | Rules | Build varied army based on enemy composition |
| Attack timing | Rules | Attack based on army size and game time |

**3.1C Done when:** AI uses all available units/buildings, scouts, defends, and presents a competitive challenge.

---

**Phase 3.1 Done when:** AI provides a competitive challenge using maintainable, debuggable rule-based logic.

---

## Phase 4: Age System
**Goal:** Implement age progression infrastructure (Dark → Feudal → Castle)

**AI Competency (cumulative):** By end of this phase, AI must do everything from Phases 0-3, plus: research age advancement when economically ready, respect age-gating for buildings/units.

**Sub-phases (approved 2026-02-06):**
- **4A**: Age infrastructure + advancement mechanic + AI advancement rules
- **4B**: Age-gating (lock buildings/units by age), UI for locked content, building visual changes

| Feature | Type | Sub-phase | Notes |
|---------|------|-----------|-------|
| Age state machine | System | 4A | Track current age per player |
| Dark Age | Age | 4A | Starting age, basic units/buildings |
| Feudal Age | Age | 4A | Cost: 500 food, requires 2 qualifying Dark Age buildings |
| Castle Age | Age | 4A | Cost: 800 food + 200 gold, requires 2 qualifying Feudal Age buildings |
| Age advancement UI | UI | 4A | Button at TC, progress bar, notification |
| AI age advancement | AI | 4A | AI researches ages when economically ready |
| Age-gating | System | 4B | Buildings/units locked until specific age |
| Locked content UI | UI | 4B | Greyed-out buttons with age requirement tooltip |
| Building visual changes | Visual | 4B | Buildings update appearance per age |

**Qualifying buildings for age advancement:**
- Buildings that train units or research techs (Barracks, Mill, Lumber Camp, Mining Camp, Dock, etc.)
- Does NOT count: Houses, Farms, Town Center, towers, walls, Gates, Outposts

**Age-gated content:**
- **Dark Age:** Villager, Militia, Barracks, House, Mill, Mining Camp, Lumber Camp, Farm, Outpost, Palisade Wall
- **Feudal Age:** Archery Range, Stable, Market, Blacksmith, Watch Tower, Stone Wall, Gate; Scout Cavalry (training; one free starting unit exists in Dark Age), Archer, Skirmisher, Spearman, Trade Cart
- **Castle Age:** Siege Workshop, Monastery, University, Castle, Town Center (additional); Knight, Cavalry Archer, Crossbowman, Pikeman, siege units

**AI updates:** AI researches age advancement when economically ready.

**Done when:** Games have distinct early-game (Dark Age eco), mid-game (Feudal military), late-game (Castle power).

---

### Phase 4A: Age Infrastructure + Advancement

| Feature | Type | Notes |
|---------|------|-------|
| Age constants & tracking | System | AGE_DARK/FEUDAL/CASTLE/IMPERIAL, per-player age vars, age_changed signal |
| Qualifying building logic | System | Count functional buildings by group to determine advancement eligibility |
| Age research at TC | Mechanic | Timer-based research, blocks villager training, can cancel |
| Advance Age button | UI | In TC panel, validates requirements, shows progress |
| Age label update | UI | Top bar updates with current age name |
| Age-up notification | UI | Notification when age research completes |
| AI age advancement rules | AI | AdvanceToFeudalAgeRule, AdvanceToCastleAgeRule |
| AI age observability | AI | Skip reasons, milestones, AI_STATE logging |

**4A Done when:** Player and AI can advance through ages. UI shows progress. AI advances when economically ready.

---

### Phase 4B: Age-Gating + Visual Changes

| Feature | Type | Notes |
|---------|------|-------|
| Building age-gating | System | Buildings locked until specific age |
| Unit age-gating | System | Units locked until specific age |
| Greyed-out UI | UI | Locked buttons show age requirement |
| Building visual upgrades | Visual | Buildings change appearance per age |
| AI respects age-gating | AI | AI only builds/trains age-appropriate content |

**4B Done when:** Age advancement creates meaningful progression. Content is locked/unlocked correctly.

---

## Phase 5: Tech Research & Upgrades
**Goal:** Full technology and unit upgrade system

**Sub-phases (approved 2026-02-07):**
- **5A**: Tech research system + Blacksmith building + Loom at TC + Feudal/Castle Blacksmith techs + AI rules + observability
- **5B**: Unit upgrade system + Knight (new unit) + Castle-and-below unit upgrades + AI upgrade rules

Imperial techs and upgrades deferred to Phase 9.

### Phase 5A: Tech Research System + Blacksmith + Loom

| Feature | Type | Notes |
|---------|------|-------|
| Generic research system | System | Reusable research logic in Building base class |
| Tech definitions | System | TECHNOLOGIES dict in GameManager with per-team state |
| Tech effect system | System | Per-team bonuses applied to units via signal |
| Blacksmith | Building | 150W, 2100HP, Feudal Age, researches attack/armor techs |
| Loom | Tech | +15 villager HP, +1/+1 armor (TC, Dark Age, 50G) |
| Blacksmith techs (Feudal) | Tech | Forging, Scale Mail, Scale Barding, Fletching, Padded Archer |
| Blacksmith techs (Castle) | Tech | Iron Casting, Chain Mail, Chain Barding, Bodkin Arrow, Leather Archer |
| Blacksmith HUD panel | UI | Tech buttons, research progress, build button |
| Loom button | UI | In TC panel, shows research progress |
| AI BuildBlacksmithRule | AI | Build after barracks + 2 military |
| AI ResearchBlacksmithTechRule | AI | Pick best tech based on army composition |
| AI ResearchLoomRule | AI | Research when gold available |

**5A Done when:** Blacksmith techs affect unit stats. AI researches techs. Loom works at TC.

### Phase 5B: Unit Upgrades + Knight

| Feature | Type | Notes |
|---------|------|-------|
| Unit upgrade system | System | Research at training building, transforms existing units in-place |
| Man-at-Arms | Upgrade | Feudal, 100F+40G, Barracks |
| Long Swordsman | Upgrade | Castle, 200F+65G, Barracks |
| Pikeman | Upgrade | Castle, 215F+90G, Barracks |
| Crossbowman | Upgrade | Castle, 125F+75G, Archery Range |
| Elite Skirmisher | Upgrade | Castle, 200W+100G, Archery Range |
| Heavy Cavalry Archer | Upgrade | Castle, 900F+500G, Archery Range |
| Light Cavalry | Upgrade | Castle, 150F+50G, Stable |
| Knight | Unit | Castle, 60F+75G, 100HP, 10atk, 2/2 armor, Stable |
| Upgrade buttons | UI | In Barracks/Archery Range/Stable panels |
| AI upgrade rules | AI | Research upgrades based on army composition |

**5B Done when:** Unit upgrades work for all Castle-and-below lines. Knight trainable. AI researches upgrades.

**Imperial content deferred to Phase 9:** Two-Handed Swordsman, Champion, Arbalester, Cavalier, Paladin, Blast Furnace, Plate Mail Armor, Plate Barding Armor, Bracer, Ring Archer Armor.

**Blacksmith Techs (Feudal + Castle):** See `docs/AoE_manual/AoE_manual.txt` for costs and effects

**AI updates:** AI researches upgrades based on army composition.

**Done when:** Tech tree is functional, upgrades affect gameplay significantly.

---

## Phase 6: Monks, Relics & Monastery
**Goal:** Add conversion mechanics and alternative victory/income

| Feature | Type | Notes |
|---------|------|-------|
| Monastery | Building | Trains monks, stores relics, Castle Age |
| Monk | Unit | Slow, heals friendly units, converts enemies |
| Conversion mechanic | Mechanic | Range 9, random success chance, rejuvenation time |
| Conversion adjacency | Mechanic | Monks must stand adjacent to buildings, rams, and Trebuchets to convert |
| Conversion immunity | Mechanic | Cannot convert: TC, Castle, Monastery, Farm, Fish Trap, walls, Gates, Wonder, allied units |
| Healing mechanic | Mechanic | Auto-heal nearby wounded friendlies; multiple monks heal faster |
| Relics | Object | Spawn on map (5 per game), only monks can carry |
| Relic garrisoning | Mechanic | Garrison in Monastery for +0.5 gold/sec |
| Relic victory | Victory | Control all relics for 200 years (game time) |
| Monk technologies | Tech | See `docs/AoE_manual/AoE_manual.txt` for costs and effects |

**AI updates:** AI trains monks, collects relics, attempts conversions on high-value targets.

**Done when:** Monks are viable tactical option. Relic control is strategic goal.

---

## Phase 7: Walls & Basic Defense
**Goal:** Positional play with walls and basic static defenses

| Feature | Type | Notes |
|---------|------|-------|
| Palisade Wall | Building | 2 wood, 250 HP, Dark Age |
| Stone Wall | Building | 5 stone, 1800 HP, Feudal Age |
| Gate | Building | 30 stone, passable wall segment, lockable, auto-opens for allies |
| Outpost | Building | 25W + 25S, 500 HP, long LOS, no attack, no garrison |
| Watch Tower | Building | 125S + 25W, 1020 HP, 5 attack, range 8 |
| Minimum range | Mechanic | Castles and towers cannot attack adjacent units (Murder Holes removes this) |
| Garrison (basic) | Mechanic | Units inside TC/towers for protection |
| Garrison attack bonus | Mechanic | Ranged units and villagers add arrows when garrisoned in TC/towers |
| Garrison healing | Mechanic | Garrisoned units heal automatically over time |
| Garrison ejection | Mechanic | Buildings auto-eject all garrisoned units when heavily damaged |
| Allied garrison | Mechanic | Allies can garrison in each other's buildings |
| Allied gates | Mechanic | Allies can open/close each other's gates |
| Town Bell | Mechanic | Garrison all villagers in nearest buildings |
| Wall dragging | Input | Click and drag to place wall segments |

**Garrison capacity:**
- Town Center: 15 foot units
- Watch Tower: 5 foot units
- Castle: 20 units (Phase 8)
- Barracks: 10 units (own unit types)
- Archery Range: 10 units (own unit types)
- Stable: 10 units (own unit types)
- Siege Workshop: 10 siege units
- Dock: 10 ships
- Monastery: 10 monks

**AI updates:** AI builds walls around base, uses towers at chokepoints.

**Done when:** Defensive play is viable. Walls create meaningful map control.

---

## Phase 8: Advanced Defense & Siege
**Goal:** Siege warfare breaks defensive positions

| Feature | Type | Notes |
|---------|------|-------|
| University | Building | Building/tower/siege techs, Castle Age |
| Guard Tower | Building | Watch Tower upgrade, 1500 HP, 6 attack |
| Fortified Wall | Building | Stone Wall upgrade, 3000 HP |
| Siege Workshop | Building | Builds siege units, Castle Age |
| Battering Ram | Unit | 175 HP, bonus vs buildings, weak to infantry |
| Capped Ram | Unit | Ram upgrade, 200 HP |
| Mangonel | Unit | Area damage, 50 HP, counters massed units |
| Onager | Unit | Mangonel upgrade, 60 HP, more damage |
| Scorpion | Unit | Bolt damage, hits all units in line |
| Heavy Scorpion | Unit | Scorpion upgrade |
| Garrison (advanced) | Mechanic | Siege units garrison in rams for protection |

**University Techs:** See `docs/AoE_manual/AoE_manual.txt` for costs and effects

**AI updates:** AI builds siege to break player walls, protects siege with infantry.

**Done when:** Turtling is viable but counterable. Siege breaks stalemates.

---

## Phase 9: Imperial Age & Advanced
**Goal:** Complete age system with late-game power units and deferred Imperial upgrades

| Feature | Type | Notes |
|---------|------|-------|
| Imperial Age | Age | Cost: 1000F + 800G, requires 2 Castle Age buildings |
| Castle | Building | 650 stone, unique units, Trebuchets, 4800 HP |
| Trebuchet | Unit | Long-range (16), pack/unpack, anti-building |
| Bombard Cannon | Unit | 225W + 225G, requires Chemistry |
| Siege Ram | Unit | Capped Ram upgrade, 270 HP |
| Siege Onager | Unit | Onager upgrade, 75 damage, cuts forests |
| Forest cutting | Mechanic | Siege Onagers and Trebuchets can cut paths through forests |
| Keep | Building | Guard Tower upgrade, 2250 HP, 7 attack |
| Bombard Tower | Building | 125S + 100G, requires Chemistry, 120 attack |
| Wonder | Building | 1000W + 1000S + 1000G, 4800 HP |
| Wonder victory | Victory | Wonder stands for 200 years |
| Chemistry | Tech | Enables gunpowder units, +1 missile attack |
| Camel | Unit | Anti-cavalry cavalry, 100 HP, bonus vs mounted |
| Heavy Camel | Unit | Camel upgrade, 120 HP |
| Hand Cannoneer | Unit | Gunpowder archer, 17 attack, inaccurate |
| Two-Handed Swordsman | Upgrade | Imperial, 300F+100G, Barracks (deferred from Phase 5) |
| Champion | Upgrade | Imperial, 750F+350G, Barracks (deferred from Phase 5) |
| Arbalester | Upgrade | Imperial, 350F+300G, Archery Range (deferred from Phase 5) |
| Cavalier | Upgrade | Imperial, 300F+300G, Stable (deferred from Phase 5) |
| Paladin | Upgrade | Imperial, 1300F+750G, Stable (deferred from Phase 5) |
| Blast Furnace | Tech | Imperial Blacksmith tech (deferred from Phase 5) |
| Plate Mail Armor | Tech | Imperial Blacksmith tech (deferred from Phase 5) |
| Plate Barding Armor | Tech | Imperial Blacksmith tech (deferred from Phase 5) |
| Bracer | Tech | Imperial Blacksmith tech (deferred from Phase 5) |
| Ring Archer Armor | Tech | Imperial Blacksmith tech (deferred from Phase 5) |

**AI updates:** AI advances to Imperial, builds Castle, uses Trebuchets, builds Wonder if ahead.

**Done when:** Full 4-age progression. Late-game feels powerful and distinct.

---

## Phase 10: Polish & UX
**Goal:** Quality of life improvements for playability

| Feature | Type | Notes |
|---------|------|-------|
| Save/Load system | System | Save and restore single-player games |
| Minimap modes | UI | Normal, Combat (military), Economic (resources) - basic minimap in 2.6 |
| Control groups | Input | Ctrl+1-9 to save, 1-9 to recall selections |
| Double-click selection | Input | Select all visible units of same type |
| Unit queuing | Mechanic | Shift+right-click for waypoints |
| Rally points | Mechanic | Set gather point for trained units |
| Formations | Mechanic | Line, Box, Staggered, Flank |
| Auto-formation | Mechanic | Mixed groups auto-position: high HP front, ranged back, weak rear |
| Formation speed | Mechanic | Groups move at slowest unit's speed |
| Patrol command | Mechanic | Units patrol between points, attack enemies in sight |
| Guard command | Mechanic | Units follow and protect target |
| Follow command | Mechanic | Units follow allied or enemy unit |
| Idle villager button | UI | Cycle through idle villagers, ships, trade units |
| Idle military button | UI | Cycle through idle military |
| Shift-click building | Input | Hold SHIFT to place multiple of same building type |
| Farm auto-rebuild | Mechanic | Right-click expired farm to queue automatic rebuild |
| Building damage visuals | Art | Buildings flame when damaged |
| In-game tech tree | UI | View full technology tree during game |
| Visual upgrade | Art | Sprites, animations |
| Sound effects | Audio | Feedback for actions, combat, UI |
| Larger maps | Map | 120x120, 200x200 options |
| Multiple map types | Map | Arabia, Black Forest, Rivers, Archipelago, etc. (14 types) |
| Hotkey customization | UI | Rebindable hotkeys saved to user profile |
| Signal allies | UI | Visual/audio ping on minimap for AI team communication |
| Observer mode | UI | "All Visible" option to watch AI play without fog of war |
| Tooltips/Help | UI | Contextual tooltips for buildings, units, and techs |
| Unit visibility | Render | Units remain visible behind buildings and trees |

**Done when:** Game feels responsive and professional.

---

## Phase 11: Naval Economy (Optional)
**Goal:** Water-based economic gameplay

| Feature | Type | Notes |
|---------|------|-------|
| Dock | Building | 150W, trains ships, drop-off for fish |
| Fishing Ship | Unit | 75W, gathers fish, builds Fish Traps |
| Fish (deep water) | Resource | Food source, requires Fishing Ship |
| Fish Trap | Building | 100W, renewable food, built by Fishing Ship |
| Trade Cog | Unit | 100W + 50G, sea trade route |
| Transport Ship | Unit | 125W, carries land units across water (capacity limit shown in status) |
| Water terrain | Map | Deep water (ships only), shallows (passable by land AND ships) |
| Shore fishing | Mechanic | Villagers fish from shore |
| Allied transport | Mechanic | Allies can transport each other's units |

**AI updates:** AI builds Dock on water maps, uses fishing economy.

**Done when:** Water maps have economic viability.

---

## Phase 12: Naval Combat (Optional)
**Goal:** Naval warfare for water map control

| Feature | Type | Notes |
|---------|------|-------|
| Galley | Unit | 90W + 30G, basic warship, 6 attack |
| War Galley | Unit | Galley upgrade, 7 attack |
| Galleon | Unit | War Galley upgrade, 8 attack |
| Fire Ship | Unit | 75W + 45G, anti-ship, 2 attack |
| Fast Fire Ship | Unit | Fire Ship upgrade |
| Demolition Ship | Unit | 70W + 50G, suicide attack, 110 damage |
| Heavy Demolition Ship | Unit | Demo Ship upgrade, 140 damage |
| Cannon Galleon | Unit | 200W + 150G, long range, anti-building |
| Elite Cannon Galleon | Unit | Cannon Galleon upgrade |
| Water maps | Map | Islands, Archipelago, Coastal, Baltic, etc. |

**Ship Techs:** Careening, Dry Dock, Shipwright (see `docs/AoE_manual/AoE_manual.txt`)

**AI updates:** AI builds navy on water maps, controls sea.

**Done when:** Naval combat is balanced and fun.

---

## Phase 13: Civilizations (Optional)
**Goal:** Asymmetric gameplay through civilization bonuses

| Feature | Type | Notes |
|---------|------|-------|
| Civilization selection | UI | Pre-game civ picker |
| 13 civilizations | Content | Britons, Byzantines, Celts, Chinese, Franks, Goths, Japanese, Mongols, Persians, Saracens, Teutons, Turks, Vikings |
| Civ bonuses | Balance | 2-4 unique bonuses per civ |
| Unique units | Units | One per civ, trained at Castle |
| Tech tree variations | System | Some civs lack certain techs |
| Team bonuses | Balance | Shared bonus with allies |

**Unique Units:**
| Civ | Unit | Type | Special |
|-----|------|------|---------|
| Britons | Longbowman | Archer | +1 range |
| Byzantines | Cataphract | Cavalry | Bonus vs infantry |
| Celts | Woad Raider | Infantry | Very fast |
| Chinese | Chu Ko Nu | Archer | Fires multiple bolts |
| Franks | Throwing Axeman | Infantry | Ranged attack |
| Goths | Huskarl | Infantry | High pierce armor |
| Japanese | Samurai | Infantry | Bonus vs unique units |
| Mongols | Mangudai | Cav Archer | Bonus vs siege |
| Persians | War Elephant | Cavalry | Massive HP, slow |
| Saracens | Mameluke | Cavalry | Ranged, anti-cavalry |
| Teutons | Teutonic Knight | Infantry | Massive armor, slow |
| Turks | Janissary | Gunpowder | Long range Hand Cannoneer |
| Vikings | Berserk | Infantry | Regenerates HP |
| Vikings | Longboat | Ship | Fires multiple arrows |

**Done when:** Each civ feels distinct. Matchups create strategic variety.

---

## Phase 14: Team Games & Allied AI (Optional)
**Goal:** 1 human + AI allies vs AI enemies (team battles)

| Feature | Type | Notes |
|---------|------|-------|
| Multiple AI opponents | System | Support 2-8 total players (1 human + AI) |
| AI team assignment | System | Pregame setup: assign AI to player's team or enemy team |
| Team configuration | UI | Set teams, colors, starting positions |
| Lock teams | Setting | Prevent alliance changes mid-game, restrict tribute to allies only |
| Diplomacy | System | Ally/Neutral/Enemy stances per AI |
| Allied victory | Mechanic | Team wins together (all enemy TCs destroyed) |
| Allied repair | Mechanic | Repair ally buildings/ships/siege (costs from owner's stockpile) |
| Cartography sharing | Mechanic | Share exploration with allies (via tech) |
| Tribute to AI | Mechanic | Send resources to AI allies |
| AI allied behavior | AI | AI allies coordinate attacks, share intel, respond to threats |

**Game Modes:**
- Random Map (standard)
- Regicide (protect your King unit - add King as special unit)
- Death Match (start with large stockpiles)
- Score Victory (first to target score wins)
- Timed Victory (highest score after time limit)

**Note:** This phase focuses on single-player team games. Online human-vs-human multiplayer (networking, lobbies, chat) is out of scope.

**Done when:** Player can fight alongside AI allies against AI enemies in team configurations.

---

## Adding New Content

### New Building
1. Create `scripts/buildings/X.gd` extending Building
2. Create `scenes/buildings/X.tscn` (StaticBody2D, Sprite2D, CollisionShape2D)
3. Set collision_layer = 2
4. Add to group in _ready()
5. Add build button to hud.tscn and hud.gd
6. Add placement logic to main.gd
7. Update `_show_building_info()` in hud.gd

### New Unit
1. Create `scripts/units/X.gd` extending Unit
2. Create `scenes/units/X.tscn` (CharacterBody2D, Sprite2D, CollisionShape2D, NavigationAgent2D, SelectionIndicator)
3. Set collision_layer = 1
4. Add to group
5. Add training logic to building
6. Update info panel in hud.gd
