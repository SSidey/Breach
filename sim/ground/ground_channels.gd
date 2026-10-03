class_name GroundChannels
extends RefCounted
## Carving a map's channels into the ground (Decision 59): each runs through the centres
## of its tiles, `width` cells across with a one-cell sloped bank, cut `depth` cells down
## (or raised, if negative), and may hold a flowing material to a level. Pure.

const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

## Cells along a tile's edge (Decision 68).
const TILE_CELLS := MapLayoutDef.CELLS_PER_TILE

var _lines := []  # [[ChannelDef, PackedVector2Array of centre points in cells], ...]


func _init(layout: MapLayoutDef) -> void:
	for channel in layout.channels:
		var points := PackedVector2Array()
		for tile in channel.tiles:
			points.append(Vector2(tile) * TILE_CELLS + Vector2.ONE * TILE_CELLS / 2.0)
		_lines.append([channel, points])


## Cells to take off the ground at a point: the deepest cut (or highest bank) there.
func carve(point: Vector2) -> float:
	var cut := 0.0
	for line in _lines:
		var depth: float = line[0].depth * _share(line, point)
		if absf(depth) > absf(cut):
			cut = depth
	return cut


## {"material", "level"} of a channel's liquid at a point, given the uncarved ground
## height there; {} where no channel holds liquid.
func liquid(point: Vector2, ground: float) -> Dictionary:
	for line in _lines:
		var channel = line[0]
		if channel.liquid_id and channel.liquid_depth > 0 and _share(line, point) > 0.0:
			var level: float = ground - channel.depth + channel.liquid_depth
			return {"material": channel.liquid_id, "level": level}
	return {}


## How much of the channel's depth applies at a point: 1 inside, falling to 0 across the
## one-cell bank at its edge.
func _share(line: Array, point: Vector2) -> float:
	var half: float = line[0].width / 2.0
	return clampf(half - _distance(line[1], point), 0.0, 1.0)


static func _distance(points: PackedVector2Array, point: Vector2) -> float:
	if points.size() == 1:
		return point.distance_to(points[0])
	var nearest := INF
	for index in range(points.size() - 1):
		var on_line := Geometry2D.get_closest_point_to_segment(
			point, points[index], points[index + 1]
		)
		nearest = minf(nearest, point.distance_to(on_line))
	return nearest
