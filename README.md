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
4. Click the Play button (top-right) or use keyboard shortcut
   - Mac: Cmd+B
   - Windows/Linux: F5
5. Destroy the enemy Town Center (red) to win

## Controls

- **WASD / Arrow keys**: Pan camera
- **Left-click**: Select unit or building
- **Left-click drag**: Box select multiple units
- **Right-click**: Move units / Attack enemy / Gather resource
- **Build buttons**: Enter placement mode, left-click to place, right-click to cancel

# Development


## Key Files

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Instructions for Claude |
| `docs/roadmap.md` | Architecture and implementation plan |
| `docs/gotchas.md` | Accumulated learnings |
| `docs/design_decisions.md` | Key design choices |

## To get started on development

**Before starting work:**

1. Check `docs/phase_checkpoints/` to see what's been done. Each completed phase has a checkpoint doc summarizing what was built, files changed, and context for the next phase.

2. Read `docs/roadmap.md` to understand the next phase. Follow the Phase Workflow section (refactor check → build → post-phase).

3. Read `docs/gotchas.md` to avoid known pitfalls.


## Running Tests

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/test_scene.tscn 2>&1
```

Exit code 0 = all passed, 1 = failures.

---

## Contributing (For Humans, Not LLMs)

This section is for human contributors. If you're an LLM, see `CLAUDE.md` instead.

### Our Approach

We don't write game code directly. Instead, we improve the process and context that enables Claude Code to write the game. Think of it as "prompt engineering at scale" — we maintain documentation, define phases, track decisions, and curate assets. Claude does the implementation.

### Ways to Contribute

**1. Continue the Roadmap**

Pick up where development left off. Check `docs/phase_checkpoints/` for the latest completed phase, then prompt Claude Code to continue:

> "Read the README and CLAUDE.md, check the phase checkpoints to see what's done, and continue with the next phase from the roadmap."

Claude will read the context, understand the current state, and execute the next phase following the established workflow.

**2. Work on Issues (Visuals & Assets)**

Check the [issue tracker](../../issues) for tasks that need human curation — primarily finding and adding:
- Sprites for units/buildings
- Music and sound effects
- Other visual assets

These tasks require human judgment to find appropriate assets that match AoE2's style.

**3. Improve the Workflow**

Help refine how development happens:
- Improve documentation structure
- Add to `docs/gotchas.md` when you discover pitfalls
- Suggest better phase breakdowns in `docs/roadmap.md`
- Enhance the code review or testing process
- Track and triage bug reports

The meta-game is making Claude more effective at building the actual game.