# Design Decisions

This document records key design decisions for the AoE2 clone project, including context and rationale. Decisions are listed in reverse chronological order (newest first).

---

## DD-006: Defer terrain elevation bonuses to Phase 9

**Date:** 2026-01-30
**Status:** Accepted

### Context

Phase 2 roadmap includes "Terrain bonuses: Units firing from elevation get attack bonus; units below get penalty." However, the current map system is a flat grass ColorRect with no elevation data.

### Options Considered

| Option | Description |
|--------|-------------|
| **A** | Implement elevation system now (tilemap with height layers, elevation detection) |
| **B** | Defer to Phase 9 (Polish) when map types are added |

### Decision

**Option B** - Defer terrain elevation bonuses to Phase 9.

### Rationale

1. **MVP map is flat**: No elevation exists. Would need to build terrain height system from scratch.

2. **Phase 9 adds map types**: Roadmap lists "Multiple map types" (Arabia, Black Forest, Rivers, etc.) in Phase 9. Elevation is better implemented alongside proper terrain variety.

3. **Combat triangle works without elevation**: The core Phase 2 goal (unit composition matters) is achievable without elevation bonuses. Archers vs skirmishers vs cavalry triangle provides tactical depth.

4. **Scope management**: Phase 2 already has significant new systems (ranged combat, cavalry, fog of war, stances, AI improvements). Adding terrain elevation would increase risk.

### Implications

- Phase 2 implements combat triangle, fog of war, stances without elevation
- Terrain elevation bonuses move to Phase 9 alongside map type system
- Document in Phase 2 checkpoint that elevation is deferred

---

## DD-005: Explicit building panels over generic abstraction

**Date:** 2026-01-28
**Status:** Accepted

### Context

During Phase 1E refactor check, the explore agent recommended creating a generic building action panel system in the HUD. Currently, TC and Barracks each have their own hardcoded panels (`tc_panel`, `barracks_panel`). The concern was that adding Market, Blacksmith, Monastery would lead to "panel explosion."

### Options Considered

| Option | Description |
|--------|-------------|
| **A** | Generic building panel system - buildings register actions dynamically |
| **B** | Explicit panels per building type - add `market_panel` like `barracks_panel` |

### Decision

**Option B** - Keep explicit panels per building type.

### Rationale

1. **AoE2 does this too**: The original game has distinct UI per building type. This isn't inherently bad design.

2. **Premature abstraction**: We have 2 panels now, adding a 3rd. The "right" abstraction isn't clear yet. Generalizing too early often creates more problems.

3. **Explicit is easier to understand**: `market_panel` with market-specific buttons is clearer than a generic system with dynamic registration.

4. **Can refactor later**: If we reach 5+ panels and see clear patterns, we can generalize then. The code isn't harder to refactor later.

### Implications

- Add `market_panel` directly to HUD (like `barracks_panel`)
- Future buildings (Blacksmith, Monastery) will get their own panels
- Revisit if panel count becomes unmanageable (Phase 4+)

---

## DD-004: Phase 1E scope - defer tribute and sheep herding

**Date:** 2026-01-28
**Status:** Accepted

### Context

Phase 1 roadmap includes several trading features. During Phase 1E planning, we needed to decide which features to implement now vs defer.

### Features Evaluated

| Feature | Decision |
|---------|----------|
| Market building | Include |
| Dynamic market pricing | Include |
| Trade Cart | Include |
| Trade distance scaling | Include |
| Tribute system (30% fee) | **Defer to Phase 13** |
| Sheep herding AI | **Defer** |

### Decision

Implement core trading (Market, Trade Cart, pricing). Defer tribute and sheep herding.

### Rationale

**Tribute system deferred:**
1. Tribute is for sending resources to other players
2. In 1v1 against AI, there's no one to tribute to (AI is enemy)
3. Only useful with allied AI (Phase 13: Team Games)
4. Implementing now would be untestable dead code

**Sheep herding AI deferred:**
1. Villagers auto-herding sheep to drop-off before killing is a nice-to-have optimization
2. Current hunting behavior works (villagers kill sheep, gather from carcass)
3. Low gameplay impact - can add as polish if requested
4. Not blocking any other features

### Implications

- Phase 1E focuses on: Market, Trade Cart, dynamic pricing, trade distance scaling
- Tribute system moves to Phase 13 (Team Games & Allied AI)
- Sheep herding remains in backlog, not scheduled

---

## DD-001: Single-player focus (no online multiplayer)

**Date:** 2026-01-27
**Status:** Accepted

### Context

The original AoE2 supports online multiplayer with networking, lobbies, chat, and game synchronization. During roadmap gap analysis, we needed to decide whether to include this.

### Options Considered

| Option | Description |
|--------|-------------|
| **A** | 1 human vs 1 AI (current MVP) |
| **B** | 1 human vs multiple AI enemies |
| **C** | 1 human + AI allies vs AI enemies (team games) |
| **D** | Full online multiplayer (human vs human) |

### Decision

**Option C** - Support team games with AI allies and enemies, but no online human-vs-human multiplayer.

### Rationale

1. **Complexity vs value**: Online multiplayer requires networking, latency handling, synchronization, lobbies, matchmaking, and anti-cheat. This is a significant engineering effort that doesn't improve the core gameplay loop.

2. **Scope management**: The goal is a faithful AoE2 clone for single-player enjoyment. Online multiplayer is a "different product" in terms of infrastructure requirements.

3. **Team games still valuable**: Option C captures the strategic depth of team compositions (allied AI coordination, tribute, shared victory) without networking complexity.

4. **Deferrable**: If the core game reaches completion and there's interest, multiplayer could be reconsidered. The architecture doesn't preclude it.

### Implications

- Phase 13 renamed from "Multiplayer" to "Team Games & Allied AI"
- Features removed from scope: networking layer, lobbies, chat, replay system, game speed sync
- Features kept: multiple AI, team assignment, allied mechanics, diplomacy, team victory
- Added to "Out of Scope" section in roadmap.md

---

## DD-002: Campaigns and editors out of scope

**Date:** 2026-01-27
**Status:** Accepted

### Context

The original AoE2 includes 5 historical campaigns (William Wallace, Joan of Arc, Saladin, Genghis Khan, Frederick Barbarossa), a scenario editor, and a campaign editor. These are significant features in the original game.

### Decision

Campaigns and editors are out of scope for this project.

### Rationale

1. **Content vs mechanics**: Campaigns are primarily content (scripted scenarios, voice acting, historical narratives). The clone focuses on reproducing game mechanics, not content.

2. **Editor complexity**: A full scenario editor with terrain painting, trigger systems, victory conditions, and AI scripting is a large project in itself.

3. **Diminishing returns**: The core gameplay experience (Random Map games against AI) doesn't require campaigns. Players who want AoE2 campaigns can play the original.

4. **Learning campaign alternative**: The William Wallace campaign serves as a tutorial. We can implement a simpler in-game tutorial if needed, without the full campaign infrastructure.

### Implications

- No campaign mode in the game
- No scenario/map editor
- No custom AI scripting (CPSB-style)
- Tutorial needs (if any) will be addressed through simpler means

---

## DD-003: Hero units deferred

**Date:** 2026-01-27
**Status:** Deferred

### Context

AoE2 includes Hero units - special named units that appear in campaigns and Regicide mode (the King). The gap analysis identified these as missing from the roadmap.

### Decision

Hero units are deferred. The King unit may be added if Regicide mode is implemented in Phase 13.

### Rationale

1. **Campaign dependency**: Most hero units (Joan of Arc, Genghis Khan, etc.) only appear in campaigns, which are out of scope.

2. **Regicide is optional**: The King unit is only needed for Regicide mode, which is listed as an optional game mode in Phase 13.

3. **Minimal unique mechanics**: Heroes are mostly regular units with special names and stats. If needed, they can be added without architectural changes.

### Implications

- No hero units in Phases 1-12
- King unit may be added in Phase 13 if Regicide mode is prioritized
- Other hero units remain out of scope unless campaigns are reconsidered

---

## Template for New Decisions

```markdown
## DD-XXX: [Short title]

**Date:** YYYY-MM-DD
**Status:** Proposed | Accepted | Deprecated | Superseded by DD-XXX

### Context

[What prompted this decision? What problem are we solving?]

### Options Considered

[List alternatives that were evaluated]

### Decision

[What we decided]

### Rationale

[Why we chose this option over others]

### Implications

[What changes as a result of this decision]
```
