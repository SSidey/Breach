class_name ChannelDef
extends Resource
## A carved feature along a path of tiles (Decision 59): a river or stream, a ditch or a
## moat - or, with a negative depth, a bank or mound. Its centre line runs through the
## tile centres; it is `width` cells across (with a one-cell sloped bank), `depth` cells
## deep, and can hold a flowing material (water, lava) `liquid_depth` cells deep.

const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")

## Tiles (col, row) in order; each next to the one before (diagonals too).
@export var tiles: Array[Vector2i] = []
@export var width: int = 4
## Cells cut below the ground; negative raises a bank instead.
@export var depth: int = 2
## A material that flows, or "" for a dry ditch.
@export var liquid_id: String = ""
@export var liquid_depth: int = 0


func validate(cols: int, rows: int, library: TerrainLibraryDef) -> PackedStringArray:
	var errors := PackedStringArray()
	var at := "channel %s: " % [tiles]
	if width < 1:
		errors.append(at + "width must be at least 1 cell, got %d" % width)
	for index in range(tiles.size()):
		var tile := tiles[index]
		if tile.x < 0 or tile.y < 0 or tile.x >= cols or tile.y >= rows:
			errors.append(at + "tile %s is off the grid" % tile)
		if index > 0 and _apart(tiles[index - 1], tile):
			errors.append(at + "tiles %s and %s are not neighbours" % [tiles[index - 1], tile])
	if liquid_id:
		var liquid = library.material(liquid_id) if library else null
		if liquid == null or not liquid.is_liquid():
			errors.append(at + "'%s' doesn't flow, so it can't fill a channel" % liquid_id)
		if liquid_depth < 0 or liquid_depth > depth:
			errors.append(at + "liquid %d deeper than the channel's %d" % [liquid_depth, depth])
	return errors


static func _apart(a: Vector2i, b: Vector2i) -> bool:
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) != 1
