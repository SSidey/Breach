class_name FormationCarry
extends RefCounted
## Bearing the wounded (Decision 126). A formation told to tend its downed - "recover" or
## "carry" - has a free unit beside each friendly downed body pick it up, while it isn't
## fighting and no foe is near the body: the nearest free unit that can still move under
## it. The body is load (wounds_body_weight a cell of it), slowing and tiring its bearer.
## "recover": the bearer sets off home with it alone (FormationStrays), and when it gets
## there both return to the reserve; "carry": the bearer keeps its place, bearing it on.
## A bearer that falls drops its body where it stands; a body that comes to is set down.
## A borne body still comes to, or dies of its wounds (FormationRecovery). Pure over the
## squads it is given.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitArms = preload("res://content/definitions/unit_arms.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const BodyGrid = preload("res://sim/skirmish/formation/body_grid.gd")


## One tick: bodies follow their bearers, are dropped or set down, come home with them,
## and are picked up. `events` are this tick's so far (a bearer's "fled_home"). Returns
## [[bearer, its squad], ...] setting off home alone with a body.
static func step(squads: Array, tick: int, fight_seed: int, events: Array) -> Array:
	var units := {}  # unit id -> [unit, its squad]
	for squad in squads:
		for unit in squad.units:
			units[unit.id] = [unit, squad]
	_bring_home(units, tick, events)
	for unit_id in units:
		_follow(units[unit_id][0], units)
	return _pick_up(squads, units, tick, fight_seed, events)


## The weight its body is, borne.
static func body_weight(body: SkirmishUnit) -> float:
	return body.footprint_width * body.footprint_depth * BattleTuning.current().wounds_body_weight


## Bodies whose bearers fled home this tick come home too.
static func _bring_home(units: Dictionary, tick: int, events: Array) -> void:
	var homes := events.filter(func(e): return e["type"] == "fled_home")
	if homes.is_empty():
		return
	var borne := {}  # bearer id -> the ids of the bodies it bears, in the units' order
	for unit_id in units:
		var body: SkirmishUnit = units[unit_id][0]
		if body.state == SkirmishUnit.State.CARRIED:
			if not borne.has(body.carried_by):
				borne[body.carried_by] = []
			borne[body.carried_by].append(unit_id)
	for event in homes:
		for unit_id in borne.get(event["unit"], []):
			var body: SkirmishUnit = units[unit_id][0]
			if body.state == SkirmishUnit.State.CARRIED and body.carried_by == event["unit"]:
				units[unit_id][1].units.erase(body)
				var extra := {"unit": body.id, "definition": body.definition}
				events.append(
					FormationEvents.squad_event("fled_home", tick, units[unit_id][1], extra)
				)


## A body follows its bearer; a bearer down drops it, and one come to is set down.
static func _follow(unit: SkirmishUnit, units: Dictionary) -> void:
	if unit.state == SkirmishUnit.State.CARRIED:
		var bearer: SkirmishUnit = units[unit.carried_by][0] if units.has(unit.carried_by) else null
		if bearer == null or not bearer.is_alive():
			unit.state = SkirmishUnit.State.DOWNED  # dropped where it is
			unit.carried_by = 0
		else:
			unit.position = bearer.position
	if unit.carrying != 0:
		var body: SkirmishUnit = units[unit.carrying][0] if units.has(unit.carrying) else null
		if body == null or body.state != SkirmishUnit.State.CARRIED or not unit.is_alive():
			unit.carrying = 0
			_bear(unit, null)


static func _pick_up(
	squads: Array, units: Dictionary, tick: int, fight_seed: int, events: Array
) -> Array:
	var reach := BattleTuning.current().wounds_reach
	var strays := []
	var near := {}  # the living found by where they stand (BodyGrid), made when first needed
	for squad in squads:
		if (
			squad.tends == ""
			or squad.state in [SkirmishSquad.State.FIGHTING, SkirmishSquad.State.ROUTING]
		):
			continue
		for unit_id in units:
			var body: SkirmishUnit = units[unit_id][0]
			if body.state != SkirmishUnit.State.DOWNED or body.faction_id != squad.faction_id:
				continue
			if _foe_near(body, units, near):
				continue
			var bearer := _bearer(squad, body, reach, [fight_seed, near])
			if bearer == null:
				continue
			body.state = SkirmishUnit.State.CARRIED
			body.carried_by = bearer.id
			bearer.carrying = body.id
			_bear(bearer, body)
			events.append(
				FormationEvents.unit_event("borne", tick, squad, bearer, {"body": body.id})
			)
			if squad.tends == "recover":
				strays.append([bearer, squad])
	return strays


## The nearest free unit of the squad beside the body that can still move bearing it.
## `drawn`: [the battle seed, the living found by where they stand (_near)].
static func _bearer(
	squad: SkirmishSquad, body: SkirmishUnit, reach: float, drawn: Array
) -> SkirmishUnit:
	var fight_seed: int = drawn[0]
	var near: Dictionary = drawn[1]
	if not near.has(squad):
		var living := squad.living()
		near[squad] = [living, BodyGrid.build(living.map(func(u): return u.position))]
	var best: SkirmishUnit = null
	var best_key := []
	for found in BodyGrid.near(near[squad][1], body.position, reach + BodyGrid.MARGIN):
		var unit: SkirmishUnit = near[squad][0][found]
		var gap := unit.position.distance_to(body.position)
		if unit.carrying != 0 or gap > reach or _stage(unit, body) >= 3:
			continue
		var key := [snappedf(gap, 0.000001), ScrumContest.draw(unit, fight_seed)]
		if best == null or key < best_key:
			best = unit
			best_key = key
	return best


## True if a living foe stands within wounds_guard_reach of the body. `near` keeps the
## living found by where they stand, made the first time it is asked.
static func _foe_near(body: SkirmishUnit, units: Dictionary, near: Dictionary) -> bool:
	var guard := BattleTuning.current().wounds_guard_reach
	if not near.has("alive"):
		var alive := units.values().map(func(entry): return entry[0])
		alive = alive.filter(func(unit): return unit.is_alive())
		near["alive"] = [alive, BodyGrid.build(alive.map(func(u): return u.position))]
	for found in BodyGrid.near(near["alive"][1], body.position, guard + BodyGrid.MARGIN):
		var other: SkirmishUnit = near["alive"][0][found]
		if other.faction_id != body.faction_id:
			if other.position.distance_to(body.position) <= guard:
				return true
	return false


## Its load stage bearing `body` (null: none).
static func _stage(unit: SkirmishUnit, body: SkirmishUnit) -> int:
	var weight := unit.gear_weight + (body_weight(body) if body != null else 0.0)
	var strength := int(unit.attributes.get("strength", 10))
	return UnitArms.stage_of(weight, strength, int(unit.traits.get("hauler", 0)))


## Sets the unit's pace, tiring and dodge for its load bearing `body` (null: none).
static func _bear(unit: SkirmishUnit, body: SkirmishUnit) -> void:
	var tuning := BattleTuning.current()
	var stage := _stage(unit, body)
	var march: float = unit.definition.speed if unit.definition != null else unit.fresh_speed
	unit.load_stage = stage
	unit.fresh_speed = march * tuning.load_pace[stage]
	unit.tiring = tuning.load_tiring[stage]
	unit.dodging = tuning.load_dodge[stage]
