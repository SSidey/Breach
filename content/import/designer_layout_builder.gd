class_name DesignerLayoutBuilder
extends RefCounted
## Builds a MapLayoutDef from a designer export, per
## specs/19-map-layout-and-objectives.md: grid, default terrain, tiles, roads and each
## link's route. Terrain and feature ids must exist in the shared TerrainLibraryDef the
## layout references (Decision 32); a missing one is an error naming the cell, since the
## designer should have saved its terrain library first.

const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")
const TileDef = preload("res://content/definitions/tile_def.gd")
const BridgeDef = preload("res://content/definitions/bridge_def.gd")
const RoadSegmentDef = preload("res://content/definitions/road_segment_def.gd")
const RouteDef = preload("res://content/definitions/route_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")

const OVERRIDES := {
	"stability_override": "stability",
	"max_height_override": "max_height",
	"max_width_override": "max_width",
	"dig_depth_override": "max_depth",
}
const MISSING := "is not in the shared terrain library - save the terrain library in the designer"


## null when the export has no grid (nothing spatial was authored).
static func build(
	export_data: Dictionary, library: TerrainLibraryDef, errors: PackedStringArray
) -> MapLayoutDef:
	var grid: Dictionary = export_data.get("grid", {})
	if grid.is_empty():
		return null
	var layout := MapLayoutDef.new()
	layout.cols = int(grid.get("cols", 0))
	layout.rows = int(grid.get("rows", 0))
	layout.cell_size = int(export_data.get("cell_size", 64))
	layout.default_terrain_id = str(export_data.get("default_terrain", ""))
	layout.terrain_library = library
	if library.terrain(layout.default_terrain_id) == null:
		errors.append("default terrain '%s' %s" % [layout.default_terrain_id, MISSING])
	for entry in export_data.get("tiles", []):
		layout.tiles.append(_tile(entry, library, errors))
	for entry in export_data.get("roads", []):
		var road := RoadSegmentDef.new()
		road.a = cell_of(entry.get("a", {}))
		road.b = cell_of(entry.get("b", {}))
		layout.roads.append(road)
	for entry in export_data.get("links", []):
		if not entry.get("route", []).is_empty():
			layout.routes.append(_route(entry))
	return layout


## The designer's {row, col} as a (col, row) cell.
static func cell_of(grid_position: Dictionary) -> Vector2i:
	return Vector2i(int(grid_position.get("col", 0)), int(grid_position.get("row", 0)))


static func _tile(
	entry: Dictionary, library: TerrainLibraryDef, errors: PackedStringArray
) -> TileDef:
	var tile := TileDef.new()
	tile.cell = cell_of(entry.get("grid_position", {}))
	if not entry.get("terrain_is_base", false):
		tile.terrain_id = str(entry.get("terrain", ""))
		if library.terrain(tile.terrain_id) == null:
			errors.append("tile %s: terrain '%s' %s" % [tile.cell, tile.terrain_id, MISSING])
	if entry.get("feature") != null:
		tile.feature_id = str(entry.get("feature"))
		if library.feature(tile.feature_id) == null:
			errors.append("tile %s: feature '%s' %s" % [tile.cell, tile.feature_id, MISSING])
	if entry.get("bridge") is Dictionary:
		tile.bridge = _bridge(entry["bridge"])
	for key in OVERRIDES:
		if entry.get(key) != null:
			tile.set(OVERRIDES[key], int(entry[key]))
	tile.upgrade_slots = int(entry.get("upgrade_slots", 0))
	var upgrades: Array[String] = []
	for upgrade in entry.get("upgrades", []):
		upgrades.append(str(upgrade))
	tile.upgrade_ids = upgrades
	return tile


static func _bridge(entry: Dictionary) -> BridgeDef:
	var bridge := BridgeDef.new()
	bridge.owning_faction_id = str(entry.get("owning_faction_id", ""))
	bridge.hp = int(entry.get("hp", 40))
	bridge.demolishable_by_owner = bool(entry.get("demolishable_by_owner", false))
	bridge.drawbridge_node_id = str(entry.get("drawbridge_node_id", ""))
	bridge.raised = bool(entry.get("raised", false))
	return bridge


static func _route(entry: Dictionary) -> RouteDef:
	var route := RouteDef.new()
	route.node_a_id = str(entry.get("a", ""))
	route.node_b_id = str(entry.get("b", ""))
	var cells: Array[Vector2i] = []
	for grid_position in entry.get("route", []):
		cells.append(cell_of(grid_position))
	route.cells = cells
	route.cost = float(entry.get("route_cost", 0.0)) if entry.get("route_cost") != null else 0.0
	return route
