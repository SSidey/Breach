@tool
class_name MapView
extends Node2D
## Draws a MapDef, per specs/18-map-viewer.md: grid, edges, lane paths, node art tinted
## by owner, labels and hidden badges - all from MapViewModel, so this file only paints.
## @tool so a map assigned in the Inspector draws in the editor's 2D viewport too.
##
## Rendering has no automated coverage beyond smoke tests (it needs a render context),
## same as LaneView; the viewer scene is checked by hand.

const MapViewModel = preload("res://presentation/map_view_model.gd")
const MapArtSet = preload("res://presentation/map_art_set.gd")
const NodeDef = preload("res://content/definitions/node_def.gd")

const NODE_SIZE := 40.0
const WAYPOINT_SIZE := 20.0
const BADGE_SIZE := 18.0
const LABEL_FONT_SIZE := 12

@export var map: MapDef:
	set(value):
		map = value
		_rebuild()
@export var art_set: MapArtSet:
	set(value):
		art_set = value
		queue_redraw()
## "" = the designer's view (everything); a faction id = only what that faction knows.
@export var view_as_faction_id: String = "":
	set(value):
		view_as_faction_id = value
		_rebuild()

## Highlighted with a ring (set by the viewer on click).
var selected_id: String = "":
	set(value):
		selected_id = value
		queue_redraw()

var model: MapViewModel


## The outline MapView draws when the art set has no texture for node_type.
static func shape_points(node_type: int, center: Vector2, size: float) -> PackedVector2Array:
	var r := size * 0.5
	match node_type:
		NodeDef.NodeType.RESOURCE:
			return _regular(center, r, 4, -PI / 2.0)
		NodeDef.NodeType.FORT:
			return _fort(center, r)
		NodeDef.NodeType.NEUTRAL:
			return _regular(center, r, 6, -PI / 2.0)
		NodeDef.NodeType.WAYPOINT:
			return _regular(center, r * 0.6, 12, 0.0)
	return _regular(center, r, 24, 0.0)  # ORIGIN: a disc


static func _regular(center: Vector2, r: float, sides: int, start: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		points.append(center + Vector2.from_angle(start + TAU * i / sides) * r)
	return points


## Same outline as assets/placeholder/map/fort.svg (64 px box, centre 32, half-size 26).
static func _fort(center: Vector2, r: float) -> PackedVector2Array:
	var svg := [
		[8, 18],
		[8, 6],
		[18, 6],
		[18, 12],
		[27, 12],
		[27, 6],
		[37, 6],
		[37, 12],
		[46, 12],
		[46, 6],
		[56, 6],
		[56, 18],
		[56, 58],
		[8, 58],
	]
	var points := PackedVector2Array()
	for p in svg:
		points.append(center + (Vector2(p[0], p[1]) - Vector2(32, 32)) / 26.0 * r)
	return points


## The id of the node under a point given in this node's parent/global space, else "".
func node_at(point: Vector2) -> String:
	if model == null:
		return ""
	return model.node_at(to_local(point), NODE_SIZE * 0.6)


func _rebuild() -> void:
	model = MapViewModel.build(map, view_as_faction_id) if map != null else null
	queue_redraw()


func _art() -> MapArtSet:
	if art_set == null:
		art_set = MapArtSet.new()
	return art_set


func _draw() -> void:
	if model == null:
		return
	var art := _art()
	draw_rect(model.bounds, art.background_color)
	_draw_grid(art)
	for segment in model.edge_segments:
		draw_dashed_line(segment[0], segment[1], art.edge_color, 2.0, 8.0)
	for i in range(model.lane_paths.size()):
		var color := art.lane_colors[i % art.lane_colors.size()]
		for run in model.lane_paths[i].runs:
			if run.size() > 1:
				draw_polyline(run, color, 5.0, true)
	for marker in model.markers:
		_draw_marker(marker, art)


func _draw_grid(art: MapArtSet) -> void:
	var rect := model.bounds
	var cell := MapViewModel.CELL
	var x := ceilf(rect.position.x / cell) * cell
	while x <= rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), art.grid_color)
		x += cell
	var y := ceilf(rect.position.y / cell) * cell
	while y <= rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), art.grid_color)
		y += cell


func _draw_marker(marker: MapViewModel.Marker, art: MapArtSet) -> void:
	var size := WAYPOINT_SIZE if marker.node_type == NodeDef.NodeType.WAYPOINT else NODE_SIZE
	var tint := model.faction_color(marker.owner_id, art.faction_palette, art.neutral_color)
	if marker.id == selected_id:
		draw_arc(marker.position, size * 0.75, 0.0, TAU, 32, art.label_color, 3.0, true)
	draw_circle(marker.position, size * 0.62, tint)
	var texture := art.texture_for(marker.node_type)
	if texture != null:
		var rect := Rect2(marker.position - Vector2(size, size) * 0.5, Vector2(size, size))
		draw_texture_rect(texture, rect, false, tint.lightened(0.45))
	else:
		var points := shape_points(marker.node_type, marker.position, size)
		draw_colored_polygon(points, tint.lightened(0.45))
		points.append(points[0])
		draw_polyline(points, art.label_color, 2.0, true)
	_draw_label(marker, size, art)
	if marker.hidden_badge:
		_draw_hidden_badge(marker.position + Vector2(size, -size) * 0.45, art)


func _draw_label(marker: MapViewModel.Marker, size: float, art: MapArtSet) -> void:
	var text := marker.id
	if marker.garrison > 0:
		text += "  ×%d" % marker.garrison
	var width := 120.0
	# Below the selection ring (radius size * 0.75) so a selected node's label stays readable.
	var origin := marker.position + Vector2(-width * 0.5, size * 0.8 + LABEL_FONT_SIZE)
	draw_string(
		ThemeDB.fallback_font,
		origin,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		LABEL_FONT_SIZE,
		art.label_color
	)


func _draw_hidden_badge(center: Vector2, art: MapArtSet) -> void:
	var half := Vector2(BADGE_SIZE, BADGE_SIZE) * 0.5
	if art.hidden_badge != null:
		draw_texture_rect(art.hidden_badge, Rect2(center - half, half * 2.0), false)
		return
	draw_circle(center, BADGE_SIZE * 0.5, art.label_color)
	draw_line(center - half * 0.6, center + half * 0.6, Color("#e06b5a"), 3.0, true)
