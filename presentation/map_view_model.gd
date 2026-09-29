class_name MapViewModel
extends RefCounted
## What the map viewer draws, per specs/18-map-viewer.md: computed headlessly from a
## MapDef so MapView's _draw() only has to paint it. Read-only over content/.
##
## View-as follows Decision 28: an empty view_as_faction_id is the designer's view
## (everything shown; nodes hidden from anyone get a badge). With a faction set, nodes
## hidden from it are left out, as is every edge touching them, and a lane path splits
## into separate runs at such a node rather than drawing a line through what that
## faction doesn't know about.

const MapDef = preload("res://content/definitions/map_def.gd")
const NodeDef = preload("res://content/definitions/node_def.gd")

## One designer cell; bounds are grown by this so edge nodes aren't drawn at the frame.
const CELL := 64.0
const DEFAULT_BOUNDS := Rect2(Vector2.ZERO, Vector2(CELL * 10, CELL * 6))


class Marker:
	var id: String
	var position: Vector2
	var node_type: int
	var owner_id: String
	var garrison: int
	var hidden_from: Array[String]
	var on_lane: bool
	var hidden_badge: bool


class LanePath:
	var id: String
	var runs: Array[PackedVector2Array] = []


var markers: Array[Marker] = []
var lane_paths: Array[LanePath] = []
var edge_segments: Array[PackedVector2Array] = []
var bounds: Rect2 = DEFAULT_BOUNDS

var _faction_ids: Array[String] = []


static func build(map_def: MapDef, view_as_faction_id: String = "") -> MapViewModel:
	var model := MapViewModel.new()
	for faction in map_def.factions:
		model._faction_ids.append(faction.id)
	var visible_by_id := {}
	for entry in _unique_nodes(map_def):
		var node: NodeDef = entry[0]
		if view_as_faction_id != "" and node.hidden_from_faction_ids.has(view_as_faction_id):
			continue
		var marker := _marker(node, entry[1], view_as_faction_id)
		model.markers.append(marker)
		visible_by_id[node.id] = marker
	for lane in map_def.lanes:
		model.lane_paths.append(_lane_path(lane, visible_by_id))
	for edge in map_def.edges:
		if visible_by_id.has(edge.node_a_id) and visible_by_id.has(edge.node_b_id):
			model.edge_segments.append(
				PackedVector2Array(
					[visible_by_id[edge.node_a_id].position, visible_by_id[edge.node_b_id].position]
				)
			)
	model.bounds = _bounds(model.markers)
	return model


## [[NodeDef, on_lane], ...], each node instance once, lane nodes first.
static func _unique_nodes(map_def: MapDef) -> Array:
	var seen := {}
	var out := []
	for lane in map_def.lanes:
		for node in lane.nodes:
			if not seen.has(node):
				seen[node] = true
				out.append([node, true])
	for node in map_def.off_lane_nodes:
		if not seen.has(node):
			seen[node] = true
			out.append([node, false])
	return out


static func _marker(node: NodeDef, on_lane: bool, view_as_faction_id: String) -> Marker:
	var marker := Marker.new()
	marker.id = node.id
	marker.position = node.position
	marker.node_type = node.node_type
	marker.owner_id = node.owning_faction_id
	marker.garrison = maxi(node.garrison, node.garrison_units.size())
	marker.hidden_from = node.hidden_from_faction_ids.duplicate()
	marker.on_lane = on_lane
	marker.hidden_badge = view_as_faction_id == "" and not marker.hidden_from.is_empty()
	return marker


static func _lane_path(lane, visible_by_id: Dictionary) -> LanePath:
	var path := LanePath.new()
	path.id = lane.id
	var run := PackedVector2Array()
	for node in lane.nodes:
		if visible_by_id.has(node.id):
			run.append(visible_by_id[node.id].position)
		elif not run.is_empty():
			path.runs.append(run)
			run = PackedVector2Array()
	if not run.is_empty():
		path.runs.append(run)
	return path


static func _bounds(all_markers: Array[Marker]) -> Rect2:
	if all_markers.is_empty():
		return DEFAULT_BOUNDS
	var rect := Rect2(all_markers[0].position, Vector2.ZERO)
	for marker in all_markers:
		rect = rect.expand(marker.position)
	return rect.grow(CELL)


## The faction's index in the map's roster, wrapped over the palette; neutral otherwise.
func faction_color(faction_id: String, palette: Array[Color], neutral: Color) -> Color:
	var index := _faction_ids.find(faction_id)
	if faction_id == "" or index == -1 or palette.is_empty():
		return neutral
	return palette[index % palette.size()]


## The id of the nearest visible marker within radius of point, else "".
func node_at(point: Vector2, radius: float) -> String:
	var best := ""
	var best_distance := radius
	for marker in markers:
		var distance := marker.position.distance_to(point)
		if distance <= best_distance:
			best = marker.id
			best_distance = distance
	return best
