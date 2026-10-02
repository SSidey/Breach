class_name DesignerLibraryImporter
extends RefCounted
## The designer's terrain library (content/designer/terrain.json) -> the one shared
## TerrainLibraryDef, per specs/19-map-layout-and-objectives.md (Decision 32). Pure
## static, headless-testable, same shape as DesignerMapImporter.
##
## in_use_problems() is the guard that keeps a library edit from breaking a map: every
## terrain and feature a saved designer map (content/maps_src/*.designer.json) uses must
## still exist in the new library, or DesignerLibraryImport refuses to write it.

const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainFeatureDef = preload("res://content/definitions/terrain_feature_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")
const MaterialDef = preload("res://content/definitions/material_def.gd")
const StratumDef = preload("res://content/definitions/stratum_def.gd")

const MAP_SUFFIX := ".designer.json"


class DesignerLibraryImportResult:
	var library: TerrainLibraryDef = TerrainLibraryDef.new()
	var errors: PackedStringArray = PackedStringArray()


static func import_file(json_path: String) -> DesignerLibraryImportResult:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary:
		var result := DesignerLibraryImportResult.new()
		result.errors.append("%s is not a JSON object" % json_path)
		return result
	return import_library(parsed)


static func import_library(library_data: Dictionary) -> DesignerLibraryImportResult:
	var result := DesignerLibraryImportResult.new()
	for entry in library_data.get("terrains", []):
		if _require_id(entry, "terrain", result.errors):
			result.library.terrains.append(_terrain(entry))
	for entry in library_data.get("materials", []):
		if _require_id(entry, "material", result.errors):
			result.library.materials.append(_material(entry))
	for entry in library_data.get("features", []):
		if _require_id(entry, "feature", result.errors):
			result.library.features.append(_feature(entry))
	result.library.road_move_multiplier = float(library_data.get("road_move_multiplier", 0.5))
	return result


## {"terrains": {id: [map names]}, "features": {id: [map names]}} for every saved map.
static func used_ids(maps_src_dir: String) -> Dictionary:
	var used := {"terrains": {}, "features": {}}
	var dir := DirAccess.open(maps_src_dir)
	if dir == null:
		return used
	for file_name in dir.get_files():
		if not file_name.ends_with(MAP_SUFFIX):
			continue
		var export_data = JSON.parse_string(
			FileAccess.get_file_as_string(maps_src_dir.path_join(file_name))
		)
		if export_data is Dictionary:
			_collect_used(export_data, file_name.trim_suffix(MAP_SUFFIX), used)
	return used


static func in_use_problems(library: TerrainLibraryDef, maps_src_dir: String) -> PackedStringArray:
	var problems := PackedStringArray()
	var used := used_ids(maps_src_dir)
	for terrain_id in used["terrains"]:
		if library.terrain(terrain_id) == null:
			problems.append(_still_used("terrain", terrain_id, used["terrains"][terrain_id]))
	for feature_id in used["features"]:
		if library.feature(feature_id) == null:
			problems.append(_still_used("feature", feature_id, used["features"][feature_id]))
	return problems


static func _still_used(kind: String, entry_id: String, maps: Array) -> String:
	return (
		"%s '%s' is still used by %s - change those maps first, or keep it in the library"
		% [kind, entry_id, ", ".join(maps)]
	)


static func _collect_used(export_data: Dictionary, map_name: String, used: Dictionary) -> void:
	var terrain_ids := [str(export_data.get("default_terrain", ""))]
	var feature_ids := []
	for tile in export_data.get("tiles", []):
		if not tile.get("terrain_is_base", false):
			terrain_ids.append(str(tile.get("terrain", "")))
		if tile.get("feature") != null:
			feature_ids.append(str(tile.get("feature")))
	for terrain_id in terrain_ids:
		_note(used["terrains"], terrain_id, map_name)
	for feature_id in feature_ids:
		_note(used["features"], feature_id, map_name)


static func _note(bucket: Dictionary, entry_id: String, map_name: String) -> void:
	if entry_id.is_empty():
		return
	if not bucket.has(entry_id):
		bucket[entry_id] = []
	if not bucket[entry_id].has(map_name):
		bucket[entry_id].append(map_name)


static func _require_id(entry: Dictionary, kind: String, errors: PackedStringArray) -> bool:
	if str(entry.get("id", "")).is_empty():
		errors.append("a %s entry has no id: %s" % [kind, JSON.stringify(entry)])
		return false
	return true


static func _terrain(entry: Dictionary) -> TerrainDef:
	var terrain := TerrainDef.new()
	terrain.id = str(entry["id"])
	terrain.display_name = str(entry.get("label", terrain.id))
	terrain.glyph = str(entry.get("glyph", ""))
	terrain.color = Color.from_string(str(entry.get("color", "#ffffff")), Color.WHITE)
	terrain.can_be_base = bool(entry.get("can_be_base", true))
	terrain.needs_bridge = bool(entry.get("needs_bridge", false))
	terrain.move_cost = float(entry.get("move_cost", 1.0))
	var blocked: Array[String] = []
	for part in str(entry.get("blocks_unit_classes", "")).split(","):
		if not part.strip_edges().is_empty():
			blocked.append(part.strip_edges())
	terrain.blocks_unit_classes = blocked
	for field in ["stability", "max_height", "max_width", "max_length", "max_depth"]:
		terrain.set("default_" + field, int(entry.get("default_" + field, 0)))
	_ground(terrain, entry)
	return terrain


## The ground fields (Decisions 53, 54); a terrain saved before them has none.
static func _ground(terrain: TerrainDef, entry: Dictionary) -> void:
	terrain.bearing = int(entry.get("bearing", 0))
	terrain.foundation_max = int(entry.get("foundation_max", terrain.bearing))
	terrain.dig_depth = int(entry.get("dig_depth", 0))
	var water = entry.get("water_table")
	if water is Dictionary:
		terrain.water_table_min = int(water.get("min", -1))
		terrain.water_table_max = int(water.get("max", -1))
	for band in entry.get("strata", []):
		var stratum := StratumDef.new()
		stratum.material_id = str(band.get("material", ""))
		stratum.min_cells = int(band.get("min", 1))
		stratum.max_cells = int(band.get("max", stratum.min_cells))
		terrain.strata.append(stratum)


static func _material(entry: Dictionary) -> MaterialDef:
	var material := MaterialDef.new()
	material.id = str(entry["id"])
	material.display_name = str(entry.get("label", material.id))
	material.color = Color.from_string(str(entry.get("color", "#ffffff")), Color.WHITE)
	material.dig_difficulty = int(entry.get("dig_difficulty", 1))
	material.climb_difficulty = int(entry.get("climb_difficulty", 0))
	material.weight = int(entry.get("weight", 1))
	material.span = int(entry.get("span", 1))
	material.loose = bool(entry.get("loose", false))
	return material


static func _feature(entry: Dictionary) -> TerrainFeatureDef:
	var feature := TerrainFeatureDef.new()
	feature.id = str(entry["id"])
	feature.display_name = str(entry.get("label", feature.id))
	feature.glyph = str(entry.get("glyph", ""))
	feature.effect_notes = str(entry.get("stub_effect", ""))
	return feature
