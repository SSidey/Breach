class_name FormationWithdraw
extends RefCounted
## A withdrawal (Decision 99, spec 27 round 10): a retreat is how a formation deals with an
## enemy, as fighting is, so it shares combat's priority (FormationManoeuvre). Ordered to
## retreat out of a fight, it leaves from where its units stand - no walking back to their
## places first:
## - **Flight:** each unit heads for home along its route at its full pace. One of a drilled
##   formation still touching a foe backs away facing it, striking back (ScrumBlows); any
##   other turns and runs, exposed as it turns. The less ordered the formation, the wider
##   its units fan out from the route's line: up to RoutFlight.FAN_DEGREES either side,
##   by a seeded angle per unit, for one with no discipline. Ground it can't cross holds it.
## - **Safe:** with no enemy within FormationRout.ENEMY_NEAR of it, and none pursuing it,
##   for FormationRout.RALLY_SECONDS - the test a rout rallies by - it re-forms on its route
##   where its units stand, facing home, and marches home (its order). One whose units are
##   all home, with nowhere further to go, re-forms there at once, and fights as any other.
## Squads keep `withdraw` ({"safe_ticks"}). Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumBlows = preload("res://sim/skirmish/formation/scrum_blows.gd")
const RoutFlight = preload("res://sim/skirmish/formation/rout_flight.gd")
const FormationRout = preload("res://sim/skirmish/formation/formation_rout.gd")
const ScrumTurn = preload("res://sim/skirmish/formation/scrum_turn.gd")
const FormationDiscipline = preload("res://sim/skirmish/formation/formation_discipline.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const CELLS := float(MapLayoutDef.CELLS_PER_TILE)
## How near (cells, along its route) home a unit has nowhere further to go.
const HOME_CELLS := 0.5


## Starts the squad withdrawing: its units leave their places where they stand.
static func begin(squad: SkirmishSquad, tick: int, events: Array) -> void:
	squad.withdraw = {"safe_ticks": 0}
	squad.stance = {}
	for unit in squad.living():
		if not squad.loose.has(unit.id):
			squad.loose[unit.id] = {"unit": unit, "at": unit.position, "goal": null}
			squad.loose[unit.id]["next"] = unit.position
	events.append(FormationEvents.squad_event("withdrawing", tick, squad))


## How far from orderly the squad is, 0 (drilled) to 1 (no discipline): how wide it fans.
static func disorder(squad: SkirmishSquad) -> float:
	if FormationDiscipline.meets_threats(squad):
		return 0.0
	return 1.0 - float(FormationDiscipline.of(squad)) / FormationDiscipline.MEETS_THREATS


## One tick of withdrawals: units flee, and squads that have been safe long enough re-form.
static func step(
	squads: Array,
	tick: int,
	pace: float,
	seconds: float,
	fight_seed: int,
	terrain: FormationTerrain,
	events: Array
) -> void:
	for squad in squads:
		if squad.withdraw.is_empty():
			continue
		if squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
			squad.withdraw = {}
			continue
		var foes := ScrumBlows.hostile_units(squad, squads)
		for unit in squad.living():
			_flee(squad, unit, foes, [pace, seconds, fight_seed], terrain)
		var safe := _safe(squad, squads, foes)
		squad.withdraw["safe_ticks"] = squad.withdraw["safe_ticks"] + 1 if safe else 0
		var long_enough: bool = (
			squad.withdraw["safe_ticks"] * seconds >= FormationRout.RALLY_SECONDS
		)
		if long_enough or _home(squad):
			_reform_here(squad, tick, events)


## `motion` is [pace (cells a tick at speed 1), seconds, fight seed].
static func _flee(
	squad: SkirmishSquad, unit: SkirmishUnit, foes: Array, motion: Array, terrain
) -> void:
	var entry: Dictionary = squad.loose[unit.id]
	var at: Vector2 = entry["at"]
	var along := squad.route.distance_of(at)
	var home: float = squad.home_distance * CELLS
	if absf(along - home) < HOME_CELLS:
		return  # home
	var homeward: Vector2 = squad.route.heading_at(along) * signf(home - along)
	var full: float = unit.speed * motion[0]
	var heading := homeward.rotated(RoutFlight.fan(unit, motion[2]) * disorder(squad))
	if terrain != null and terrain.factor(unit.height, at, at + heading) <= 0.0:
		heading = homeward  # it can't fan that way: it keeps to the line
	if terrain != null:
		full *= terrain.factor(unit.height, at, at + heading)
	var foe_at = null
	if FormationDiscipline.meets_threats(squad):
		foe_at = ScrumBlows.nearest_touching(squad, unit, foes, motion[2])
	var to := at + heading * maxf(full, 0.000001)
	entry["at"] = UnitMotion.walk(unit, at, to, full, motion[1], foe_at)
	entry["next"] = entry["at"]
	entry["goal"] = null


## True if all its units are home: it has nowhere further to go.
static func _home(squad: SkirmishSquad) -> bool:
	var home: float = squad.home_distance * CELLS
	for unit in squad.living():
		if absf(squad.route.distance_of(ScrumReach.at(squad, unit)) - home) >= HOME_CELLS:
			return false
	return true


## True if no standing enemy is near the squad and none pursues it.
static func _safe(squad: SkirmishSquad, squads: Array, foes: Array) -> bool:
	for other in squads:
		if other.pursuit.get("foe") == squad.id and not other.pursuit.get("returning", false):
			return false
	for unit in squad.living():
		var at := ScrumReach.at(squad, unit)
		for entry in foes:
			if ScrumReach.at(entry[1], entry[0]).distance_to(at) <= FormationRout.ENEMY_NEAR:
				return false
	return true


## Puts the squad's frame on its route where its units stand, facing home; its units walk
## to their places (a re-form) and it marches home on its order.
static func _reform_here(squad: SkirmishSquad, tick: int, events: Array) -> void:
	var total := 0.0
	var living := squad.living()
	for unit in living:
		total += squad.route.distance_of(ScrumReach.at(squad, unit))
	var mean := total / maxi(1, living.size()) / CELLS
	var lowest := minf(squad.home_distance, squad.front_distance)
	var highest := maxf(squad.home_distance, squad.front_distance)
	squad.front_distance = clampf(mean, lowest, highest)
	squad.withdraw = {}
	ScrumTurn.begin(squad, -1 if squad.home_distance < squad.front_distance else 1, tick, events)
	events.append(FormationEvents.squad_event("regrouping", tick, squad))
