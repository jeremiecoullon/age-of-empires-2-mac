# Age of Empires 2 Clone

A clone of Age of Empires 2 built in Godot 4.x. The goal is to faithfully reproduce the original game as defined by the AoE2 manual.

**Current status:** MVP complete. Player vs AI combat works with basic economy (wood, food), militia units, and conquest victory. See `docs/roadmap.md` for the full implementation plan.

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

## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Instructions for Claude |
| `docs/roadmap.md` | Architecture and implementation plan |
| `docs/gotchas.md` | Accumulated learnings |
| `docs/design_decisions.md` | Key design choices |
