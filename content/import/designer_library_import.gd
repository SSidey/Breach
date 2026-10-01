class_name DesignerLibraryImport
extends RefCounted
## Import-validate-save for the shared terrain library, per
## specs/19-map-layout-and-objectives.md: DesignerLibraryImporter, then
## TerrainLibraryDef.validate(), then the in-use guard (no saved map may lose a terrain
## or feature it uses), and ResourceSaver.save only when all three are clean. Sub-
## resources get ids derived from their own ids, so re-importing the same JSON writes a
## byte-identical .tres. tools/import_designer_library.gd runs this headlessly.

const DesignerLibraryImporter = preload("res://content/import/designer_library_importer.gd")

const LIBRARY_JSON := "res://content/designer/terrain.json"
const MAPS_SRC_DIR := "res://content/maps_src"
const LIBRARY_TRES := "res://content/terrain/terrain_library.tres"


static func run(
	source_json_path: String = LIBRARY_JSON,
	maps_src_dir: String = MAPS_SRC_DIR,
	target_tres_path: String = LIBRARY_TRES
) -> DesignerLibraryImporter.DesignerLibraryImportResult:
	var result := DesignerLibraryImporter.import_file(source_json_path)
	if result.errors.is_empty():
		result.errors.append_array(result.library.validate())
	if result.errors.is_empty():
		result.errors.append_array(
			DesignerLibraryImporter.in_use_problems(result.library, maps_src_dir)
		)
	if not result.errors.is_empty():
		return result
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(FileAccess.get_file_as_bytes(source_json_path))
	result.library.source_hash = hashing.finish().hex_encode()
	for terrain in result.library.terrains:
		terrain.resource_scene_unique_id = _safe_id("Terrain", terrain.id)
	for feature in result.library.features:
		feature.resource_scene_unique_id = _safe_id("Feature", feature.id)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(target_tres_path.get_base_dir())
	)
	var save_error := ResourceSaver.save(result.library, target_tres_path)
	if save_error != OK:
		result.errors.append("ResourceSaver.save returned error %d" % save_error)
	return result


static func _safe_id(prefix: String, raw: String) -> String:
	var out := prefix + "_"
	for character in raw:
		out += (
			character if character.is_valid_ascii_identifier() or character.is_valid_int() else "_"
		)
	return out
