extends RefCounted
class_name BuildOrder

## Build Order System
## Defines a sequence of steps for AI to follow during early game

enum StepType {
	QUEUE_VILLAGER,      # Queue a villager with target resource assignment
	BUILD_BUILDING,      # Build a specific building
	WAIT_VILLAGERS,      # Wait until we have X total villagers
	WAIT_RESOURCES,      # Wait until we have X of a resource
	ASSIGN_VILLAGERS,    # Reassign X villagers to a resource
}

## A single step in the build order
class Step:
	var type: StepType
	var target_resource: String = ""  # For QUEUE_VILLAGER, ASSIGN_VILLAGERS
	var building_type: String = ""     # For BUILD_BUILDING
	var count: int = 0                 # For WAIT_VILLAGERS, WAIT_RESOURCES, ASSIGN_VILLAGERS
	var resource_type: String = ""     # For WAIT_RESOURCES

	func _init(step_type: StepType) -> void:
		type = step_type

	static func queue_villager(resource: String) -> Step:
		var step = Step.new(StepType.QUEUE_VILLAGER)
		step.target_resource = resource
		return step

	static func build(building: String) -> Step:
		var step = Step.new(StepType.BUILD_BUILDING)
		step.building_type = building
		return step

	static func wait_villagers(villager_count: int) -> Step:
		var step = Step.new(StepType.WAIT_VILLAGERS)
		step.count = villager_count
		return step

	static func wait_resources(resource: String, amount: int) -> Step:
		var step = Step.new(StepType.WAIT_RESOURCES)
		step.resource_type = resource
		step.count = amount
		return step

	static func assign_villagers(resource: String, villager_count: int) -> Step:
		var step = Step.new(StepType.ASSIGN_VILLAGERS)
		step.target_resource = resource
		step.count = villager_count
		return step

var steps: Array[Step] = []
var name: String = ""

func _init(order_name: String = "Custom") -> void:
	name = order_name

func add_step(step: Step) -> void:
	steps.append(step)

func get_step(index: int) -> Step:
	if index >= 0 and index < steps.size():
		return steps[index]
	return null

func size() -> int:
	return steps.size()

## Create a standard Dark Age build order
## Optimized for fast economy into military production
static func create_dark_age_build_order() -> BuildOrder:
	var bo = BuildOrder.new("Dark Age Standard")

	# Starting: 3 villagers, ~200 food, ~200 wood
	# Goal: 22 villagers, farms, barracks, archery range, stable

	# Phase 1: Initial food gathering (sheep/berries)
	# Queue 3 vils to food (we start with 3, going to 6)
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("food"))

	# Build first house at pop 4 (need before pop 5)
	bo.add_step(Step.wait_villagers(4))
	bo.add_step(Step.build("house"))

	# Phase 2: Wood economy
	# Send next 4 vils to wood
	bo.add_step(Step.queue_villager("wood"))
	bo.add_step(Step.queue_villager("wood"))
	bo.add_step(Step.queue_villager("wood"))
	bo.add_step(Step.queue_villager("wood"))

	# Build lumber camp near trees
	bo.add_step(Step.wait_villagers(8))
	bo.add_step(Step.build("lumber_camp"))

	# Build second house at pop 9
	bo.add_step(Step.build("house"))

	# Phase 3: More food for military
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("food"))

	# Build mill for farm efficiency
	bo.add_step(Step.wait_villagers(12))
	bo.add_step(Step.build("mill"))

	# Phase 4: Gold economy (for archers)
	bo.add_step(Step.queue_villager("gold"))
	bo.add_step(Step.queue_villager("gold"))
	bo.add_step(Step.queue_villager("gold"))

	# Build mining camp near gold
	bo.add_step(Step.build("mining_camp"))

	# Build third house
	bo.add_step(Step.build("house"))

	# Phase 5: Military buildings
	bo.add_step(Step.wait_villagers(15))
	bo.add_step(Step.wait_resources("wood", 175))
	bo.add_step(Step.build("barracks"))

	# More villagers while barracks builds
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("wood"))
	bo.add_step(Step.queue_villager("gold"))

	# Build fourth house
	bo.add_step(Step.build("house"))

	# Build archery range
	bo.add_step(Step.wait_villagers(18))
	bo.add_step(Step.wait_resources("wood", 175))
	bo.add_step(Step.build("archery_range"))

	# Continue economy
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("wood"))

	# Build stable
	bo.add_step(Step.wait_resources("wood", 175))
	bo.add_step(Step.build("stable"))

	# Build farms as berries run out
	bo.add_step(Step.build("farm"))
	bo.add_step(Step.build("farm"))

	# Fifth house
	bo.add_step(Step.build("house"))

	# Target: 22 villagers, then focus on military
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.wait_villagers(22))

	return bo

## Create an aggressive rush build order
## Faster military, fewer villagers
static func create_rush_build_order() -> BuildOrder:
	var bo = BuildOrder.new("Rush")

	# Quick economy, fast barracks
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("food"))

	bo.add_step(Step.wait_villagers(4))
	bo.add_step(Step.build("house"))

	bo.add_step(Step.queue_villager("wood"))
	bo.add_step(Step.queue_villager("wood"))
	bo.add_step(Step.queue_villager("wood"))

	bo.add_step(Step.wait_villagers(7))
	bo.add_step(Step.build("lumber_camp"))

	# Early barracks
	bo.add_step(Step.wait_resources("wood", 100))
	bo.add_step(Step.build("barracks"))

	bo.add_step(Step.build("house"))

	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("food"))
	bo.add_step(Step.queue_villager("gold"))

	bo.add_step(Step.wait_villagers(12))
	bo.add_step(Step.build("house"))

	# Rush with militia + archers
	bo.add_step(Step.build("archery_range"))
	bo.add_step(Step.build("farm"))

	bo.add_step(Step.queue_villager("gold"))
	bo.add_step(Step.queue_villager("gold"))

	bo.add_step(Step.wait_villagers(15))

	return bo
