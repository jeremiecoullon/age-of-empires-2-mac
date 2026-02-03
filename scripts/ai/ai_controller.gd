extends Node
class_name AIController

# =============================================================================
# AI Controller - Rule-Based System (Phase 3.1)
# =============================================================================
#
# This file was cleared as part of replacing Phase 3 with Phase 3.1.
# The original procedural AI (~3900 lines) was removed due to architectural issues.
#
# See: docs/ai_player_designs/phase3_failure_summary.md
#
# The new implementation will use a rule-based system inspired by AoE2.
# See: docs/ai_player_designs/aoe2_ai_rule_system.md
#
# =============================================================================

# Team constants (used by other systems)
const PLAYER_TEAM: int = 0
const AI_TEAM: int = 1

# Base positions
const AI_BASE_POSITION: Vector2 = Vector2(1700, 1700)
const PLAYER_BASE_POSITION: Vector2 = Vector2(480, 480)


func _ready() -> void:
	# TODO: Initialize rule-based AI system
	pass


func _process(_delta: float) -> void:
	# TODO: Evaluate rules each tick
	pass
