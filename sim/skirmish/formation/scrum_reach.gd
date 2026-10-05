class_name ScrumReach
extends RefCounted
## Who touches whom in the scrum (Decision 88, spec 27 round 5): a unit reaches an enemy
## whose cells touch its own on a face or a corner, the 8 cells round it. A unit's front
## is the 3 cells ahead of it, diagonals included; a blow from anywhere else is a flank
## blow. Pure; cells.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")

## How far apart (cells) two units' cells may be and still touch: a unit stepping between
## cells still reaches the one it is leaving.
const CONTACT := 0.25
## A point lies in a unit's front when its direction is within 60 degrees of its bearing.
const FRONT_ARC := 0.5


## Where the unit stands: its place in the scrum, or where its squad puts it.
static func at(squad: SkirmishSquad, unit: SkirmishUnit) -> Vector2:
	if squad.loose.has(unit.id):
		return squad.loose[unit.id]["at"]
	return unit.position


## The cells the unit covers, centred where it stands, turned to its squad's facing.
static func area(squad: SkirmishSquad, unit: SkirmishUnit) -> Rect2:
	var size := Vector2(unit.footprint_width, unit.footprint_depth)
	if absf(SquadFrame.forward(squad.facing).x) > 0.5:
		size = Vector2(unit.footprint_depth, unit.footprint_width)
	return Rect2(at(squad, unit) - size / 2.0, size)


static func touching(a: Rect2, b: Rect2) -> bool:
	var gap_x := maxf(a.position.x - b.end.x, b.position.x - a.end.x)
	var gap_y := maxf(a.position.y - b.end.y, b.position.y - a.end.y)
	return maxf(gap_x, gap_y) <= CONTACT


## True if `point` lies in the front of a unit at `from` on `bearing` (UnitMotion).
static func in_front(bearing: float, from: Vector2, point: Vector2) -> bool:
	var direction := point - from
	if direction.length() < 0.000001:
		return true
	return direction.normalized().dot(UnitMotion.vector(bearing)) >= FRONT_ARC - 0.000001


## The facing nearest the way from `from` to `to` (ties: along x).
static func facing_to(from: Vector2, to: Vector2) -> int:
	var direction := to - from
	if absf(direction.x) >= absf(direction.y):
		return SquadFrame.EAST if direction.x >= 0.0 else SquadFrame.WEST
	return SquadFrame.SOUTH if direction.y > 0.0 else SquadFrame.NORTH


## The cell holding a point.
static func cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x), floori(point.y))


static func centre(of_cell: Vector2i) -> Vector2:
	return Vector2(of_cell) + Vector2(0.5, 0.5)
