class_name StructureSupports
extends RefCounted
## What holds up each element of a structure plan (Decision 61, spec 24). Elements are
## keyed "cell:x,y,level" or "face:x,y,level,side"; the ground under a column is
## "ground:x,y". Pure over the plan it is given.
## - A solid cell rests on the solid cell beneath, the floor under it, or the ground.
## - A face wall rests on the same face a level down, a solid cell beneath either side,
##   or the ground at level 0.
## - A floor rests on the solid cell beneath, the face walls along its edges a level down,
##   or the ground at level 0.
## Ground counts only where it isn't dug, or is dug and filled with a solid (Decision 67);
## a liquid fill (a moat) holds nothing up.

const StructurePlanDef = preload("res://content/definitions/structure_plan_def.gd")
const StructureFaceDef = preload("res://content/definitions/structure_face_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")

const DOWN := Vector3i(0, 0, -1)

var _plan: StructurePlanDef
var _faces := {}  # key -> StructureFaceDef
var _dug := {}  # Vector3i -> true


## library tells solid fills from liquid ones; without it every fill counts as still dug.
func _init(plan: StructurePlanDef, library: TerrainLibraryDef = null) -> void:
	_plan = plan
	for face in plan.faces:
		_faces[face.key()] = face
	for at in plan.dug:
		var fill = library.material(plan.fills[at]) if library and plan.fills.has(at) else null
		if fill == null or fill.is_liquid():
			_dug[at] = true


## Every element: key -> {"at": Vector3i, "kind": "cell" | side name, "material": id,
## "eighths": 8 for a cell, else the face's thickness}.
func elements() -> Dictionary:
	var out := {}
	for at in _plan.solid_cells:
		out[_cell_key(at)] = {
			"at": at, "kind": "cell", "material": _plan.solid_cells[at], "eighths": 8
		}
	for key in _faces:
		var face: StructureFaceDef = _faces[key]
		out[key] = {
			"at": face.cell,
			"kind": StructureFaceDef.SIDE_NAMES[face.side],
			"material": face.material_id,
			"eighths": face.thickness
		}
	return out


## The keys an element rests on directly; [] if nothing holds it but its neighbours.
func direct(element: Dictionary) -> Array:
	var at: Vector3i = element["at"]
	match element["kind"]:
		"cell":
			return _first([_cell(at + DOWN), _face(at, "floor"), _ground(at, at)])
		"floor":
			var walls := []
			for edge in [[at, "north"], [at + Vector3i(0, 1, 0), "north"], [at, "west"]]:
				walls.append(_face(edge[0] + DOWN, edge[1]))
			walls.append(_face(at + Vector3i(1, 0, 0) + DOWN, "west"))
			walls = walls.filter(func(k): return k != "")
			if _cell(at + DOWN):
				return [_cell(at + DOWN)]
			return walls if not walls.is_empty() else _first([_ground(at, at)])
		_:
			var beside := (
				at + (Vector3i(0, -1, 0) if element["kind"] == "north" else Vector3i(-1, 0, 0))
			)
			if _face(at + DOWN, element["kind"]):
				return [_face(at + DOWN, element["kind"])]
			var cells := [_cell(at + DOWN), _cell(beside + DOWN)].filter(func(k): return k != "")
			return cells if not cells.is_empty() else _first([_ground(at, beside)])


## Elements of the same kind beside this one, which it can hang from within its span: the
## next face along a wall's run, the next floor, the next solid cell.
func neighbours(element: Dictionary) -> Array:
	var at: Vector3i = element["at"]
	var steps := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]
	if element["kind"] == "north":
		steps = steps.slice(0, 2)
	elif element["kind"] == "west":
		steps = steps.slice(2, 4)
	var out := []
	for step in steps:
		var key: String = (
			_cell(at + step) if element["kind"] == "cell" else _face(at + step, element["kind"])
		)
		if key:
			out.append(key)
	return out


## What a load resting in a cell bears on: its floor, the solid cell beneath, the ground.
func load_target(at: Vector3i) -> String:
	var found := _first([_face(at, "floor"), _cell(at + DOWN), _ground(at, at)])
	return found[0] if not found.is_empty() else ""


func _cell(at: Vector3i) -> String:
	return _cell_key(at) if _plan.solid_cells.has(at) else ""


func _face(at: Vector3i, side: String) -> String:
	var key := "face:%d,%d,%d,%s" % [at.x, at.y, at.z, side]
	return key if _faces.has(key) else ""


## The ground under one of two columns at level 0 (the first not dug out), or "".
func _ground(at: Vector3i, other: Vector3i) -> String:
	if at.z != 0:
		return ""
	for column in [at, other]:
		if not _dug.has(column + DOWN):
			return "ground:%d,%d" % [column.x, column.y]
	return ""


static func _first(keys: Array) -> Array:
	for key in keys:
		if key:
			return [key]
	return []


static func _cell_key(at: Vector3i) -> String:
	return "cell:%d,%d,%d" % [at.x, at.y, at.z]
