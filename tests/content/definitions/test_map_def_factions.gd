extends GdUnitTestSuite
## MapDef.validate()'s faction/garrison-unit cross-reference checks, split out from
## test_map_def.gd per specs/13-faction-def-and-garrison-unit.md - the source file's
## own concerns are split into private helpers (_validate_node_references,
## _validate_faction_relations); this file mirrors that split rather than growing
## test_map_def.gd past this project's max-file-lines gate.

const NodeDef = preload("res://content/definitions/node_def.gd")
const LaneDef = preload("res://content/definitions/lane_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")
const FactionRelationDef = preload("res://content/definitions/faction_relation_def.gd")
const FactionDef = preload("res://content/definitions/faction_def.gd")
const GarrisonUnitDef = preload("res://content/definitions/garrison_unit_def.gd")


func _make_origin_node(id: String) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = id
	return node


func _valid_lane(
	lane_id: String = "main", node_a_id: String = "home", node_b_id: String = "core"
) -> LaneDef:
	var lane := LaneDef.new()
	lane.id = lane_id
	var nodes: Array[NodeDef] = [_make_origin_node(node_a_id), _make_origin_node(node_b_id)]
	lane.nodes = nodes
	lane.player_home_index = 0
	return lane


func _garrisoned_fort_node(id: String) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.FORT
	node.id = id
	node.garrison = 2
	node.garrison_hp = 10
	node.garrison_dmg = 3
	node.dismantle_wood_yield = 8
	node.dismantle_stone_yield = 5
	node.fortify_wood_cost = 10
	node.fortify_stone_cost = 6
	return node


func _faction(id: String) -> FactionDef:
	var faction := FactionDef.new()
	faction.id = id
	faction.display_name = id
	return faction


func _map_with_lane(lane: LaneDef) -> MapDef:
	var map := MapDef.new()
	var lanes: Array[LaneDef] = [lane]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	return map


func test_garrison_unit_patrol_route_referencing_nonexistent_node_id_is_invalid() -> void:
	var fort := _garrisoned_fort_node("F")
	var unit := GarrisonUnitDef.new()
	unit.faction_id = "the_kingdom"
	unit.patrol_route = ["p", "ghost"]
	var units: Array[GarrisonUnitDef] = [unit]
	fort.garrison_units = units
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [_make_origin_node("p"), fort]
	lane.nodes = nodes
	lane.player_home_index = 0

	var map := _map_with_lane(lane)
	var factions: Array[FactionDef] = [_faction("the_kingdom")]
	map.factions = factions

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("ghost"))).is_true()


func test_garrison_unit_delivery_target_id_referencing_nonexistent_node_is_invalid() -> void:
	var fort := _garrisoned_fort_node("F")
	var unit := GarrisonUnitDef.new()
	unit.faction_id = "the_kingdom"
	unit.delivery_target_id = "ghost"
	var units: Array[GarrisonUnitDef] = [unit]
	fort.garrison_units = units
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [_make_origin_node("p"), fort]
	lane.nodes = nodes
	lane.player_home_index = 0

	var map := _map_with_lane(lane)
	var factions: Array[FactionDef] = [_faction("the_kingdom")]
	map.factions = factions

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("ghost"))).is_true()


func test_garrison_unit_faction_id_referencing_nonexistent_faction_is_invalid() -> void:
	var fort := _garrisoned_fort_node("F")
	var unit := GarrisonUnitDef.new()
	unit.faction_id = "ghost_faction"
	var units: Array[GarrisonUnitDef] = [unit]
	fort.garrison_units = units
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [_make_origin_node("p"), fort]
	lane.nodes = nodes
	lane.player_home_index = 0

	var map := _map_with_lane(lane)

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("ghost_faction"))).is_true()


func test_owning_faction_id_referencing_nonexistent_faction_is_invalid() -> void:
	var home := _make_origin_node("p")
	home.owning_faction_id = "ghost_faction"
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [home, _make_origin_node("core")]
	lane.nodes = nodes
	lane.player_home_index = 0

	var map := _map_with_lane(lane)

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("ghost_faction"))).is_true()


func test_hidden_from_unknown_faction_is_invalid() -> void:
	var lane := _valid_lane()
	lane.nodes[1].hidden_from_faction_ids = ["ghost_faction"]
	var map := _map_with_lane(lane)
	var factions: Array[FactionDef] = [_faction("player")]
	map.factions = factions

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("ghost_faction"))).is_true()


func test_hidden_from_declared_faction_is_valid() -> void:
	var lane := _valid_lane()
	lane.nodes[1].hidden_from_faction_ids = ["the_kingdom"]
	var map := _map_with_lane(lane)
	var factions: Array[FactionDef] = [_faction("player"), _faction("the_kingdom")]
	map.factions = factions

	assert_array(map.validate()).is_empty()


func test_faction_relations_error_is_aggregated() -> void:
	var relation := FactionRelationDef.new()
	relation.faction_a_id = "player"
	relation.faction_b_id = "player"

	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_valid_lane()]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	var relations: Array[FactionRelationDef] = [relation]
	map.faction_relations = relations

	var errors := map.validate()

	assert_array(errors).is_not_empty()


func test_faction_relation_referencing_nonexistent_faction_is_invalid() -> void:
	var relation := FactionRelationDef.new()
	relation.faction_a_id = "player"
	relation.faction_b_id = "the_kingdom"

	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_valid_lane()]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	var relations: Array[FactionRelationDef] = [relation]
	map.faction_relations = relations
	var factions: Array[FactionDef] = [_faction("player")]
	map.factions = factions

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("the_kingdom"))).is_true()


func test_duplicate_faction_relation_either_order_is_invalid() -> void:
	var a_to_b := FactionRelationDef.new()
	a_to_b.faction_a_id = "player"
	a_to_b.faction_b_id = "the_kingdom"
	var b_to_a := FactionRelationDef.new()
	b_to_a.faction_a_id = "the_kingdom"
	b_to_a.faction_b_id = "player"

	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_valid_lane()]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	var relations: Array[FactionRelationDef] = [a_to_b, b_to_a]
	map.faction_relations = relations
	var factions: Array[FactionDef] = [_faction("player"), _faction("the_kingdom")]
	map.factions = factions

	var errors := map.validate()

	assert_array(errors).is_not_empty()
	assert_bool(Array(errors).any(func(m): return m.contains("duplicate"))).is_true()


func test_valid_faction_relation_across_declared_factions_has_no_errors() -> void:
	var relation := FactionRelationDef.new()
	relation.faction_a_id = "player"
	relation.faction_b_id = "the_kingdom"
	relation.stance = FactionRelationDef.Stance.HOSTILE

	var map := MapDef.new()
	var lanes: Array[LaneDef] = [_valid_lane()]
	map.lanes = lanes
	map.tick_duration_seconds = 2.0
	map.suspicion_tier_thresholds = [25, 50, 75, 90]
	var relations: Array[FactionRelationDef] = [relation]
	map.faction_relations = relations
	var factions: Array[FactionDef] = [_faction("player"), _faction("the_kingdom")]
	map.factions = factions

	assert_array(map.validate()).is_empty()
