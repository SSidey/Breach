class_name FormationSimulation
extends RefCounted
## One lane of the formation feel test (specs/22-formation-feel-test.md, Decision 40):
## squads of both factions on one route. Deterministic - every phase iterates squads and
## units in id order, and blows land simultaneously.
##
## step() runs one tick in this fixed order:
##   1. orders  - queued wave orders apply (a retreat disengages at once)
##   2. engage  - hostile squads whose fronts are within MELEE_REACH lock together
##   3. move    - free squads move as a block at their slowest unit's speed, stopping at
##                contact or behind a friendly squad; one that reaches a friendly squad
##                in combat joins it from the back (Decision 44); reaching the enemy end
##                is arrival (the fort is immune)
##   4. combat  - each squad's front-rank fighters strike: the enemy fighter they overlap
##                laterally, or - past the end of a narrower enemy line - the nearest end
##                fighter as a flank attack (x FLANK_BONUS). A unit struck by several foes
##                takes every blow but strikes back at only one. Ranged units strike the
##                nearest enemy in range from anywhere in their squad (Decision 46)
##   5. deaths  - the fallen die, the ranks behind step up, and a squad with no one left
##                is destroyed, freeing whoever fought it
##   6. re-form - a reinforced squad's units swap toward their preferred places
##                (FormationShuffle, Decision 46)
## Timing constants match the spec 21 SkirmishSimulation, so a 1v1 plays out the same.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationShuffle = preload("res://sim/skirmish/formation/formation_shuffle.gd")

const MELEE_REACH := FormationContact.MELEE_REACH
const ATTACK_INTERVAL_SECONDS := 1.0
const TRAVEL_SCALE := 0.5
const EPSILON := 0.000001

var route_length: float
var tick_seconds: float

var _squads: Array[SkirmishSquad] = []
var _next_squad_id := 1
var _next_unit_id := 1
var _pending_orders := {}  # squad id -> SkirmishUnit.Order
var _tick := 0


func _init(length: float, seconds_per_tick: float) -> void:
	route_length = length
	tick_seconds = seconds_per_tick


## placements: [[UnitDef, Vector2i(rank, column)], ...] from a WaveTemplate layout.
func spawn_squad(
	width: int, placements: Array, faction_id: String, at_player_end: bool, wait_ticks: int = 0
) -> SkirmishSquad:
	var direction := 1 if at_player_end else -1
	var home := 0.0 if at_player_end else route_length
	var members: Array[SkirmishUnit] = []
	for placement in placements:
		members.append(_unit(placement[0], placement[1], faction_id, direction))
	var squad := SkirmishSquad.new(_next_squad_id, faction_id, direction, home, width, members)
	_next_squad_id += 1
	squad.wait_ticks = wait_ticks
	_squads.append(squad)
	_sync_unit_distances()
	return squad


## Takes effect on the next step(), whether or not the clock is paused now.
func order(squad_id: int, new_order: SkirmishUnit.Order) -> void:
	_pending_orders[squad_id] = new_order


func squads() -> Array[SkirmishSquad]:
	return _squads


func squad(squad_id: int) -> SkirmishSquad:
	for entry in _squads:
		if entry.id == squad_id:
			return entry
	return null


func tick_number() -> int:
	return _tick


func step() -> Array:
	_tick += 1
	var events := []
	_apply_orders(events)
	_engage(events)
	_move(events)
	_fight(events)
	_bury(events)
	for entry in _squads:
		events.append_array(FormationShuffle.step(entry, tick_seconds, TRAVEL_SCALE, _tick))
	_sync_unit_distances()
	return events


func _unit(unit_def: UnitDef, place: Vector2i, faction_id: String, direction: int) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.id = _next_unit_id
	_next_unit_id += 1
	unit.faction_id = faction_id
	unit.hp = unit_def.hp
	unit.max_hp = unit_def.hp
	unit.dmg = unit_def.dmg
	unit.speed = unit_def.speed
	unit.footprint_depth = unit_def.footprint_depth
	unit.footprint_width = unit_def.footprint_width
	unit.preferred_position = unit_def.preferred_position
	unit.position_priority = unit_def.position_priority
	unit.attack_range = unit_def.attack_range
	unit.rank = place.x
	unit.column = place.y
	unit.advance_direction = direction
	return unit


func _apply_orders(events: Array) -> void:
	var ids := _pending_orders.keys()
	ids.sort()
	for squad_id in ids:
		var target := squad(squad_id)
		if target == null or target.state == SkirmishSquad.State.DESTROYED:
			continue
		target.order = _pending_orders[squad_id]
		var order_name: String = SkirmishUnit.Order.keys()[target.order]
		events.append(
			FormationEvents.squad_event("order_applied", _tick, target, {"order": order_name})
		)
		if target.order == SkirmishUnit.Order.RETREAT and target.engaged_with != 0:
			_release(target)
			events.append(FormationEvents.squad_event("disengaged", _tick, target))
	_pending_orders.clear()


func _engage(events: Array) -> void:
	for attacker in _squads:
		if not FormationContact.can_engage(attacker) or attacker.engaged_with != 0:
			continue
		var foe := FormationContact.nearest_hostile(attacker, _squads)
		if foe == null:
			continue
		_lock(attacker, foe)
		if foe.engaged_with == 0:
			_lock(foe, attacker)
		events.append(FormationEvents.squad_event("engaged", _tick, attacker, {"with": foe.id}))


func _lock(squad_entry: SkirmishSquad, foe: SkirmishSquad) -> void:
	squad_entry.engaged_with = foe.id
	squad_entry.state = SkirmishSquad.State.FIGHTING
	for unit in squad_entry.living():
		unit.attack_cooldown = 1  # the first blows land this tick


func _move(events: Array) -> void:
	var joins := []  # [leader, joining]
	for mover in _squads:
		if mover.state in [SkirmishSquad.State.DESTROYED, SkirmishSquad.State.FIGHTING]:
			continue
		if mover.state == SkirmishSquad.State.ARRIVED:
			continue
		if mover.wait_ticks > 0:
			mover.wait_ticks -= 1
			continue
		if mover.order == SkirmishUnit.Order.HOLD:
			mover.state = SkirmishSquad.State.HOLDING
			continue
		mover.state = SkirmishSquad.State.MOVING
		var advancing := mover.order == SkirmishUnit.Order.ADVANCE
		var direction := mover.direction if advancing else -mover.direction
		var step := mover.speed() * TRAVEL_SCALE * tick_seconds
		var next := clampf(mover.front_distance + direction * step, 0.0, route_length)
		if advancing:
			next = FormationContact.limit(mover, _squads, next)
		mover.front_distance = next
		var leader := FormationContact.joinable(mover, _squads) if advancing else null
		if leader != null:
			joins.append([leader, mover])
		_check_ends(mover, events)
	for pair in joins:
		_join(pair[0], pair[1], events)


## A wave reaching a friendly squad in combat becomes its rear ranks (Decision 44).
func _join(leader: SkirmishSquad, joining: SkirmishSquad, events: Array) -> void:
	events.append(FormationEvents.squad_event("reinforced", _tick, joining, {"into": leader.id}))
	for moved in FormationContact.reinforce(leader, joining):
		events.append(
			FormationEvents.unit_event("stepped_up", _tick, leader, moved, {"rank": moved.rank})
		)
	_squads.erase(joining)
	leader.reforming = true


func _fight(events: Array) -> void:
	for entry in _squads:
		for unit in entry.living():
			unit.target_id = 0
	var blows := []  # [attacker, target, damage, flank]
	for attacker_squad in _squads:
		if attacker_squad.state != SkirmishSquad.State.FIGHTING:
			continue
		var foe := squad(attacker_squad.engaged_with)
		if foe == null or foe.is_destroyed():
			continue
		var foe_fighters := foe.fighters()
		for fighter in attacker_squad.fighters():
			var pick := FormationCombat.pick_target(attacker_squad, fighter, foe, foe_fighters)
			if pick.is_empty():
				continue
			fighter.target_id = pick[0].id
			fighter.attack_cooldown -= 1
			if fighter.attack_cooldown <= 0:
				fighter.attack_cooldown = _attack_interval_ticks()
				var damage := FormationCombat.damage(fighter, pick[1])
				blows.append([fighter, pick[0], damage, pick[1]])
	var shots := FormationCombat.ranged_blows(_squads, _attack_interval_ticks())
	for shot in shots:
		shot[1].hp -= shot[2]
		var spat := {"target": shot[1].id, "dmg": shot[2]}
		events.append(FormationEvents.unit_event("spat", _tick, shot[3], shot[0], spat))
	for blow in blows:
		blow[1].hp -= blow[2]
		events.append(FormationEvents.hit(_tick, blow))


func _bury(events: Array) -> void:
	for fallen_squad in _squads:
		var deaths := 0
		for unit in fallen_squad.living():
			if unit.hp <= 0:
				unit.state = SkirmishUnit.State.DEAD
				deaths += 1
				events.append(FormationEvents.unit_event("died", _tick, fallen_squad, unit))
		if deaths == 0:
			continue
		for moved in fallen_squad.compact():
			events.append(
				FormationEvents.unit_event(
					"stepped_up", _tick, fallen_squad, moved, {"rank": moved.rank}
				)
			)
		if fallen_squad.is_destroyed() and fallen_squad.state != SkirmishSquad.State.DESTROYED:
			fallen_squad.state = SkirmishSquad.State.DESTROYED
			_release(fallen_squad)
			events.append(FormationEvents.squad_event("destroyed", _tick, fallen_squad))


## Ends a squad's fight and frees every squad that was fighting it.
func _release(released: SkirmishSquad) -> void:
	released.engaged_with = 0
	if released.state != SkirmishSquad.State.DESTROYED:
		released.state = SkirmishSquad.State.MOVING
	for other in _squads:
		if other.engaged_with == released.id:
			other.engaged_with = 0
			if other.state != SkirmishSquad.State.DESTROYED:
				other.state = SkirmishSquad.State.MOVING


func _check_ends(mover: SkirmishSquad, events: Array) -> void:
	var enemy_end := route_length if mover.direction > 0 else 0.0
	if (
		mover.order == SkirmishUnit.Order.ADVANCE
		and is_equal_approx(mover.front_distance, enemy_end)
	):
		mover.front_distance = enemy_end
		mover.state = SkirmishSquad.State.ARRIVED  # the enemy fort is immune in the feel test
		events.append(FormationEvents.squad_event("arrived", _tick, mover))
	elif (
		mover.order == SkirmishUnit.Order.RETREAT
		and is_equal_approx(mover.front_distance, mover.home_distance)
	):
		mover.front_distance = mover.home_distance
		mover.order = SkirmishUnit.Order.HOLD
		mover.state = SkirmishSquad.State.HOLDING
		events.append(FormationEvents.squad_event("returned", _tick, mover))


## Units mirror their squad's placement - including any swap under way - so views can
## read unit.distance.
func _sync_unit_distances() -> void:
	for entry in _squads:
		for unit in entry.units:
			var swapping := FormationShuffle.offset(entry, unit) * SkirmishSquad.RANK_DEPTH
			unit.distance = entry.unit_distance(unit) + entry.direction * swapping


func _attack_interval_ticks() -> int:
	return maxi(1, roundi(ATTACK_INTERVAL_SECONDS / tick_seconds))
