# Phase 4B plan: Age-gating + visual changes

## Steps

- [x] 0. Add free starting Scout Cavalry (player in main.tscn, AI in _spawn_starting_base, starting pop = 4)
- [x] 1. Add age requirement dictionaries + helpers to GameManager (BUILDING_AGE_REQUIREMENTS, UNIT_AGE_REQUIREMENTS, is_building_unlocked, is_unit_unlocked)
- [x] 2. Add age checks to AI game state (get_can_train_reason, get_can_build_reason)
- [x] 3. Add age-gated UI for build buttons (_update_build_button_states in _show_build_buttons)
- [x] 4. Add age-gated UI for train buttons (_update_train_button_states in _show_*_buttons)
- [x] 5. Add age safety checks to button press handlers
- [x] 6. Refresh UI on age change (_on_age_changed calls _refresh_current_panel)
- [x] 7. Document deferral in gotchas.md
- [x] 8. Fix AI military tests to set age before testing Feudal/Castle content (6 tests + 10 for correctness)

## Post-phase checklist

- [x] Run spec-check on age assignments (17/17 matches)
- [x] Run code-reviewer agent (3 fixes applied: TrainArcherRule save check, AGE_DARK constants, per-building age names)
- [x] Run test agent (30 new tests, all 437 pass)
- [x] Run ai-observer (age-gating PASS, barracks_by_90s FAIL — economy bottleneck, not age-gating bug)
- [x] Update gotchas.md
- [x] Write phase-4.0b.md checkpoint
- [x] Verify game launches

## Age assignments

Buildings: house/barracks/farm/mill/lumber_camp/mining_camp = Dark, archery_range/stable/market = Feudal
Units: villager/militia = Dark, archer/skirmisher/spearman/scout_cavalry/trade_cart = Feudal, cavalry_archer = Castle
