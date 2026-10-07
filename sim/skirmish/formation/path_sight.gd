class_name PathSight
extends RefCounted
## What a pathfinder can see to plan by (spec 30): a shape, not a circle - its reach ahead,
## to either side and behind, eased between them by the angle off its facing (straight
## ahead the ahead reach, square to it the side reach, straight back the behind reach,
## linearly between). A unit type sets the three as shares of its detection range
## (UnitDef.sight_ahead, sight_side, sight_behind). Symmetric left and right, so ground
## mirrored is seen mirrored. Pure.

const UnitDef = preload("res://content/definitions/unit_def.gd")

## Where it looks from (cells) and which way (a unit vector).
var origin: Vector2
var facing: Vector2
## How far (cells) it sees straight ahead, square to either side and straight back.
var ahead: float
var side: float
var behind: float


## The sight of a unit of `unit_def` standing at `at`, facing `way`.
static func of(unit_def: UnitDef, at: Vector2, way: Vector2) -> PathSight:
	var reach := unit_def.detection_range
	return PathSight.new(
		at,
		way,
		reach * unit_def.sight_ahead,
		reach * unit_def.sight_side,
		reach * unit_def.sight_behind
	)


## How far it sees in the direction `way` (a unit vector).
func reach(way: Vector2) -> float:
	var turned := acos(clampf(way.dot(facing), -1.0, 1.0)) / (PI / 2.0)  # 0 ahead to 2 behind
	if turned <= 1.0:
		return lerpf(ahead, side, turned)
	return lerpf(side, behind, turned - 1.0)


## Whether it sees `point`.
func sees(point: Vector2) -> bool:
	var offset := point - origin
	var length := offset.length()
	return length <= 0.000001 or length <= reach(offset / length)


func _init(at: Vector2, way: Vector2, ahead_cells: float, side_cells: float, behind_cells: float):
	origin = at
	facing = way.normalized()
	ahead = ahead_cells
	side = side_cells
	behind = behind_cells
