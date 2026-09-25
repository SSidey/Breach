class_name NodeDef
extends Resource
## Map node definition (Farm/Fort/Core/PlayerHome shapes). See
## specs/07-data-resource-schemas.md, specs/03-resource-nodes-and-workers.md, and
## specs/09-node-graph-and-lanes.md.

## NEUTRAL appended (Phase 4 item 2), never inserted - .tres files store the raw
## ordinal, and inserting would silently reinterpret already-authored content.
enum NodeType { ORIGIN, RESOURCE, FORT, NEUTRAL }

## Append-only, per specs/12-node-schema-round-3.md. Matches EconomySystem._pools'
## existing five keys. Authored ahead of any node using anything but FOOD - a real
## generic-resource consumer (sim/capture_resolution.gd still hardcodes "food") is
## future work, not this field.
enum ResourceType { FOOD, WOOD, STONE, METAL, CRYSTAL }

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

## 0 = unlimited (today's behavior, unchanged). Once consumed by a future item,
## intended semantics: only yield ABOVE decay_floor_food should deplete this - the
## floor stays an eternally-renewable baseline, leaving room for a future
## "maintained by skilled units" mechanic without another schema change.
@export var total_reserves: int = 0

## Structure-slot metadata for a future spatial-placement pass (Decision 4) - not
## validated in this slice since nothing consumes it yet.
@export var structure_slots: int = 0

## Pooled blocker stats CombatResolver fights against, required when garrison > 0.
## See specs/02-lane-movement-and-combat.md, Decision 11 - `garrison` is a
## presence/count check, these are the real combat numbers.
@export var garrison_hp: int = 0
@export var garrison_dmg: int = 0

## Assignment roles, per specs/12-node-schema-round-3.md - additive, inert; no
## patrol/sortie movement or AI exists anywhere in sim/ yet. Static defense needs no
## field of its own: garrison/garrison_hp/garrison_dmg above already work on any
## node_type (not type-gated), so "a structure can have a garrison" is already true.

## Ordered node ids a garrisoned defender patrols between. Empty = static only
## (unchanged default behavior). Only meaningful with garrison > 0. Cross-referenced
## against the map's real node ids in MapDef.validate() - a single node can't see
## the rest of the map's nodes to check its own ids exist.
@export var patrol_route: Array[String] = []

## Matches the combat addendum's already-drafted sortie concept (temporary
## intercept, returns after). Only meaningful with garrison > 0.
@export var can_sortie: bool = false

## The garrison's single default affiliation. Only meaningful with garrison > 0.
## garrison is a pooled count, not a list of individual units, so this cannot
## express per-unit mixed affiliation (e.g. a prisoner inside an enemy structure) -
## that needs a pooled-garrison -> individual-unit-list redesign, deferred alongside
## the squads/unit-library extension.
@export var garrison_faction: FactionRelationDef.FactionId = FactionRelationDef.FactionId.ENEMY

## CaptureResolution's capture-choice figures. See
## specs/03-resource-nodes-and-workers.md. Food/Wood/Stone-specific rather than
## generic-resource-typed, matching yield_food_per_tick's existing convention - this
## slice's only resource node produces Food and its only fort has no resource type.
@export var ravage_yield_food: int = 0  ## RESOURCE nodes only.
@export var dismantle_wood_yield: int = 0  ## FORT nodes only.
@export var dismantle_stone_yield: int = 0  ## FORT nodes only.
@export var fortify_wood_cost: int = 0  ## FORT nodes only.
@export var fortify_stone_cost: int = 0  ## FORT nodes only.

## Which node a RESOURCE node's future worker-delivery route targets, per the combat
## addendum's Worker-as-Combatant section. No delivery movement exists in sim/ yet.
## Cross-referenced against the map's real node ids in MapDef.validate().
@export var delivery_target_id: String = ""

## Free-text/id placeholder for what unlocks on capture. Empty = none. No unlock
## system consumes this yet.
@export var capture_reward: String = ""


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
	if not patrol_route.is_empty() and garrison <= 0:
		errors.append("patrol_route requires garrison > 0, got %d" % garrison)
	if can_sortie and garrison <= 0:
		errors.append("can_sortie requires garrison > 0, got %d" % garrison)
	return errors
