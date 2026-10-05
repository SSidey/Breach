class_name FormationWheel
extends RefCounted
## A formation moves no faster than its units can (Decision 116, spec 30 round 2): each
## tick its frame's step and its sweep round a bend (FormationSweep) are cut back together
## until no unit's place moves further than that unit can walk - its own speed, at the
## pace the ground allows the squad. On a straight march nothing changes (the frame goes
## at its slowest unit's pace); round a bend the outer file covers the arc as well as the
## step, so the wheel slows to what it can walk while the files nearer the pivot take
## shorter steps, and the formation keeps its shape. No unit ever hurries. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const EPSILON := 0.000001


## The share (0 to 1) of its move the squad may make this tick: from its frame at heading
## `before` to its heading now and `delta` tiles along its route, when a unit of speed 1
## may walk `cells` cells.
static func share(squad: SkirmishSquad, before: float, delta: float, cells: float) -> float:
	if squad.route == null:
		return 1.0
	var reached := squad.route.point_at(
		(squad.front_distance + delta) * MapLayoutDef.CELLS_PER_TILE
	)
	var least := 1.0
	for unit in squad.living():
		if squad.loose.has(unit.id) or squad.fleeing.has(unit.id):
			continue
		var from := _place(squad, squad.position, before, unit)
		var to := _place(squad, reached, squad.heading, unit)
		var moved := from.distance_to(to)
		if moved > EPSILON:
			least = minf(least, unit.speed * cells / moved)
	return least


## The share (0 to 1) of its move a line of 1-cell units `width` wide, all of one speed,
## may make from its front `from` cells along `route` facing `before` to `to` cells facing
## `after`: its front rank's places moving no further than the line's straight step. For
## a march predicted before it is made (FormationRendezvous).
static func line_share(
	route: FormationRoute, width: int, from: float, to: float, before: float, after: float
) -> float:
	var step := to - from
	var least := 1.0
	for column in range(width):
		var across := column - width / 2.0 + 0.5
		var start := _line_place(route.point_at(from), before, across)
		var moved := start.distance_to(_line_place(route.point_at(to), after, across))
		if moved > EPSILON:
			least = minf(least, step / moved)
	return least


## Turns the squad's frame back from its heading now to `share` of its sweep from
## `before`, the short way round.
static func cut_sweep(squad: SkirmishSquad, before: float, share_of: float) -> void:
	var swept := fposmod(squad.heading - before + 180.0, 360.0) - 180.0
	squad.heading = fposmod(before + swept * share_of, 360.0)


static func _place(squad: SkirmishSquad, anchor: Vector2, heading: float, unit) -> Vector2:
	return SquadFrame.place(anchor, heading, squad.width, squad.centre_shift, unit)


static func _line_place(anchor: Vector2, heading: float, across: float) -> Vector2:
	var ahead := UnitMotion.vector(heading)
	return anchor - ahead.orthogonal() * across - ahead * 0.5
