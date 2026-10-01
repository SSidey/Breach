class_name MapLayoutView
extends RefCounted
## The spatial half of what the map viewer draws, per specs/19-map-layout-and-
## objectives.md: every grid cell with its terrain colour (from the shared terrain
## library), feature glyphs, bridges, road segments, and each link's route as points.
## Pure and read-only over content/; MapViewModel uses it when a map has a layout.

const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const NO_CELL := Vector2i(-1, -1)


class CellView:
	var cell: Vector2i
	var rect: Rect2
	var color: Color
	var glyph: String
	var feature_glyph: String
	var has_bridge: bool
	var is_drawbridge: bool
	var raised: bool


var cells: Array[CellView] = []
var road_segments: Array[PackedVector2Array] = []
var grid_rect: Rect2 = Rect2()

var _cell_size: float = 64.0
var _routes: Dictionary = {}  # "a|b" -> PackedVector2Array, oriented a -> b


static func build(layout: MapLayoutDef) -> MapLayoutView:
	var view := MapLayoutView.new()
	view._cell_size = float(layout.cell_size)
	view.grid_rect = Rect2(Vector2.ZERO, Vector2(layout.cols, layout.rows) * view._cell_size)
	for row in range(layout.rows):
		for col in range(layout.cols):
			view.cells.append(view._cell_view(layout, Vector2i(col, row)))
	for road in layout.roads:
		view.road_segments.append(PackedVector2Array([view.center(road.a), view.center(road.b)]))
	for route in layout.routes:
		var points := PackedVector2Array()
		for cell in route.cells:
			points.append(view.center(cell))
		view._routes[route.node_a_id + "|" + route.node_b_id] = points
	return view


func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size


## The route between two nodes as points from a to b; empty when the link has none.
func route_points(node_a_id: String, node_b_id: String) -> PackedVector2Array:
	var key := node_a_id + "|" + node_b_id
	if _routes.has(key):
		return _routes[key]
	var reverse := node_b_id + "|" + node_a_id
	if _routes.has(reverse):
		var points: PackedVector2Array = _routes[reverse].duplicate()
		points.reverse()
		return points
	return PackedVector2Array()


func cell_at(point: Vector2) -> Vector2i:
	if not grid_rect.has_point(point):
		return NO_CELL
	return Vector2i((point / _cell_size).floor())


func _cell_view(layout: MapLayoutDef, cell: Vector2i) -> CellView:
	var entry := CellView.new()
	entry.cell = cell
	entry.rect = Rect2(Vector2(cell) * _cell_size, Vector2(_cell_size, _cell_size))
	var terrain = layout.terrain_library.terrain(layout.terrain_id_at(cell))
	entry.color = terrain.color if terrain != null else Color.MAGENTA  # magenta = missing
	entry.glyph = terrain.glyph if terrain != null else "?"
	var tile = layout.tile_at(cell)
	if tile != null:
		var feature = layout.terrain_library.feature(tile.feature_id) if tile.feature_id else null
		entry.feature_glyph = feature.glyph if feature != null else ""
		entry.has_bridge = tile.bridge != null
		entry.is_drawbridge = entry.has_bridge and tile.bridge.drawbridge_node_id != ""
		entry.raised = entry.has_bridge and tile.bridge.raised
	return entry
