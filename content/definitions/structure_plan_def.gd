class_name StructurePlanDef
extends Resource
## A structure's plan (Decisions 52, 61, spec 24): cells in levels over its site. Solid
## cells of a material (cell walls, keeps), faces (face walls and floors), cells dug out
## of the ground beneath, and loads resting in cells (a ballista, stores), in load units
## (Decision 65).

const StructureFaceDef = preload("res://content/definitions/structure_face_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")

## Vector3i(x, y, level) -> material id.
@export var solid_cells: Dictionary = {}
@export var faces: Array[StructureFaceDef] = []
## Ground cells removed (level < 0).
@export var dug: Array[Vector3i] = []
## Vector3i cell -> load units resting there.
@export var loads: Dictionary = {}


## side: StructureFaceDef.NORTH, WEST or FLOOR.
func face_at(at: Vector3i, side: int) -> StructureFaceDef:
	for face in faces:
		if face.cell == at and face.side == side:
			return face
	return null


func validate(library: TerrainLibraryDef) -> PackedStringArray:
	var errors := PackedStringArray()
	for at in solid_cells:
		if library.material(solid_cells[at]) == null:
			errors.append("cell %s: unknown material '%s'" % [at, solid_cells[at]])
	for face in faces:
		if library.material(face.material_id) == null:
			errors.append("%s: unknown material '%s'" % [face.key(), face.material_id])
		if face.thickness < 1 or face.thickness > 8:
			errors.append("%s: thickness %d is not 1 to 8 eighths" % [face.key(), face.thickness])
	return errors
