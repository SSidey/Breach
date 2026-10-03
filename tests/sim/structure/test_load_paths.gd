extends GdUnitTestSuite
## Load paths, per Decision 61 and spec 24: every element carries its weight and what rests
## on it down to the ground; it fails beyond its capacity or its span, and a ground column
## fails beyond its bearing. settle() follows the collapse through.

const LoadPaths = preload("res://sim/structure/load_paths.gd")
const StructurePlanDef = preload("res://content/definitions/structure_plan_def.gd")
const StructureFaceDef = preload("res://content/definitions/structure_face_def.gd")
const MaterialDef = preload("res://content/definitions/material_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")

const FIELDS_BEARING := 4


func _material(id: String, weight: int, strength: int, span: int) -> MaterialDef:
	var material := MaterialDef.new()
	material.id = id
	material.weight = weight
	material.strength = strength
	material.span = span
	return material


func _library() -> TerrainLibraryDef:
	var library := TerrainLibraryDef.new()
	library.materials = [_material("TIMBER", 1, 6, 3), _material("ROCK", 2, 20, 4)]
	return library


func _face(x: int, y: int, level: int, side: String, thickness: int = 1) -> StructureFaceDef:
	return StructureFaceDef.make(Vector3i(x, y, level), side, "TIMBER", thickness)


## A 3-long timber face wall along the north of row 1, two levels high.
func _wall() -> StructurePlanDef:
	var plan := StructurePlanDef.new()
	for level in range(2):
		for x in range(3):
			plan.faces.append(_face(x, 1, level, "north"))
	return plan


## A one-cell timber room, two levels high, roofed with a timber floor 8 eighths thick.
func _room() -> StructurePlanDef:
	var plan := StructurePlanDef.new()
	for level in range(2):
		for side in ["north", "south", "west", "east"]:
			plan.faces.append(_face(0, 0, level, side))
	plan.faces.append(_face(0, 0, 2, "floor", 8))
	return plan


func _failed(plan: StructurePlanDef, bearing: int = FIELDS_BEARING) -> Array:
	return LoadPaths.solve(plan, _library(), bearing)["failed"]


func test_a_timber_wall_with_no_floor_stands() -> void:
	assert_array(_failed(_wall())).is_empty()


func test_a_wall_bridges_a_dug_gap_beneath_it() -> void:
	var plan := _wall()
	plan.dug = [Vector3i(1, 1, -1), Vector3i(1, 0, -1)]

	var result := LoadPaths.solve(plan, _library(), FIELDS_BEARING)

	assert_array(result["failed"]).is_empty()
	assert_int(result["loads"]["face:0,1,0,north"]).is_equal(3)  # its own 2, and half the middle's


func test_a_roof_stands_but_a_ballista_on_it_brings_the_walls_down() -> void:
	assert_array(_failed(_room())).is_empty()

	var plan := _room()
	plan.loads = {Vector3i(0, 0, 2): 40}
	var failed := _failed(plan)

	assert_bool(failed.has("face:0,0,1,north")).is_true()
	assert_bool(failed.has("face:0,0,2,floor")).is_false()  # the roof itself holds


func test_a_floor_beyond_its_span_falls() -> void:
	var plan := StructurePlanDef.new()
	plan.faces = [_face(5, 5, 1, "floor")]

	assert_array(_failed(plan)).is_equal(["face:5,5,1,floor"])


func test_the_grounds_bearing_limits_a_stone_tower() -> void:
	var plan := StructurePlanDef.new()
	for level in range(4):
		plan.solid_cells[Vector3i(0, 0, level)] = "ROCK"

	assert_array(_failed(plan, 8)).is_empty()  # 4 cells x 16 units = 64 = bearing 8 x 8

	plan.solid_cells[Vector3i(0, 0, 4)] = "ROCK"
	assert_bool(_failed(plan, 8).has("cell:0,0,0")).is_true()


func test_failure_cascades_when_settled() -> void:
	var plan := StructurePlanDef.new()
	plan.faces = [_face(5, 5, 1, "floor")]
	plan.solid_cells = {Vector3i(5, 5, 1): "TIMBER"}  # rests on that floor

	assert_array(_failed(plan)).is_equal(["face:5,5,1,floor"])
	assert_array(LoadPaths.settle(plan, _library(), FIELDS_BEARING)).is_equal(
		["face:5,5,1,floor", "cell:5,5,1"]
	)
	assert_int(plan.faces.size()).is_equal(1)  # settle leaves the plan itself unchanged
