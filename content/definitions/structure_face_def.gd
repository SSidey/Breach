class_name StructureFaceDef
extends Resource
## A face of a structure plan's cell (Decision 61, spec 24): a face wall on the north or
## west side, or a floor under the cell (a roof is the floor of the cell above), of a
## material and a thickness in eighths of a cell (Decision 65). South and east faces are
## stored as the neighbour's north and west, so each face has one key.

const NORTH := 0
const WEST := 1
const FLOOR := 2

const SIDE_NAMES := ["north", "west", "floor"]

## (x, y, level): level 0 stands on the ground.
@export var cell: Vector3i = Vector3i.ZERO
## NORTH, WEST or FLOOR.
@export_enum("north", "west", "floor") var side: int = NORTH
@export var material_id: String = ""
## Eighths of a cell, 1 to 8.
@export var thickness: int = 1


## A face by any side name: north, south, east, west or floor.
static func make(
	at: Vector3i, side_name: String, material: String, eighths: int
) -> StructureFaceDef:
	var face := StructureFaceDef.new()
	face.material_id = material
	face.thickness = eighths
	match side_name:
		"south":
			face.cell = at + Vector3i(0, 1, 0)
			face.side = NORTH
		"east":
			face.cell = at + Vector3i(1, 0, 0)
			face.side = WEST
		_:
			face.cell = at
			face.side = SIDE_NAMES.find(side_name)
	return face


## "face:x,y,level,side", as load paths name elements.
func key() -> String:
	return "face:%d,%d,%d,%s" % [cell.x, cell.y, cell.z, SIDE_NAMES[side]]
