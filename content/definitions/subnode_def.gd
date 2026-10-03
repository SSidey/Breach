class_name SubnodeDef
extends Resource
## One of a node's objectives (Decision 72, specs/26-subnodes.md): units take it by
## holding its capture area with no enemy there, and its holder then controls its zone of
## influence. Cells are columns in the node's local cells (Decision 68), all levels. A node
## is controlled only when one side holds every subnode; capture isn't simulated yet.

const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

## OBJECTIVE is a subnode painted from scratch (a crossroads, a hilltop).
const TYPES := ["WELL", "ORE_VEIN", "KEEP", "OBJECTIVE"]

## Unique within its node.
@export var id: String = ""
@export var subnode_type: String = "OBJECTIVE"
## The marker cell the subnode was placed at.
@export var at: Vector2i = Vector2i.ZERO
## Where units must stand to take it; inside the zone.
@export var capture_cells: Array[Vector2i] = []
## The cells its holder controls (building, benefit, buildings within).
@export var zone_cells: Array[Vector2i] = []


## A node's subnodes together: unique ids, zones on the node's tiles (a cell's tile is
## the node's own tile plus whole tiles of cells), and no cell in two zones.
static func validate_in_node(
	subnodes: Array, tiles: Array[Vector2i], own_tile: Vector2i
) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	var claimed := {}
	for subnode in subnodes:
		if ids.has(subnode.id):
			errors.append("subnode '%s' is listed more than once" % subnode.id)
		ids[subnode.id] = true
		var off_tiles := false
		for cell in subnode.zone_cells:
			if not off_tiles and not tiles.has(own_tile + tile_offset(cell)):
				errors.append(
					"subnode '%s': zone cell %s is off the node's tiles" % [subnode.id, cell]
				)
				off_tiles = true
			if claimed.has(cell) and claimed[cell] != subnode.id:
				errors.append(
					"subnodes '%s' and '%s' overlap at %s" % [claimed[cell], subnode.id, cell]
				)
			claimed[cell] = subnode.id
	return errors


## Which tile, relative to the node's own, a local cell lies on.
static func tile_offset(cell: Vector2i) -> Vector2i:
	var size := MapLayoutDef.CELLS_PER_TILE
	return Vector2i(floori(float(cell.x) / size), floori(float(cell.y) / size))


## Checks on the subnode alone; how it sits in its node is validate_in_node's job.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("a subnode's id must not be empty")
	if not subnode_type in TYPES:
		errors.append("subnode '%s': unknown type '%s'" % [id, subnode_type])
	if capture_cells.is_empty():
		errors.append("subnode '%s': its capture area is empty" % id)
	for cell in capture_cells:
		if not zone_cells.has(cell):
			errors.append("subnode '%s': capture cell %s is outside its zone" % [id, cell])
			break
	if not zone_cells.has(at):
		errors.append("subnode '%s': its marker %s is outside its zone" % [id, at])
	return errors
