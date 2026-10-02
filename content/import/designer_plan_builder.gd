class_name DesignerPlanBuilder
extends RefCounted
## A designer structure plan (spec 24) -> StructurePlanDef: solid cells keyed "x,y,level",
## faces with any side name (south and east stored as the neighbour's north and west),
## dug cells as [x, y, level], and loads keyed "x,y,level". Pure.

const StructurePlanDef = preload("res://content/definitions/structure_plan_def.gd")
const StructureFaceDef = preload("res://content/definitions/structure_face_def.gd")


static func build(data: Dictionary) -> StructurePlanDef:
	var plan := StructurePlanDef.new()
	var cells = data.get("solid_cells", {})
	for at in cells if cells is Dictionary else {}:
		plan.solid_cells[_cell(at)] = str(cells[at])
	for face in data.get("faces", []):
		var at := Vector3i(int(face.get("x", 0)), int(face.get("y", 0)), int(face.get("level", 0)))
		plan.faces.append(
			StructureFaceDef.make(
				at,
				str(face.get("side", "north")),
				str(face.get("material", "")),
				int(face.get("thickness", 1))
			)
		)
	for dug in data.get("dug", []):
		plan.dug.append(Vector3i(int(dug[0]), int(dug[1]), int(dug[2])))
	var loads = data.get("loads", {})
	for at in loads if loads is Dictionary else {}:
		plan.loads[_cell(at)] = int(loads[at])
	return plan


static func _cell(text: String) -> Vector3i:
	var parts := text.split(",")
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
