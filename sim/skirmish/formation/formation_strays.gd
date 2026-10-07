class_name FormationStrays
extends RefCounted
## A unit on its own makes for home (Decision 126): one that came to after being downed,
## its formation gone or out of sight. It becomes a lone router of its own (FormationRout):
## it flees home along its formation's route - caught by a friendly formation it runs into,
## it joins it; struck, it may be downed again or surrender; home, it returns to the
## reserve ("fled_home"). Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")


## A new routing squad (id 0, for the simulation to number) of `unit` alone, taken out of
## `squad`, fleeing home along `squad`'s route from where it stands.
static func strand(unit: SkirmishUnit, squad: SkirmishSquad) -> SkirmishSquad:
	squad.units.erase(unit)
	squad.loose.erase(unit.id)
	squad.fleeing.erase(unit.id)
	squad.chasers.erase(unit.id)
	var members: Array[SkirmishUnit] = [unit]
	var stray := SkirmishSquad.new(
		0, squad.faction_id, squad.direction, squad.home_distance, 1, members, squad.command
	)
	stray.route = squad.route
	var along: float = squad.route.distance_of(unit.position)
	stray.front_distance = along / MapLayoutDef.CELLS_PER_TILE
	stray.heading = squad.heading
	stray.state = SkirmishSquad.State.ROUTING
	stray.morale = 0
	var offset: Vector2 = unit.position - squad.route.point_at(along)
	# it walks home straight, not fanning out as a panicked rout does (RoutFlight)
	stray.fleeing[unit.id] = {"along": along, "offset": offset, "fanned": INF}
	unit.rank = 0
	unit.column = 0
	return stray


## Sets each of `strays` ([[unit, its squad], ...]) off home alone, as squads numbered from
## `next_id` added to `squads`; returns the next free squad id.
static func adopt(strays: Array, squads: Array, next_id: int) -> int:
	for stray in strays:
		var lone := strand(stray[0], stray[1])
		lone.id = next_id
		next_id += 1
		squads.append(lone)
	return next_id
