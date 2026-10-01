extends GdUnitTestSuite
## MapDef.layout, MapDef.loss_groups, LossGroupDef and NodeDef.is_critical_asset, per
## specs/19-map-layout-and-objectives.md. Split from test_map_def.gd to keep that file
## under the max-file-lines gate.

const NodeDef = preload("res://content/definitions/node_def.gd")
const LaneDef = preload("res://content/definitions/lane_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")
const FactionDef = preload("res://content/definitions/faction_def.gd")
const LossGroupDef = preload("res://content/definitions/loss_group_def.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")
const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")


func _origin(id: String, critical: bool) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	node.id = id
	node.is_critical_asset = critical
	return node


func _map() -> MapDef:
	var lane := LaneDef.new()
	lane.id = "main"
	var nodes: Array[NodeDef] = [_origin("home", true), _origin("core", false)]
	lane.nodes = nodes
	var map := MapDef.new()
	var lanes: Array[LaneDef] = [lane]
	map.lanes = lanes
	map.tick_duration_seconds = 1.5
	map.suspicion_tier_thresholds = [20, 45, 70, 90]
	var player := FactionDef.new()
	player.id = "player"
	player.display_name = "Player"
	var factions: Array[FactionDef] = [player]
	map.factions = factions
	return map


func _group(faction_id: String, node_ids: Array[String]) -> LossGroupDef:
	var group := LossGroupDef.new()
	group.faction_id = faction_id
	group.display_name = "Home"
	group.node_ids = node_ids
	return group


func _any(errors: PackedStringArray, needle: String) -> bool:
	return Array(errors).any(func(m): return m.contains(needle))


func test_nodes_are_not_critical_assets_by_default() -> void:
	assert_bool(NodeDef.new().is_critical_asset).is_false()


func test_a_map_without_layout_or_loss_groups_is_still_valid() -> void:
	assert_array(_map().validate()).is_empty()


func test_a_loss_group_of_critical_assets_validates() -> void:
	var map := _map()
	var groups: Array[LossGroupDef] = [_group("player", ["home"] as Array[String])]
	map.loss_groups = groups

	assert_array(map.validate()).is_empty()


func test_loss_group_problems_are_errors() -> void:
	var map := _map()
	var groups: Array[LossGroupDef] = [
		_group("player", [] as Array[String]),
		_group("player", ["ghost", "core"] as Array[String]),
		_group("kingdom", ["home"] as Array[String]),
	]
	map.loss_groups = groups

	var errors := map.validate()

	assert_bool(_any(errors, "loss group 'Home' (player) has no nodes")).is_true()
	assert_bool(_any(errors, "unknown node 'ghost'")).is_true()
	assert_bool(_any(errors, "'core' is not a critical asset")).is_true()
	assert_bool(_any(errors, "unknown faction 'kingdom'")).is_true()


func test_the_layout_is_validated_against_the_map_nodes() -> void:
	var map := _map()
	var layout := MapLayoutDef.new()
	layout.cols = 4
	layout.rows = 3
	layout.default_terrain_id = "LAVA"
	var fields := TerrainDef.new()
	fields.id = "FIELDS"
	var library := TerrainLibraryDef.new()
	var terrains: Array[TerrainDef] = [fields]
	library.terrains = terrains
	layout.terrain_library = library
	map.layout = layout

	assert_bool(_any(map.validate(), "default_terrain_id 'LAVA'")).is_true()
