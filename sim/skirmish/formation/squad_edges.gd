class_name SquadEdges
extends RefCounted
## A squad's four edges (Decision 78, spec 27 round 2): front, right, rear and left,
## relative to its facing (clockwise, as facings are). Which edge an attacker meets, which
## units stand on an edge (the outermost on that side, so when one falls the next inward
## is the edge: step-up inward is implicit), and how far an attacker's front is from a
## squad's near face. Pure; cells unless stated.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const FRONT := 0
const RIGHT := 1
const REAR := 2
const LEFT := 3
const EPSILON := 0.000001


## The cells the squad's living units cover.
static func bounds(squad: SkirmishSquad) -> Rect2:
	var area := Rect2()
	var first := true
	for unit in squad.living():
		var rect := _rect(squad, unit)
		area = rect if first else area.merge(rect)
		first = false
	return area


## The edge of `victim` an attacker facing `attacker_facing` meets with its front.
static func edge_hit(victim: SkirmishSquad, attacker_facing: int) -> int:
	return posmod(SquadFrame.opposite(attacker_facing) - victim.facing, 4)


## The units on an edge: those with no living unit of their squad beyond them that way.
static func edge_units(squad: SkirmishSquad, edge: int) -> Array[SkirmishUnit]:
	var outward := SquadFrame.forward(squad.facing + edge)
	var across := posmod(squad.facing + edge, 4)
	var living := squad.living()
	var out: Array[SkirmishUnit] = []
	for unit in living:
		var rect := _rect(squad, unit)
		var span := SquadFrame.lateral_interval(rect, across)
		var reach := _far(rect, outward)
		var covered := false
		for other in living:
			if other == unit:
				continue
			var other_rect := _rect(squad, other)
			var other_span := SquadFrame.lateral_interval(other_rect, across)
			var overlap := minf(span.y, other_span.y) - maxf(span.x, other_span.x)
			if overlap > EPSILON and _far(other_rect, outward) > reach + EPSILON:
				covered = true
				break
		if not covered:
			out.append(unit)
	return out


## How far `to`'s near face lies ahead of `from`'s front along `from`'s facing, in tiles.
static func face_gap(from: SkirmishSquad, to: SkirmishSquad) -> float:
	var ahead := SquadFrame.forward(from.facing)
	var near := -_far(bounds(to), -ahead)
	return (near - from.position.dot(ahead)) / MapLayoutDef.CELLS_PER_TILE


## True if `from`'s line overlaps `to`'s cells across `from`'s facing.
static func overlap_across(from: SkirmishSquad, to: SkirmishSquad) -> bool:
	var mine := Vector2(INF, -INF)
	for unit in from.living():
		var span := from.lateral_span(unit)
		mine = Vector2(minf(mine.x, span.x), maxf(mine.y, span.y))
	var theirs := SquadFrame.lateral_interval(bounds(to), from.facing)
	return minf(mine.y, theirs.y) - maxf(mine.x, theirs.x) > EPSILON


static func _rect(squad: SkirmishSquad, unit: SkirmishUnit) -> Rect2:
	return SquadFrame.unit_rect(squad.position, squad.facing, squad.width, squad.centre_shift, unit)


## How far a rect reaches along a direction (the furthest corner's projection).
static func _far(rect: Rect2, direction: Vector2) -> float:
	var best := -INF
	for corner in [
		rect.position,
		rect.end,
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.end.x, rect.position.y)
	]:
		best = maxf(best, corner.dot(direction))
	return best
