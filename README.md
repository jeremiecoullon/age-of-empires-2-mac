# Age of Empires 2 Clone

A clone of Age of Empires 2 built in Godot 4.x. The goal is to faithfully reproduce the original game as defined by the AoE2 manual - all units, buildings, ages, and mechanics.

**Current status:** MVP complete. Player vs AI combat works with basic economy (wood, food), militia units, and conquest victory. See `docs/roadmap.md` for the full 10-phase plan.

## Quick Start

1. Open project in Godot 4.x
2. Press F5 to play
3. Destroy the enemy Town Center (red) to win

## Controls

- **WASD / Arrow keys**: Pan camera
- **Left-click**: Select unit or building
- **Left-click drag**: Box select multiple units
- **Right-click**: Move units / Attack enemy / Gather resource
- **Build buttons**: Enter placement mode, left-click to place, right-click to cancel

## Development

### AI Workflow

This project uses an orchestrator + sub-agent pattern with Claude Code.

**Orchestrator** (main session): Does not write game code directly. Coordinates sub-agents, verifies work, writes documentation.

**Sub-agents**: Implement specific features, return summaries.

### Phase Workflow

1. **Pre-flight** - Read `docs/gotchas.md`, verify game runs
2. **Plan** - Break phase into sub-tasks, create task files in `docs/tasks/phaseN/`
3. **Build** - Sub-agents implement tasks
4. **Review** - Code review
5. **Verify** - Compare implementation against spec
6. **Checkpoint** - Write summary to `docs/phase_checkpoints/`, update gotchas
7. **Clear context** - Artifacts persist for next session

### Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Instructions for Claude (read automatically) |
| `docs/gotchas.md` | Accumulated learnings |
| `docs/phase_checkpoints/` | Phase summaries |
| `docs/tasks/` | Sub-task files per phase |
| `docs/roadmap.md` | Full implementation plan |
