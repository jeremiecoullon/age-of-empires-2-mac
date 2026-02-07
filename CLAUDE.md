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

This is the canonical workflow for building phases. Each phase (or sub-phase) follows these steps.

### 1. Plan (in planning mode)

**Do not skip this step.** Use `EnterPlanMode` to explore the codebase and design the execution plan before writing any code.

**In planning mode, do the refactor check:**

1. **Read the phase spec** in `docs/roadmap.md` — What features are being added?
2. **Skim Phase N+1** — What's coming next? Will this phase's code need to change?
3. **Inspect the code you'll touch.** Ask:
   - Will adding these features require duplicating existing code?
   - Are there hardcoded values that need to become dynamic?
   - Is there a pattern emerging (3+ similar things) that should be extracted?
   - Will the current structure make Phase N+1 harder than it needs to be?
4. **Decide:** If refactor needed → include it in the plan before features.

**Then write the execution plan** to both the plan file AND `docs/plans/phase-{X}-plan.md` (identical content in both). This ensures the comprehensive plan survives into the build phase without information loss. (Note: plan files in `docs/plans/` exist from phase 4b onward — earlier phases predate this workflow.) The plan should contain:

1. **Refactoring identified** — what (if anything) needs refactoring first
2. **Ordered feature list** — specific files to create/modify, in implementation order
3. **Key implementation notes** — non-obvious gotchas, dependencies between features, patterns to follow
4. **Post-phase checklist** — the post-phase steps (from step 3 below) listed explicitly so they survive context compaction

Use `ExitPlanMode` to present the plan for user approval.

**Important:** You (the agent) determine what refactoring is needed based on the actual codebase. Use your judgment. YAGNI — only fix what will actually cause problems.

### 2. Build the phase

The plan is already in `docs/plans/phase-{X}-plan.md` (written during plan mode). This file is a **compaction-resistant checklist** — re-read it after any context compaction. Update it during implementation (mark completed items, add discovered work).

Implement:

1. **Implement features** per the execution plan. Details in `docs/AoE_manual/AoE_manual.txt`.
2. **Run spec-check agent** on new units/buildings/techs to verify against AoE2 specs.
3. **If phase adds features the AI should use:**
   - Add AI rules for the new features (in `scripts/ai/ai_rules.gd`)
   - Add observability so tests can track the new behavior:
     - Skip reasons in `ai_controller.gd` (explains why rules don't fire)
     - Milestones in `ai_test_analyzer.gd` for new buildings/units
     - Update `AI_STATE` logging if new counts are needed
4. **Consider unit tests** for logic-heavy code (stat calculations, combat formulas, state transitions). Not everything needs tests — UI and scene setup rarely benefit; game logic often does.

### 3. Post-phase

1. **Self-report on context friction** in the checkpoint doc:
   - Did I re-read any file more than twice? Which ones?
   - Did I forget earlier decisions and have to correct myself?
   - Are there patterns I'm not confident are consistent?

2. **Run code-reviewer agent.** Review suggestions critically — apply what's useful, skip what's not.

3. **Run test agent** to write automated tests. After it returns, YOU must update the checkpoint doc's "Test Coverage" section with what was tested.

4. **Run ai-observer agent** if the phase affects AI behavior (modified `scripts/ai/`, added buildings/units/techs, added mechanics AI should use). Add results to checkpoint doc's "AI Behavior Tests" section.

5. **Update `docs/gotchas.md`** — REQUIRED. Add a section for the phase documenting:
   - Patterns that worked or didn't
   - Non-obvious implementation details
   - Bugs encountered and fixes

6. **Write checkpoint doc** in `docs/phase_checkpoints/` using the template.

7. **Verify** game still launches and plays correctly.

---

## Sub-phases

Phases can be split into sub-phases (e.g., 1.0a, 1.0b, 1.0c) if needed. Each sub-phase follows the full workflow above including its own checkpoint doc.

**One sub-phase per context window.** Complete one sub-phase, do the full post-phase ceremony, then signal for context clear. Never start the next sub-phase in the same context — context rot makes later sub-phases error-prone.

**Checkpoint naming:** Always use `phase-X.Ya.md` format (e.g., `phase-2.0a.md`, `phase-2.5b.md`). The `.0` is required for major phases so files sort correctly.

**Sub-phase sizing:** Each sub-phase should be a coherent chunk — 3-5 related features, or 1-2 new systems with their dependent content. Too small = ceremony overhead. Too large = context rot.

**Orchestrating a full phase:** When the user says "do all of phase X":

1. **Propose a split.** Read the phase spec, propose sub-phases (e.g., 2.0A, 2.0B, 2.0C). Explain what each covers. Get user approval once upfront.

2. **Persist the split.** Update `docs/roadmap.md` with the sub-phase breakdown. This is the source of truth for future sessions. Sub-phase descriptions must include both **entities** (units, buildings) AND **systems** (mechanics being introduced).

3. **Execute the next sub-phase only.** Run the full Phase Workflow (plan → build → post-phase) for one sub-phase.

4. **Signal for context clear.** Say: "4.0A complete. Clear context now."

5. **Repeat from step 3.** When user clears context and says "continue", read the breakdown in `roadmap.md` and checkpoint docs to determine which sub-phase is next, then go back to step 3.

After the initial split approval, Claude executes autonomously. The only user actions needed are context clears and "continue".

---

## Code Review

Run the code-reviewer agent after completing work (phases, tests, bug fixes, refactoring). Review suggestions critically — apply what's useful, skip what's not.

**For non-phase work** (tests, bug fixes): You don't need the full phase ceremony (refactor check, checkpoint docs). Just do the work, then run code review.

---

## Test Agent

The test agent writes automated tests for phase features. It receives the checkpoint doc + relevant source files, writes tests, and returns a summary.

**IMPORTANT:** After the test agent returns, YOU must update the checkpoint doc's "Test Coverage" section with what was tested.

**Writing tests manually:** When writing tests yourself (not via test agent), still run code review afterward.

---

## AI Behavior Testing

The ai-observer agent runs headless AI tests and analyzes behavior. It:
1. Runs a 600 game-second test at 10x speed
2. Reads structured output (`summary.json`) for pass/fail and milestones
3. On failure, analyzes verbose logs to identify root causes
4. Returns a report with findings and recommendations

This is different from unit tests: unit tests verify code correctness (deterministic, fast), AI behavior tests verify the AI plays competently (game-level outcomes, stochastic, slower).

**Optional focus areas:** You can ask the agent to focus on specific aspects (e.g., "focus on economy", "check military production", "analyze first 3 minutes").

See `docs/ai_player_designs/ai_testing.md` for full documentation of the test infrastructure.

---

## Spec Verification

The spec-check agent verifies implementations against the AoE2 manual (`docs/AoE_manual/AoE_manual.txt`). It returns a comparison table showing mismatches.

Fix any mismatches, or document intentional deviations in `docs/gotchas.md`.

---

## Running Tests

**Always run tests in two steps:**

1. **Validate project import** (catches .tscn/.tres syntax errors):
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .
   ```

2. **Run the test suite**:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/test_scene.tscn
   ```

Both steps are required. The import step catches scene file errors that won't show up in tests (since tests use mock HUD).

Tests auto-quit when complete. Exit code 0 = all passed, 1 = failures. Do not ask the user to run tests manually in the GUI.

--- 

## Improving the AI player

Games are logged to `logs/game_logs/` with snapshots every 10 seconds. When the user asks to analyze a game:

1. **Run the game-analyzer agent** on the game log directory the user specifies. It identifies the biggest strategic gap and proposes a concrete code change. The report goes to `analysis.md` inside that game log folder.
2. **Critically assess the recommendation.** Don't blindly accept — check whether the proposed change makes sense given current AI logic and game state.
3. **Wait for user confirmation** before implementing anything.
4. **Implement the fix**, then run the code-reviewer agent on the changes.
5. **Update the AI tuning log** in `docs/ai_player_designs/ai_tuning_log.md` to track what changed and why. This history matters as new features/maps are added — earlier tuning may become irrelevant.



---

## Sprites & Assets

**When creating new buildings/units without available sprites:**

1. **Never use another entity's sprite as a fallback.** Don't use the barracks sprite for a stable, or militia sprite for an archer. This causes confusion and visual bugs.

2. **Create an SVG placeholder instead.** SVGs are simple XML that Godot imports natively. Create a basic colored rectangle/shape with text indicating what it represents. See `assets/sprites/buildings/farm.svg` or `market.svg` for examples.

3. **Document the missing sprite** in `docs/gotchas.md` under the "Missing Sprites" section. This ensures Phase 9 (Polish) knows what to replace.

See `docs/gotchas.md` "Missing Sprites" table for the full list of SVG placeholders. Units/buildings not in that table have AoE sprites.

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
