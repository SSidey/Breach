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


# --- Decision 67: flush walls and filled digs ---------------------------------------


func test_a_wall_grows_into_the_cell_it_was_drawn_from() -> void:
	var north := StructureFaceDef.make(Vector3i(2, 3, 0), "north", "TIMBER", 1)
	var south := StructureFaceDef.make(Vector3i(2, 3, 0), "south", "TIMBER", 1)
	var east := StructureFaceDef.make(Vector3i(2, 3, 0), "east", "TIMBER", 1)

	assert_bool(north.into_neighbour).is_false()  # grows into (2, 3), its own cell
	assert_bool(south.into_neighbour).is_true()  # stored on (2, 4), grows back into (2, 3)
	assert_bool(east.into_neighbour).is_true()


func test_a_floor_has_no_neighbour_to_grow_into() -> void:
	var plan := StructurePlanDef.new()
	var floor := StructureFaceDef.make(Vector3i(0, 0, 1), "floor", "TIMBER", 2)
	floor.into_neighbour = true
	plan.faces = [floor]

	assert_bool(_any(plan.validate(_library()), "a floor has no neighbour")).is_true()


func test_a_dug_cell_can_be_filled_with_a_known_material() -> void:
	var plan := StructurePlanDef.new()
	plan.dug = [Vector3i(1, 1, -1)]
	plan.fills = {Vector3i(1, 1, -1): "TIMBER"}

	assert_array(Array(plan.validate(_library()))).is_empty()


func test_fills_must_be_dug_and_of_known_materials() -> void:
	var plan := StructurePlanDef.new()
	plan.dug = [Vector3i(1, 1, -1)]
	plan.fills = {Vector3i(1, 1, -1): "MARBLE", Vector3i(5, 5, -1): "TIMBER"}

	var errors := plan.validate(_library())

	assert_bool(_any(errors, "unknown material 'MARBLE'")).is_true()
	assert_bool(_any(errors, "isn't dug")).is_true()
