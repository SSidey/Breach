class_name SquadGeometry
extends RefCounted
## Where squads stand relative to one another in cells (Decisions 74 and 75, spec 27 round
## 1): gaps along a squad's facing, whether two lines overlap across it, and the point a
## unit's rank stands at. On a straight lane these give the lane's distance arithmetic in
## tiles. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const CELLS := float(MapLayoutDef.CELLS_PER_TILE)
const EPSILON := 0.000001


## How far `to`'s front lies ahead of `from`'s along `from`'s facing, in tiles.
static func gap(from: SkirmishSquad, to: SkirmishSquad) -> float:
	return SquadFrame.gap_along(from.position, to.position, from.facing) / CELLS


## How far a unit's rank stands ahead of `from`'s front along its facing, in tiles.
static func unit_gap(from: SkirmishSquad, to: SkirmishSquad, unit: SkirmishUnit) -> float:
	var point := to.position - SquadFrame.forward(to.facing) * unit.rank
	return SquadFrame.gap_along(from.position, point, from.facing) / CELLS


## True if the two squads' lines overlap across `from`'s facing (and face the same axis).
static func overlaps(from: SkirmishSquad, to: SkirmishSquad) -> bool:
	if posmod(from.facing - to.facing, 2) != 0:
		return false
	var mine := lateral(from)
	var theirs := lateral(to)
	return minf(mine.y, theirs.y) - maxf(mine.x, theirs.x) > EPSILON


## True if the two squads face each other's way: only these meet in round 1.
static func facing_off(from: SkirmishSquad, to: SkirmishSquad) -> bool:
	return to.facing == SquadFrame.opposite(from.facing)


## The squad's extent across its facing, from its living units' spans (empty: none).
static func lateral(squad: SkirmishSquad) -> Vector2:
	var extent := Vector2(INF, -INF)
	for unit in squad.living():
		var span := squad.lateral_span(unit)
		extent = Vector2(minf(extent.x, span.x), maxf(extent.y, span.y))
	return extent
