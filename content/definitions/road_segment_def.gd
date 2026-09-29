class_name RoadSegmentDef
extends Resource
## A road between two neighbouring cells (8-neighbours, so diagonals too), per
## specs/19-map-layout-and-objectives.md. Only the cells a road joins are connected;
## roads never auto-join. A road lowers movement cost (TerrainLibraryDef.
## road_move_multiplier); it isn't topology - links are.

@export var a: Vector2i = Vector2i.ZERO
@export var b: Vector2i = Vector2i.ZERO


func is_between_neighbours() -> bool:
	var delta := (b - a).abs()
	return delta != Vector2i.ZERO and delta.x <= 1 and delta.y <= 1


## Order-independent key, so a-b and b-a are the same segment.
func key() -> String:
	var low := a if a < b else b
	var high := b if a < b else a
	return "%s-%s" % [low, high]
