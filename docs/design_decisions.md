# Design Decisions

This document records key design decisions for the AoE2 clone project, including context and rationale. Decisions are listed in reverse chronological order (newest first).

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
