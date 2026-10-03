class_name DesignerPlanBuilder
extends RefCounted
## A designer structure plan (spec 24) -> StructurePlanDef: solid cells keyed "x,y,level",
## faces with any side name (south and east stored as the neighbour's north and west),
## dug cells as [x, y, level], fills keyed "x,y,level" (Decision 67), and loads keyed
## "x,y,level". A face's `into_neighbour`, when given, overrides the side's default. Pure.

const StructurePlanDef = preload("res://content/definitions/structure_plan_def.gd")
const StructureFaceDef = preload("res://content/definitions/structure_face_def.gd")


static func build(data: Dictionary) -> StructurePlanDef:
	var plan := StructurePlanDef.new()
	var cells = data.get("solid_cells", {})
	for at in cells if cells is Dictionary else {}:
		plan.solid_cells[_cell(at)] = str(cells[at])
	for face in data.get("faces", []):
		var at := Vector3i(int(face.get("x", 0)), int(face.get("y", 0)), int(face.get("level", 0)))
		var built := StructureFaceDef.make(
			at,
			str(face.get("side", "north")),
			str(face.get("material", "")),
			int(face.get("thickness", 1))
		)
		if face.has("into_neighbour"):
			built.into_neighbour = bool(face["into_neighbour"])
		plan.faces.append(built)
	for dug in data.get("dug", []):
		plan.dug.append(Vector3i(int(dug[0]), int(dug[1]), int(dug[2])))
	var fills = data.get("fills", {})
	for at in fills if fills is Dictionary else {}:
		plan.fills[_cell(at)] = str(fills[at])
	var loads = data.get("loads", {})
	for at in loads if loads is Dictionary else {}:
		plan.loads[_cell(at)] = int(loads[at])
	return plan


static func _cell(text: String) -> Vector3i:
	var parts := text.split(",")
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
