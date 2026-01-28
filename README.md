# Age of Empires 2 Clone

A clone of Age of Empires 2 built in Godot 4.x. The goal is to faithfully reproduce the original game as defined by the AoE2 manual.

## Quick Start

1. Install Git LFS (assets are stored with LFS):
   ```bash
   brew install git-lfs
   git lfs install
   ```
2. Clone the repo (LFS assets download automatically)
3. Open project in Godot 4.x
4. Press F5 to play
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

## Development

**Before starting work:**

1. Check `docs/phase_checkpoints/` to see what's been done. Each completed phase has a checkpoint doc summarizing what was built, files changed, and context for the next phase.

2. Read `docs/roadmap.md` to understand the next phase. Follow the Phase Workflow section (refactor check → build → post-phase).

3. Read `docs/gotchas.md` to avoid known pitfalls.
