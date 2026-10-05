class_name UnitMotion
extends RefCounted
## How a unit moves and turns on its own (Decisions 95 and 105, spec 27 round 8; model C).
## A unit faces a bearing: an angle in degrees, clockwise from north (0 north, 90 east, 180
## south, 270 west), turned freely. It may move any way, at a pace set by the angle
## between its bearing and its heading - its full speed straight ahead, down to its
## backward pace straight back - while its bearing turns towards its heading, or stays on
## a foe it backs away from, at its turn rate (degrees a second). Both are unit stats: a
## grem is nimbler than a brute. A unit turning to its places or its foe is exposed, as a
## blow from outside its front is a flank blow (Decision 88). Pure.

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

const EPSILON := 0.000001


## The unit vector of a bearing.
static func vector(bearing: float) -> Vector2:
	var angle := deg_to_rad(bearing)
	return Vector2(sin(angle), -cos(angle))


## The bearing of a squad facing (SquadFrame: 0 north, 1 east, 2 south, 3 west).
static func of_facing(facing: int) -> float:
	return posmod(facing, 4) * 90.0


## The bearing of the way from `from` to `to` (`current` if they coincide).
static func bearing_to(from: Vector2, to: Vector2, current: float) -> float:
	var way := to - from
	if way.length() < EPSILON:
		return current
	return fposmod(rad_to_deg(atan2(way.x, -way.y)), 360.0)


## Degrees from bearing `from` to `to` the short way round: positive clockwise, in
## (-180, 180]. An exact about-turn goes clockwise (to the unit's right).
static func _apart(from: float, to: float) -> float:
	var turn := fposmod(to - from, 360.0)
	return turn - 360.0 if turn > 180.0 + EPSILON else turn


## Turns the unit towards `wanted` by what its turn rate allows in `seconds`; true once it
## faces it.
static func turn(unit: SkirmishUnit, wanted: float, seconds: float) -> bool:
	var left := _apart(unit.bearing, wanted)
	if absf(left) < EPSILON:
		unit.bearing = fposmod(wanted, 360.0)
		return true
	var reach := unit.turn_rate * seconds
	if reach >= absf(left) - EPSILON:
		unit.bearing = fposmod(wanted, 360.0)
		return true
	unit.bearing = fposmod(unit.bearing + signf(left) * reach, 360.0)
	return false


## The share of its speed the unit makes moving along `heading` while facing `bearing`
## (its own, if not given): 1 straight ahead, its backward pace straight back.
static func pace(unit: SkirmishUnit, heading: Vector2, bearing = null) -> float:
	if heading.length() < EPSILON:
		return 1.0
	var facing: float = unit.bearing if bearing == null else bearing
	var cosine := clampf(heading.normalized().dot(vector(facing)), -1.0, 1.0)
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
