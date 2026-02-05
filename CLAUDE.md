# Age of Empires 2 Clone

> **FIRST STEPS — Read Before Doing Anything**
>
> 1. **Always read `README.md` first** to understand the project.
> 2. **If doing development work**, also read:
>    - `docs/phase_checkpoints/` — Latest checkpoint = current project state
>    - `docs/roadmap.md` — Architecture and phase details
>    - `docs/gotchas.md` — Known pitfalls to avoid
>
> This applies to every new session. Don't start coding until you've read these.
>
> **Ignore the archive:** `docs/phase_checkpoints/archive/` contains replaced implementations. Do not read or reference these unless explicitly asked.

---

## Git Policy

**Never perform git operations.** No commits, no pushes, no branch operations. The user handles all git manually.

---

## Spec Verification

**Always verify implementations against the AoE2 manual.**

After implementing or modifying any unit, building, or technology:
1. Use the **spec-check agent** to verify implementation matches specs
2. Review the comparison table it returns
3. Fix any mismatches, or document intentional deviations in `docs/gotchas.md`

The spec-check agent searches `docs/AoE_manual/AoE_manual.txt` and compares against your implementation.

**Do not skip this step.** The goal is a faithful AoE2 clone, not "close enough."

---

## Project Context

Building an AoE2 clone in Godot 4.x. MVP complete (Tiers 1-3).

Key docs:
- `docs/roadmap.md` - Architecture, phased implementation plan, how to add content
- `docs/design_decisions.md` - High-level design choices and rationale (ADRs)
- `docs/gotchas.md` - Accumulated learnings and pitfalls
- `docs/AoE_manual/` - Reference specs from original game

**gotchas.md vs design_decisions.md:**
- `gotchas.md` = Implementation lessons ("X doesn't work because Y", "remember to do Z")
- `design_decisions.md` = Strategic choices ("we chose A over B because...")

When you make a significant design choice (scope, architecture, tradeoffs), add it to `design_decisions.md`.

---

## Phase Workflow

**For the full phase workflow (refactor check, build, post-phase), see `docs/roadmap.md` → "Phase Workflow" section.**

**Sub-phases:** Phases can be split into sub-phases (e.g., 1.0a, 1.0b, 1.0c) if needed. Each sub-phase follows the full workflow including its own checkpoint doc.

**Checkpoint naming:** Always use `phase-X.Ya.md` format (e.g., `phase-2.0a.md`, `phase-2.5b.md`). The `.0` is required for major phases so that files sort correctly (otherwise `phase-2.5a` sorts before `phase-2a`).

**Sub-phase sizing:** Each sub-phase should be a coherent chunk - related features that touch the same systems. Too small and you spend more time on ceremony than code. Too large and you get context rot anyway. A good heuristic: 3-5 related features, or 1-2 new systems with their dependent content.

**Orchestrating a full phase:** When the user says "do all of phase X" or "complete phase X":

1. **Propose a split.** Read the phase spec in `docs/roadmap.md`, analyze the scope, and propose sub-phases (e.g., 2.0A, 2.0B, 2.0C). Explain what each sub-phase covers and why. Get user approval once upfront.

2. **Persist the split.** After approval, update `docs/roadmap.md` with the sub-phase breakdown under that phase's section. Add a "Sub-phases" block with date and brief description of each sub-phase. This is the source of truth for future sessions.

   **Sub-phase descriptions must include both entities AND systems.** Don't just list units/buildings—also list any new mechanics or systems being introduced (e.g., "armor system", "fog of war", "stance system"). If a previous checkpoint deferred something to this phase, it should appear in the description.

3. **Execute sub-phase.** Do the full workflow for the current sub-phase:
   - Refactor check
   - Build features
   - Run spec-check on new units/buildings/techs
   - Run code-reviewer agent
   - Run test agent
   - Write checkpoint doc

4. **Signal for context clear.** Say: "2.0A complete. Clear context now." (Claude cannot clear its own context.)

5. **Continue automatically.** When user clears context and says "continue", read the sub-phase breakdown in `roadmap.md` and checkpoint docs to see what's done, then immediately continue with the next sub-phase. No re-proposing, no asking permission - just execute.

After the initial split approval, Claude executes autonomously. The only user actions needed are context clears and saying "continue".

---

## Code Review

**Always run the code-reviewer agent after completing work.** This includes:
- Phases and sub-phases
- Writing or modifying tests
- Bug fixes
- Refactoring

Review the suggestions critically - apply what's useful, skip what's not.

Note: For non-phase work (tests, bug fixes), you don't need the full phase ceremony (refactor check, checkpoint docs). Just do the work, then run code review.

---

## Test Agent

**After code review, run the test agent to write automated tests for the phase.**

The test agent:
1. Receives the checkpoint doc + relevant source files
2. Writes tests for the phase's features
3. Returns a brief summary of what was tested

**IMPORTANT: After the test agent returns, you MUST update the checkpoint doc.** Add the test summary to the "Test Coverage → Automated Tests" section (list test files and what they cover). This step is YOUR responsibility, not the test agent's. The checkpoint is how future sessions know what's tested.

See `docs/roadmap.md` → "Post-Phase" for the full workflow.

**Writing tests manually:** When writing or modifying tests yourself (not via test agent), still run code review afterward per the Code Review section above.

---

## AI Behavior Testing

**After modifying AI logic or game features that affect AI behavior, run the ai-observer agent.**

The ai-observer agent:
1. Runs a headless AI test (600 game-seconds at 10x speed)
2. Reads structured output (`summary.json`) for pass/fail and milestones
3. On failure, analyzes verbose logs to identify root causes
4. Returns a report with findings and recommendations

This is different from unit tests: unit tests verify code correctness (deterministic, fast), AI behavior tests verify the AI plays competently (game-level outcomes, stochastic, slower).

**When to run:**
- After modifying `scripts/ai/` files
- After adding game features the AI should use (new buildings, units, techs)
- When debugging AI behavior issues

**Optional focus areas:** You can ask the agent to focus on specific aspects (e.g., "focus on economy", "check military production", "analyze first 3 minutes").

See `docs/ai_player_designs/ai_testing.md` for full documentation of the test infrastructure.

---

## Running Tests

**Always run tests in two steps:**

1. **Validate project import** (catches .tscn/.tres syntax errors):
   ```bash
   godot --headless --import --path .
   ```

2. **Run the test suite**:
   ```bash
   godot --headless --path . tests/test_scene.tscn
   ```

Both steps are required. The import step catches scene file errors that won't show up in tests (since tests use mock HUD).

Tests auto-quit when complete. Exit code 0 = all passed, 1 = failures. Do not ask the user to run tests manually in the GUI.

---

## Sprites & Assets

**When creating new buildings/units without available sprites:**

1. **Never use another entity's sprite as a fallback.** Don't use the barracks sprite for a stable, or militia sprite for an archer. This causes confusion and visual bugs.

2. **Create an SVG placeholder instead.** SVGs are simple XML that Godot imports natively. Create a basic colored rectangle/shape with text indicating what it represents. See `assets/sprites/buildings/farm.svg` or `market.svg` for examples.

3. **Document the missing sprite** in `docs/gotchas.md` under the "Missing Sprites" section. This ensures Phase 9 (Polish) knows what to replace.

Existing SVG placeholders: farm, market. All other buildings/units have AoE sprites.

---

## Project Conventions

- All game state goes through GameManager (autoload singleton)
- Units extend `scripts/units/unit.gd`
- Buildings extend `scripts/buildings/building.gd`
- AI logic lives in `scripts/ai/ai_controller.gd`
- New units/buildings must be added to appropriate groups
- Collision layers: 1=Units, 2=Buildings, 4=Resources

---

## Godot Shortcuts (Mac vs Windows/Linux)

| Action | Mac | Windows/Linux |
|--------|-----|---------------|
| Run project | Cmd+B | F5 |
| Run current scene | Cmd+R | F6 |
| Stop | Cmd+. | F8 |

The toolbar buttons (top-right) work identically on all platforms.
