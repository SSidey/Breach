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

## CaptureResolution's capture-choice figures. See
## specs/03-resource-nodes-and-workers.md. Food/Wood/Stone-specific rather than
## generic-resource-typed, matching yield_food_per_tick's existing convention - this
## slice's only resource node produces Food and its only fort has no resource type.
@export var ravage_yield_food: int = 0  ## RESOURCE nodes only.
@export var dismantle_wood_yield: int = 0  ## FORT nodes only.
@export var dismantle_stone_yield: int = 0  ## FORT nodes only.
@export var fortify_wood_cost: int = 0  ## FORT nodes only.
@export var fortify_stone_cost: int = 0  ## FORT nodes only.


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
		if ravage_yield_food <= 0:
			errors.append("ravage_yield_food must be > 0 for a RESOURCE node")
	if garrison > 0:
		if garrison_hp <= 0:
			errors.append("garrison_hp must be > 0 when garrison > 0")
		if garrison_dmg <= 0:
			errors.append("garrison_dmg must be > 0 when garrison > 0")
	if node_type == NodeType.FORT:
		if dismantle_wood_yield <= 0:
			errors.append("dismantle_wood_yield must be > 0 for a FORT node")
		if dismantle_stone_yield <= 0:
			errors.append("dismantle_stone_yield must be > 0 for a FORT node")
		if fortify_wood_cost <= 0:
			errors.append("fortify_wood_cost must be > 0 for a FORT node")
		if fortify_stone_cost <= 0:
			errors.append("fortify_stone_cost must be > 0 for a FORT node")
	return errors
