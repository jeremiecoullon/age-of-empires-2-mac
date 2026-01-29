# Age of Empires 2 Clone

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

**Sub-phases:** Phases can be split into sub-phases (e.g., 1a, 1b, 1c) if needed. Each sub-phase follows the full workflow including its own checkpoint doc.

**Sub-phase sizing:** Each sub-phase should be a coherent chunk - related features that touch the same systems. Too small and you spend more time on ceremony than code. Too large and you get context rot anyway. A good heuristic: 3-5 related features, or 1-2 new systems with their dependent content.

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

## Running Tests

**Always run tests in headless mode.** Do not ask the user to run tests manually in the GUI.

```bash
godot --headless --path . tests/test_scene.tscn
```

Tests auto-quit when complete. Exit code 0 = all passed, 1 = failures.

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
