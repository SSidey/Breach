class_name UnitShuffle
extends RefCounted
## Taking a place in a formation (Decision 92: a turn is a re-form; spec 27 round 11): a
## unit walking to its place arrives facing the formation's way by whichever is quicker -
## shuffling there facing that way, at the pace its bearing allows (UnitMotion), or turning
## to walk, walking at full pace and turning back. So a unit stepping back a cell or two
## keeps its face to the enemy rather than spinning round. Pure.

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")

const EPSILON := 0.000001


## The point the unit should look towards walking from `at` to its place `to`, to arrive
## facing `bearing` soonest; `speed` is its full speed in cells a second.
static func look(
	unit: SkirmishUnit, at: Vector2, to: Vector2, bearing: int, speed: float
) -> Vector2:
	var way := to - at
	var ahead := at + UnitMotion.vector(bearing)
	if way.length() < EPSILON or speed < EPSILON:
		return ahead
	var heading := UnitMotion.bearing_to(at, to, unit.bearing)
	var facing_pace := _pace(unit, bearing, way)
	var shuffling := _turning(unit, unit.bearing, bearing) + way.length() / (speed * facing_pace)
	var walking := (
		_turning(unit, unit.bearing, heading)
		+ way.length() / speed
		+ _turning(unit, heading, bearing)
	)
	return ahead if shuffling <= walking else to


## Seconds the unit takes to turn from one bearing to another.
static func _turning(unit: SkirmishUnit, from: int, to: int) -> float:
	var steps := posmod(to - from, 8)
	steps = mini(steps, 8 - steps)
	return steps * UnitMotion.STEP_DEGREES / maxf(unit.turn_rate, EPSILON)


## The share of its speed the unit makes along `way` while facing `bearing`.
static func _pace(unit: SkirmishUnit, bearing: int, way: Vector2) -> float:
	var cosine := clampf(way.normalized().dot(UnitMotion.vector(bearing)), -1.0, 1.0)
	var off := rad_to_deg(acos(cosine)) / 180.0
	return maxf(1.0 - (1.0 - unit.backward_pace) * off, EPSILON)
