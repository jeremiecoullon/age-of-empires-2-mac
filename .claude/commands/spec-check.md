# Spec Check

Spawn a Haiku sub-agent to verify implementation matches AoE2 specs.

**Feature to check:** $ARGUMENTS

## Instructions

Use the Task tool to spawn a sub-agent with these parameters:
- `model`: haiku
- `subagent_type`: general-purpose
- `description`: Spec check $ARGUMENTS

Include this prompt for the sub-agent:

---

**Task:** Check if the implementation of "$ARGUMENTS" matches the Age of Empires 2 manual specs.

**Steps:**

1. **Find the spec in the manual**
   - Search `docs/AoE_manual/AoE_manual.txt` for "$ARGUMENTS"
   - For units, check "Unit Attributes" appendix (around line 3750+)
   - For buildings, check "Building Attributes" appendix (around line 3714+)
   - For technologies, check "Technology Costs & Benefits" (around line 3854+)
   - Extract: HP, attack, armor, cost, range, speed, special abilities

2. **Find the implementation**
   - Units: `scripts/units/` directory
   - Buildings: `scripts/buildings/` directory
   - Search for the relevant .gd file and extract values

3. **Return a comparison table**

   | Attribute | AoE2 Spec | Implementation | Match? |
   |-----------|-----------|----------------|--------|
   | HP        | ?         | ?              | ?      |
   | Attack    | ?         | ?              | ?      |
   | Cost      | ?         | ?              | ?      |
   | ...       | ...       | ...            | ...    |

4. **Summary**
   - List mismatches
   - Note missing features
   - Note intentional deviations if apparent

Be concise. Just the table and a brief summary.

---

After receiving the sub-agent's result, display it to the user.
