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
| `CLAUDE.md` | **How to build** — Phase workflow, when to run agents, policies (git, sprites), project conventions |
| `docs/roadmap.md` | **What to build** — Phase specs, architecture, unit/building stats, adding new content |
| `docs/phase_checkpoints/` | **What was built** — One doc per phase summarizing features, files changed, context for next phase |
| `docs/gotchas.md` | **What we learned** — Pitfalls and lessons per phase, implementation details to remember |
| `docs/design_decisions.md` | **Why we chose X** — ADRs for strategic choices (scope, architecture, tradeoffs) |
| `docs/ai_player_designs/ai_testing.md` | **AI testing** — How to run headless tests, output formats, pass/fail checks |

## To get started on development

**Before starting work:**

1. Check `docs/phase_checkpoints/` to see what's been done (latest checkpoint = current state).

2. Read `docs/roadmap.md` to understand the next phase's spec.

3. Read `CLAUDE.md` for the phase workflow (refactor check → build → post-phase).

4. Read `docs/gotchas.md` to avoid known pitfalls.


## Running Tests

```bash
# Step 1: Validate project imports correctly
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .

# Step 2: Run test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/test_scene.tscn
```

Exit code 0 = all passed, 1 = failures.

---

# Contributing (For humans, not LLMs)

This section is for human contributors. If you're an LLM, read the rest of the readme above.

## Our approach

We don't write game code directly. Our goal is rather to make Claude Code more effective at building the actual game.

We do this by building processes in `CLAUDE.md` and `roadmap.md` (in the "key files" above) and setting up sub-agents (see the `.claude/agents/` folder). 



## Ways to contribute

**1. Continue the roadmap**

Pick up where development left off by prompting Claude Code in the following way:

> "Read the README and the related development files, and continue with the next phase from the roadmap."

Claude will read the context, understand the current state, and execute the next phase following the established workflow:

- Read phase spec and skim next phase for context
- Check if refactoring is needed before building
- Implement features, running spec-check on new units/buildings/techs
- Run code-reviewer agent and apply relevant suggestions
- Run test agent to write automated tests
- Write checkpoint doc summarizing what was built

**2. Find game assets (visual, music..)**

To clone AoE2 we need the sprites, background images, music, & SFX of the original game. We need to find these online, process them, and add them to the game. See the issues in the [issue tracker](../../issues) for details

**3. Improve the workflow**

Help refine how development happens:
- Modify `CLAUDE.md` or the sub-agents to improve the process
- Improve the `roadmap.md`. The roadmap was built to accurately reflect the AoE2 manual in `docs/AoE_manual/Age_of_Empires_2_The_Age_of_Kings_Manual_Win_EN.pdf` (as represented by the sibling .txt file), but there might be some things missing. There might also be important spects that aren't in the AoE2 manual at all.

**4. Play the game & report bugs**

Play the game and report any bugs you find in the [issue tracker](../../issues). You can list multiple bugs in a single issue — they'll be triaged with Claude Code. Even better: open a PR to fix them!

**5. Improve the AI**

Play against the AI, then use Claude Code to analyze and improve its behavior. The workflow:

1. **Play a game.** Games are automatically logged to `logs/game_logs/` with snapshots of both players' state every 10 seconds.
2. **Run the game analyzer agent.** Ask Claude Code: `"Run the game analyzer on game_<timestamp>"`. It reads the log, identifies the biggest strategic gap between you and the AI, and proposes a concrete code change.
3. **Review the analysis.** Read the proposed fix and decide if it makes sense. The analyzer writes its report to `analysis.md` inside the game log folder.
4. **Implement the fix.** If you agree with the proposal, ask Claude Code to implement it as well as run the code-review agent on the changes. It will make the code change and run the test suite.
5. **Replay and iterate.** Play another game to see if the fix helped. Run the analyzer again to measure improvement and find the next bottleneck.

The tuning history lives in `docs/ai_player_designs/ai_tuning_log.md` — read this first to see what's already been tried and what the current known issues are.
