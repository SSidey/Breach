class_name NodeDef
extends Resource
## Map node definition (Farm/Fort/Core/PlayerHome shapes). See
## specs/07-data-resource-schemas.md and specs/03-resource-nodes-and-workers.md.

enum NodeType { ORIGIN, RESOURCE, FORT }

@export var node_type: NodeType = NodeType.ORIGIN
@export var garrison: int = 0

## Only meaningful when node_type == RESOURCE.
@export var yield_food_per_tick: int = 0
@export var decay_interval_ticks: int = 0
@export var decay_floor_food: int = 0

## Structure-slot metadata for a future spatial-placement pass (Decision 4) - not
## validated in this slice since nothing consumes it yet.
@export var structure_slots: int = 0

## Pooled blocker stats CombatResolver fights against, required when garrison > 0.
## See specs/02-lane-movement-and-combat.md, Decision 11 - `garrison` is a
## presence/count check, these are the real combat numbers.
@export var garrison_hp: int = 0
@export var garrison_dmg: int = 0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if garrison < 0:
		errors.append("garrison must be >= 0, got %d" % garrison)
	if node_type == NodeType.RESOURCE:
		if yield_food_per_tick <= 0:
			errors.append("yield_food_per_tick must be > 0 for a RESOURCE node")
		if decay_interval_ticks <= 0:
			errors.append("decay_interval_ticks must be > 0 for a RESOURCE node")
		if decay_floor_food < 0:
			errors.append("decay_floor_food must be >= 0, got %d" % decay_floor_food)
	if garrison > 0:
		if garrison_hp <= 0:
			errors.append("garrison_hp must be > 0 when garrison > 0")
		if garrison_dmg <= 0:
			errors.append("garrison_dmg must be > 0 when garrison > 0")
	return errors
