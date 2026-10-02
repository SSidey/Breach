extends GdUnitTestSuite
## StructurePlanDef and StructureFaceDef, per Decisions 61 and 65 and spec 24: solid cells,
## faces (walls with a thickness in eighths, floors), dug cells and loads.

const StructurePlanDef = preload("res://content/definitions/structure_plan_def.gd")
const StructureFaceDef = preload("res://content/definitions/structure_face_def.gd")
const MaterialDef = preload("res://content/definitions/material_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")


func _library() -> TerrainLibraryDef:
	var timber := MaterialDef.new()
	timber.id = "TIMBER"
	var library := TerrainLibraryDef.new()
	library.materials = [timber]
	return library


func _any(errors: PackedStringArray, needle: String) -> bool:
	return Array(errors).any(func(m): return m.contains(needle))


func test_south_and_east_faces_are_stored_as_the_neighbours_north_and_west() -> void:
	var south := StructureFaceDef.make(Vector3i(2, 3, 0), "south", "TIMBER", 1)
	var east := StructureFaceDef.make(Vector3i(2, 3, 0), "east", "TIMBER", 1)

	assert_str(south.key()).is_equal("face:2,4,0,north")
	assert_str(east.key()).is_equal("face:3,3,0,west")


func test_a_plan_finds_its_faces() -> void:
	var plan := StructurePlanDef.new()
	plan.faces = [StructureFaceDef.make(Vector3i(0, 0, 1), "floor", "TIMBER", 2)]

	assert_int(plan.face_at(Vector3i(0, 0, 1), StructureFaceDef.FLOOR).thickness).is_equal(2)
	assert_object(plan.face_at(Vector3i(0, 0, 1), StructureFaceDef.NORTH)).is_null()


func test_a_plan_of_known_materials_validates() -> void:
	var plan := StructurePlanDef.new()
	plan.solid_cells = {Vector3i(0, 0, 0): "TIMBER"}
	plan.faces = [StructureFaceDef.make(Vector3i(1, 0, 0), "north", "TIMBER", 1)]

	assert_array(Array(plan.validate(_library()))).is_empty()


func test_unknown_materials_and_thicknesses_outside_one_to_eight_are_errors() -> void:
	var plan := StructurePlanDef.new()
	plan.solid_cells = {Vector3i(0, 0, 0): "MARBLE"}
	plan.faces = [StructureFaceDef.make(Vector3i(1, 0, 0), "north", "TIMBER", 9)]

	var errors := plan.validate(_library())

	assert_bool(_any(errors, "unknown material 'MARBLE'")).is_true()
	assert_bool(_any(errors, "thickness 9")).is_true()
