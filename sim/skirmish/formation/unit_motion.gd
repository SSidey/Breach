class_name UnitMotion
extends RefCounted
## How a unit moves and turns on its own (Decision 95, spec 27 round 8; model C). A unit
## faces one of 8 bearings (45 degree steps, clockwise from north: 0 north, 2 east, 4
## south, 6 west). It may move any way, at a pace set by the angle between its bearing and
## its heading - its full speed straight ahead, down to its backward pace straight back -
## while its bearing turns towards its heading, or stays on a foe it backs away from, at
## its turn rate (degrees a second). Both are unit stats: a grem is nimbler than a brute.
## A unit turning to its places or its foe is exposed, as a blow from outside its front is
## a flank blow (Decision 88). Pure.

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

const STEP_DEGREES := 45.0
const EPSILON := 0.000001


## The unit vector of a bearing.
static func vector(bearing: int) -> Vector2:
	var angle := deg_to_rad(posmod(bearing, 8) * STEP_DEGREES)
	return Vector2(sin(angle), -cos(angle))


## The bearing of a squad facing (SquadFrame: 0 north, 1 east, 2 south, 3 west).
static func of_facing(facing: int) -> int:
	return posmod(facing, 4) * 2


## The bearing nearest the way from `from` to `to` (unchanged if they coincide).
static func bearing_to(from: Vector2, to: Vector2, current: int) -> int:
	var way := to - from
	if way.length() < EPSILON:
		return current
	var degrees := rad_to_deg(atan2(way.x, -way.y))
	return posmod(roundi(degrees / STEP_DEGREES), 8)


## Turns the unit towards `wanted` by what its turn rate allows in `seconds`; true once it
## faces it.
static func turn(unit: SkirmishUnit, wanted: int, seconds: float) -> bool:
	var apart := posmod(wanted - unit.bearing, 8)
	if apart == 0:
		unit.turn_spare = 0.0
		return true
	unit.turn_spare += unit.turn_rate * seconds
	var way := 1 if apart <= 4 else -1
	while unit.turn_spare >= STEP_DEGREES - EPSILON and unit.bearing != wanted:
		unit.bearing = posmod(unit.bearing + way, 8)
		unit.turn_spare -= STEP_DEGREES
	return unit.bearing == wanted


## The share of its speed the unit makes moving along `heading`, by how far that is from
## its bearing: 1 straight ahead, its backward pace straight back.
static func pace(unit: SkirmishUnit, heading: Vector2) -> float:
	if heading.length() < EPSILON:
		return 1.0
	var cosine := clampf(heading.normalized().dot(vector(unit.bearing)), -1.0, 1.0)
	var off := rad_to_deg(acos(cosine)) / 180.0
	return 1.0 - (1.0 - unit.backward_pace) * off


## The unit's next point moving from `at` to `to` with `full_step` cells at full pace, at
## the pace its present bearing allows (it turns separately).
static func move(unit: SkirmishUnit, at: Vector2, to: Vector2, full_step: float) -> Vector2:
	return at.move_toward(to, full_step * pace(unit, to - at))


## The unit's next point walking from `at` to `to` with `full_step` cells at full pace,
## turning as it goes - towards its heading, or to keep facing `face_point` if given.
static func walk(
	unit: SkirmishUnit,
	at: Vector2,
	to: Vector2,
	full_step: float,
	seconds: float,
	face_point = null
) -> Vector2:
	var heading := to - at
	var look: Vector2 = face_point if face_point != null else to
	turn(unit, bearing_to(at, look, unit.bearing), seconds)
	return at.move_toward(to, full_step * pace(unit, heading))
