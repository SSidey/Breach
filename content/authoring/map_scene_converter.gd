class_name MapSceneConverter
## Converts a hand-authored map scene tree (MapSceneRoot > MapLaneRoot > MapNodeMarker)
## into a MapDef, per specs/10-map-scene-authoring.md. Pure and @tool-free: operates
## on any plain Node2D tree, so it's testable against a detached tree built with
## .new()/add_child() with no running SceneTree required. Scoped to topology only -
## map-global scalar fields (tick_duration_seconds etc.) are the caller's job.

const NodeDef = preload("res://content/definitions/node_def.gd")
const LaneDef = preload("res://content/definitions/lane_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")
const MapEdgeDef = preload("res://content/definitions/map_edge_def.gd")
const MapLaneRoot = preload("res://content/authoring/map_lane_root.gd")
const MapNodeMarker = preload("res://content/authoring/map_node_marker.gd")
const MapEdgeMarker = preload("res://content/authoring/map_edge_marker.gd")


class MapSceneConversionResult:
	extends RefCounted
	var map_def: MapDef = MapDef.new()
	var errors: PackedStringArray = PackedStringArray()


class _LaneConversionResult:
	extends RefCounted
	var lane_def: LaneDef
	var errors: PackedStringArray = PackedStringArray()


class _EdgeConversionResult:
	extends RefCounted
	var edge_def: MapEdgeDef
	var errors: PackedStringArray = PackedStringArray()


static func build_map_def(scene_root: Node2D) -> MapSceneConversionResult:
	var result := MapSceneConversionResult.new()
	var lanes: Array[LaneDef] = []
	var edges: Array[MapEdgeDef] = []
	for child in scene_root.get_children():
		if child is MapLaneRoot:
			var lane_result := _build_lane_def(child)
			lanes.append(lane_result.lane_def)
			result.errors.append_array(lane_result.errors)
		elif child is MapEdgeMarker:
			var edge_result := _build_edge_def(child)
			if edge_result.edge_def != null:
				edges.append(edge_result.edge_def)
			result.errors.append_array(edge_result.errors)
	result.map_def.lanes = lanes
	result.map_def.edges = edges
	return result


static func _build_edge_def(marker: MapEdgeMarker) -> _EdgeConversionResult:
	var result := _EdgeConversionResult.new()
	if marker.node_a == null or marker.node_a.node_def == null:
		result.errors.append("edge marker missing node_a (or its node_def)")
		return result
	if marker.node_b == null or marker.node_b.node_def == null:
		result.errors.append("edge marker missing node_b (or its node_def)")
		return result

	var edge_def := MapEdgeDef.new()
	edge_def.node_a_id = marker.node_a.node_def.id
	edge_def.node_b_id = marker.node_b.node_def.id
	result.edge_def = edge_def
	return result


static func _build_lane_def(lane_root: MapLaneRoot) -> _LaneConversionResult:
	var result := _LaneConversionResult.new()
	var lane_def := LaneDef.new()
	lane_def.id = lane_root.lane_id

	var nodes: Array[NodeDef] = []
	var player_home_indices: Array[int] = []
	for marker in lane_root.get_children():
		var node_def: NodeDef = marker.node_def.duplicate()
		node_def.position = marker.position
		if marker.player_home:
			player_home_indices.append(nodes.size())
		nodes.append(node_def)
	lane_def.nodes = nodes

	if player_home_indices.size() == 1:
		lane_def.player_home_index = player_home_indices[0]
	else:
		result.errors.append(
			(
				"lane '%s': expected exactly 1 player_home marker, got %d"
				% [lane_def.id, player_home_indices.size()]
			)
		)

	result.lane_def = lane_def
	return result
