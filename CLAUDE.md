# Age of Empires 2 Clone

## Git Policy

**Never perform git operations.** No commits, no pushes, no branch operations. The user handles all git manually.

---

## Current Mode: DIRECT

**DIRECT mode** (current):
- Write code directly - no need to spawn sub-agents
- Skip task files - just do the work
- Still read `docs/gotchas.md` before starting work
- Still update `docs/gotchas.md` when you hit issues
- **Still write checkpoint docs** at end of phase (see Post-Phase in roadmap.md)

**ORCHESTRATOR mode** (switch to this when codebase grows large):
- Follow the full orchestrator workflow below
- Coordinate sub-agents instead of writing code directly
- Use task files and full checkpoint templates

*To switch modes: change DIRECT to ORCHESTRATOR above.*

---

## Spec Verification (Both Modes)

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

Both DIRECT and ORCHESTRATOR modes follow that workflow. The difference is *how* you execute the build step:

- **DIRECT mode:** Write code yourself
- **ORCHESTRATOR mode:** Coordinate sub-agents (see below)

---

## Orchestrator Mode Details

*Skip this section when in DIRECT mode.*

You are the **orchestrator**. You do not write game code directly. You coordinate sub-agents.

### How to Execute a Phase (Orchestrator)

1. Follow the Phase Workflow in `docs/roadmap.md` (refactor check, etc.)
2. Break the phase into sub-tasks
3. Create task files in `docs/tasks/phaseN/`
4. For each sub-task: spawn a sub-agent, verify results, commit
5. After phase completion: write checkpoint doc

### Sub-Agent Briefing

When spawning a sub-agent for a build task, include:

1. The task file content (objective, acceptance criteria)
2. Relevant context files (existing code patterns to follow)
3. The `docs/gotchas.md` content
4. Explicit instruction: "Implement this feature. Return a summary of what you built and file locations."

### Task File Format

```markdown
# Task: [Short Name]

## Objective
[What to build, 1-2 sentences]

## Context Files
- scripts/path/to/relevant.gd (why it's relevant)
- scripts/another/file.gd (why it's relevant)

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Notes
[Any gotchas or special considerations]

## Output
[Filled in by sub-agent after completion: what was built, file locations, any issues]
```

### Checkpoint Format

See `docs/phase_checkpoints/_template.md`

## Project Conventions

- All game state goes through GameManager (autoload singleton)
- Units extend `scripts/units/unit.gd`
- Buildings extend `scripts/buildings/building.gd`
- AI logic lives in `scripts/ai/ai_controller.gd`
- New units/buildings must be added to appropriate groups
- Collision layers: 1=Units, 2=Buildings, 4=Resources

## Current State

- MVP complete (villager, militia, TC, house, barracks, farm)
- Player vs AI with conquest victory
- Next: Phase 1 (Resource & Economy) or Phase 2 (Military Triangle) per docs/roadmap.md
