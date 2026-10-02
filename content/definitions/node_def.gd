class_name NodeDef
extends Resource
## Map node definition (Farm/Fort/Core/PlayerHome shapes). See
## specs/07-data-resource-schemas.md, specs/03-resource-nodes-and-workers.md, and
## specs/09-node-graph-and-lanes.md.

## NEUTRAL appended (Phase 4 item 2), never inserted - .tres files store the raw
## ordinal, and inserting would silently reinterpret already-authored content.
## WAYPOINT appended per specs/16-designer-map-import.md (Decision 25's candidate): a
## pure routing point with no type-specific validation.
enum NodeType { ORIGIN, RESOURCE, FORT, NEUTRAL, WAYPOINT }

## Append-only, per specs/12-node-schema-round-3.md. Matches EconomySystem._pools'
## existing five keys. Authored ahead of any node using anything but FOOD - a real
## generic-resource consumer (sim/capture_resolution.gd still hardcodes "food") is
## future work, not this field.
enum ResourceType { FOOD, WOOD, STONE, METAL, CRYSTAL }

const StructurePlanDef = preload("res://content/definitions/structure_plan_def.gd")

## Stable authoring identifier (Phase 4 item 2) - rendering/authoring metadata only,
## sim/ never reads it. Needed once array index is no longer globally unique across
## lanes.
@export var id: String = ""

## Rendering position (Phase 4 item 2) - authoring/rendering metadata only, per
## Decision 19: sim/ mechanics stay purely index-based and never read this field.
@export var position: Vector2 = Vector2.ZERO

@export var node_type: NodeType = NodeType.ORIGIN
@export var garrison: int = 0

## Only meaningful when node_type == RESOURCE.
@export var yield_food_per_tick: int = 0
@export var decay_interval_ticks: int = 0
@export var decay_floor_food: int = 0

## Additive, per specs/12-node-schema-round-3.md - existing Food-specific fields
## above are untouched (no rename), so sim/capture_resolution.gd's reads keep
## compiling and behaving identically. Authored, not yet read by sim/.
@export var resource_type: ResourceType = ResourceType.FOOD

## Fixes total_reserves' old 0-means-unlimited overload (round 3): 0 can't mean both
## "empty" and "infinite". Defaults true so content authored before this field
## existed keeps its effectively-unlimited behavior unchanged. Once total_reserves is
## actually consumed by a future item, intended semantics: only yield ABOVE
## decay_floor_food should deplete it when this is false - the floor stays an
## eternally-renewable baseline, leaving room for a future "maintained by skilled
## units" mechanic without another schema change.
@export var is_inexhaustible: bool = true

## The real finite pool size when is_inexhaustible is false. Ignored (unlimited)
## when is_inexhaustible is true. Authored, not yet read by sim/.
@export var total_reserves: int = 0

## Which faction controls this node - meaningful for ORIGIN-type "base" nodes, not
## hard-gated to that type. Cross-referenced against the map's faction roster in
## MapDef.validate(). Per specs/13-faction-def-and-garrison-unit.md: this and
## LaneDef.player_home_index are now two independent ways to identify "the player's
## base" on the same node - a known, documented tension, not resolved here.
@export var owning_faction_id: String = ""

## Factions that do not know this node exists at map start - secret and secondary
## objectives, per specs/15-node-hidden-from-factions.md (Decision 28). Empty = known to
## every faction. Cross-referenced against the map's faction roster in MapDef.validate().
## Authored, not yet read by sim/ or presentation/; how a hidden node gets revealed
## (scouting, events) is not designed yet.
@export var hidden_from_faction_ids: Array[String] = []

## A node whose loss matters to its faction - the members of LossGroupDef groups, per
## specs/19-map-layout-and-objectives.md. Authored data; sim/ doesn't read it yet.
@export var is_critical_asset: bool = false

## Pooled blocker stats CombatResolver fights against, required when garrison > 0.
## See specs/02-lane-movement-and-combat.md, Decision 11 - `garrison` is a
## presence/count check, these are the real combat numbers.
@export var garrison_hp: int = 0
@export var garrison_dmg: int = 0

## Assignment roles, per specs/13-faction-def-and-garrison-unit.md (revised from
## specs/12 - see Decision 24): affiliation/behavior per stationed unit, not pooled
## on the node. Static defense needs no field of its own: garrison/garrison_hp/
## garrison_dmg above already work on any node_type (not type-gated), so "a
## structure can have a garrison" is already true. Empty = static only, no units
## assigned. Only meaningful with garrison > 0. Each entry's patrol_route/
## delivery_target_id/faction_id are cross-referenced against the map's real node
## ids/faction roster in MapDef.validate().
@export var garrison_units: Array[GarrisonUnitDef] = []

## CaptureResolution's capture-choice figures. See
## specs/03-resource-nodes-and-workers.md. Food/Wood/Stone-specific rather than
## generic-resource-typed, matching yield_food_per_tick's existing convention - this
## slice's only resource node produces Food and its only fort has no resource type.
@export var ravage_yield_food: int = 0  ## RESOURCE nodes only.
@export var dismantle_wood_yield: int = 0  ## FORT nodes only.
@export var dismantle_stone_yield: int = 0  ## FORT nodes only.
@export var fortify_wood_cost: int = 0  ## FORT nodes only.
@export var fortify_stone_cost: int = 0  ## FORT nodes only.

## Free-text/id placeholder for what unlocks on capture. Empty = none. No unlock
## system consumes this yet.
@export var capture_reward: String = ""

## The structure's plan of cells, faces and loads (spec 24); null = none drawn yet.
@export var plan: StructurePlanDef


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("id must not be empty")
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
	if total_reserves < 0:
		errors.append("total_reserves must be >= 0, got %d" % total_reserves)
	if not garrison_units.is_empty() and garrison <= 0:
		errors.append("garrison_units requires garrison > 0, got %d" % garrison)
	errors.append_array(_validate_garrison_units_and_hidden_from())
	return errors


## Per-entry checks for the two faction-referencing lists. Local checks only; existence
## against the map's node ids and faction roster is MapDef's job.
func _validate_garrison_units_and_hidden_from() -> PackedStringArray:
	var errors := PackedStringArray()
	for unit in garrison_units:
		for unit_error in unit.validate():
			errors.append(unit_error)
	var seen := {}
	for faction_id in hidden_from_faction_ids:
		if faction_id.is_empty():
			errors.append("hidden_from_faction_ids must not contain an empty faction id")
		elif seen.has(faction_id):
			errors.append("hidden_from_faction_ids lists '%s' more than once" % faction_id)
		seen[faction_id] = true
	return errors
