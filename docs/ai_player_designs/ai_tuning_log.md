# AI tuning log

Tracks changes to AI behavior parameters, their motivation (usually from human vs AI game analysis), and measured impact. Useful for future sessions to understand what's been tried and what the current bottlenecks are.

Game analysis reports live in `logs/game_logs/<game_id>/analysis.md`.

## Current known issues

| Issue | Severity | Notes |
|-------|----------|-------|
| Food economy too weak for dual production | High | AI has ~4 farms vs human's 9. Can't sustain villager + militia training simultaneously after pause lifts. Fix: raise farm minimum from 4 to 6, trigger farm building at 7 villagers instead of 10. |
| Stable rarely built | Medium | AI often wood-constrained, blocks stable construction. Known since Phase 3.1C. |
| Scouting uses hardcoded positions | Low | Assumes fixed map layout. Won't scale to larger/different maps. |

## Tuning changelog

### 2026-02-06: Fix 4 — Raise villager pause threshold to < 3

**File:** `scripts/ai/ai_rules.gd` — `TrainVillagerRule.conditions()`
**Change:** Villager pause threshold from `military_population == 0` to `military_population < 3`
**Also:** `scripts/ai/ai_controller.gd` skip reason now reports `paused_for_military_N/3`
**Motivation:** Games 2 and 3 showed the AI getting stuck at 1 militia for 210-230 seconds. The `== 0` pause lifted immediately after the first militia, and food starvation prevented any further training.
**Result:** AI now reaches 3 militia by t=240s (up from max 1). But no 4th militia after pause lifts — food economy is the upstream bottleneck.
**Game:** `game_2026-02-06_14-35-03` (game 4)

### 2026-02-06: Fix 3 — Delay gold gathering until archery range exists

**File:** `scripts/ai/ai_rules.gd` — `AdjustGathererPercentagesRule.conditions()`
**Change:** Phase 0→1 transition now requires `archery_range >= 1` in addition to 10 villagers + barracks
**Motivation:** Game 2 showed 2 villagers mining gold from t=110 onward with nothing to spend it on (300 gold stockpile, archery range not built until t=370). Those villagers on food instead would have enabled continuous militia production.
**Result:** Eliminated useless gold mining entirely (0 gold until archery range built). But militia drought persisted due to villager pause threshold being too narrow (== 0).
**Game:** `game_2026-02-06_13-36-57` (game 3)

### 2026-02-06: Fix 2 — Increase farm cap

**File:** `scripts/ai/ai_rules.gd` — `BuildFarmRule.conditions()`
**Change:** Farm cap formula from `max(4, target_food_villagers / 2)` to `max(4, target_food_villagers)`
**Motivation:** Game 1 analysis showed human building 9 farms while AI capped at 4-5.
**Result:** AI builds more farms (5 in game 2, up from fewer). Incremental improvement but not sufficient alone.
**Game:** `game_2026-02-06_12-47-02` (game 2)

### 2026-02-06: Fix 1 — Pause villager training when military urgently needed

**File:** `scripts/ai/ai_rules.gd` — `TrainVillagerRule.conditions()`
**Change:** Added early return: if barracks >= 1, military == 0, and villagers >= 10, skip villager training
**Motivation:** Game 1 showed AI spending all food on villagers for 380 seconds with 0 military. Militia (60 food) could never be afforded because villagers (50 food) consumed all food first.
**Result:** First militia appeared at t=110s (down from t=460s — 350s improvement). But pause lifted after 1 militia, food starvation resumed.
**Game:** `game_2026-02-06_12-22-49` (game 1, baseline)

## Cross-game metrics

| Metric | Game 1 (baseline) | Game 2 (fixes 1+2) | Game 3 (+fix 3) | Game 4 (+fix 4) |
|--------|-------------------|---------------------|------------------|------------------|
| First militia | 460s | 110s | 130s | 130s |
| Time to 3 militia | never | never | never | 240s |
| Militia at t=240s | 0 | 1 | 1 | 3 |
| Peak AI military | 0 | ~1 | ~1 | 3 |
| Useless gold at t=240s | 600+ | 300 | 0 | 0 |
| AI farms | ~3 | ~5 | ~5 | ~4 |
| Game duration | 509s | 433s | 497s | 393s |
| Winner | Human | Human | Human | Human |
