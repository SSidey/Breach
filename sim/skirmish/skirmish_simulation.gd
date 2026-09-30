class_name SkirmishSimulation
extends RefCounted
## The real-time skirmish feel test's rules (specs/21-realtime-skirmish-feel-test.md,
## Decision 38): melee units of two factions on one route, advanced one fixed tick at a
## time. Deterministic - no randomness, and every phase iterates units in id order - so
## the same spawns and orders at the same ticks always replay identically.
##
## step() runs one tick in this fixed order:
##   1. orders    - queued player orders take effect (a retreat disengages at once)
##   2. engage    - units within MELEE_REACH of an engageable hostile lock on
##   3. move      - free units move speed x tick; they stop at contact rather than pass
##                  through a hostile, and arrive at the enemy end (the fort is immune)
##   4. combat    - fighting units whose cooldown is up strike; blows land simultaneously
##   5. deaths    - hp <= 0 dies and frees whoever was fighting it
## A retreating unit can't be engaged in v1 (a clean disengage), so a retreat always works.

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

## Cells between two units for them to fight.
const MELEE_REACH := 0.35
## Ticks between a unit's blows (4 at 0.25 s = one blow a second).
const ATTACK_COOLDOWN_TICKS := 4
const EPSILON := 0.000001

var route_length: float
var tick_seconds: float

var _units: Array[SkirmishUnit] = []
var _next_id := 1
var _pending_orders := {}  # unit id -> SkirmishUnit.Order
var _tick := 0


func _init(length: float, seconds_per_tick: float) -> void:
	route_length = length
	tick_seconds = seconds_per_tick


func spawn(
	unit_def: UnitDef, faction_id: String, at_player_end: bool, wait_ticks: int = 0
) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.id = _next_id
	_next_id += 1
	unit.faction_id = faction_id
	unit.hp = unit_def.hp
	unit.max_hp = unit_def.hp
	unit.dmg = unit_def.dmg
	unit.speed = unit_def.speed
	unit.home_distance = 0.0 if at_player_end else route_length
	unit.distance = unit.home_distance
	unit.advance_direction = 1 if at_player_end else -1
	unit.wait_ticks = wait_ticks
	_units.append(unit)
	return unit


## Takes effect on the next step(), whether or not the clock is paused now.
func order(unit_id: int, new_order: SkirmishUnit.Order) -> void:
	_pending_orders[unit_id] = new_order


func units() -> Array[SkirmishUnit]:
	return _units


func unit(unit_id: int) -> SkirmishUnit:
	for entry in _units:
		if entry.id == unit_id:
			return entry
	return null


func tick_number() -> int:
	return _tick


## One tick; returns what happened, in order, as plain dictionaries (for logs and replay).
func step() -> Array:
	_tick += 1
	var events := []
	_apply_orders(events)
	_engage(events)
	_move(events)
	_fight(events)
	_bury(events)
	return events


func _apply_orders(events: Array) -> void:
	var ids := _pending_orders.keys()
	ids.sort()
	for unit_id in ids:
		var target := unit(unit_id)
		if target == null or not target.is_alive():
			continue
		target.order = _pending_orders[unit_id]
		events.append(
			_event("order_applied", target, {"order": SkirmishUnit.Order.keys()[target.order]})
		)
		if target.order == SkirmishUnit.Order.RETREAT and target.target_id != 0:
			_release(target)
			events.append(_event("disengaged", target))
	_pending_orders.clear()


func _engage(events: Array) -> void:
	for attacker in _units:
		if not _can_engage(attacker) or attacker.target_id != 0:
			continue
		var foe := _nearest_engageable_hostile(attacker, MELEE_REACH)
		if foe == null:
			continue
		attacker.target_id = foe.id
		attacker.state = SkirmishUnit.State.FIGHTING
		attacker.attack_cooldown = 1  # the first blow lands this tick
		if foe.target_id == 0:
			foe.target_id = attacker.id
			foe.state = SkirmishUnit.State.FIGHTING
			foe.attack_cooldown = 1
		events.append(_event("engaged", attacker, {"with": foe.id}))


func _move(events: Array) -> void:
	for mover in _units:
		if (
			not mover.is_alive()
			or mover.state in [SkirmishUnit.State.FIGHTING, SkirmishUnit.State.ARRIVED]
		):
			continue
		if mover.wait_ticks > 0:
			mover.wait_ticks -= 1
			continue
		if mover.order == SkirmishUnit.Order.HOLD:
			mover.state = SkirmishUnit.State.HOLDING
			continue
		mover.state = SkirmishUnit.State.MOVING
		var direction := (
			mover.advance_direction
			if mover.order == SkirmishUnit.Order.ADVANCE
			else -mover.advance_direction
		)
		var next := clampf(
			mover.distance + direction * mover.speed * tick_seconds, 0.0, route_length
		)
		if mover.order == SkirmishUnit.Order.ADVANCE:
			next = _stop_at_contact(mover, next)
		mover.distance = next
		_check_ends(mover, events)


func _fight(events: Array) -> void:
	var blows := []  # [attacker, defender] - applied together so neither side strikes first
	for attacker in _units:
		if attacker.state != SkirmishUnit.State.FIGHTING:
			continue
		attacker.attack_cooldown -= 1
		if attacker.attack_cooldown <= 0:
			attacker.attack_cooldown = ATTACK_COOLDOWN_TICKS
			blows.append([attacker, unit(attacker.target_id)])
	for blow in blows:
		blow[1].hp -= blow[0].dmg
		events.append(
			_event(
				"hit", blow[0], {"target": blow[1].id, "dmg": blow[0].dmg, "target_hp": blow[1].hp}
			)
		)


func _bury(events: Array) -> void:
	for fallen in _units:
		if fallen.is_alive() and fallen.hp <= 0:
			fallen.state = SkirmishUnit.State.DEAD
			_release(fallen)
			events.append(_event("died", fallen))


## Clears a unit's fight and frees everyone who was fighting it (they carry on next tick).
func _release(released: SkirmishUnit) -> void:
	released.target_id = 0
	if released.is_alive():
		released.state = SkirmishUnit.State.MOVING
	for other in _units:
		if other.target_id == released.id:
			other.target_id = 0
			if other.is_alive():
				other.state = SkirmishUnit.State.MOVING


func _can_engage(candidate: SkirmishUnit) -> bool:
	return (
		candidate.is_alive()
		and candidate.state != SkirmishUnit.State.ARRIVED
		and candidate.order != SkirmishUnit.Order.RETREAT
		and candidate.wait_ticks == 0
	)


func _nearest_engageable_hostile(from: SkirmishUnit, reach: float) -> SkirmishUnit:
	var best: SkirmishUnit = null
	var best_gap := INF
	for other in _units:
		if other == from or not from.is_hostile_to(other) or not _can_engage(other):
			continue
		var gap := absf(other.distance - from.distance)
		if gap <= reach + EPSILON and gap < best_gap:
			best = other
			best_gap = gap
	return best


## An advancing unit stops at MELEE_REACH from the nearest engageable hostile ahead,
## so two units closing faster than the reach per tick still meet instead of passing.
func _stop_at_contact(mover: SkirmishUnit, next: float) -> float:
	var direction := mover.advance_direction
	for other in _units:
		if not mover.is_hostile_to(other) or not _can_engage(other):
			continue
		var ahead := (other.distance - mover.distance) * direction
		if ahead <= 0.0:
			continue
		var limit := other.distance - direction * MELEE_REACH
		next = minf(next, limit) if direction > 0 else maxf(next, limit)
	return next


func _check_ends(mover: SkirmishUnit, events: Array) -> void:
	var enemy_end := route_length if mover.advance_direction > 0 else 0.0
	if mover.order == SkirmishUnit.Order.ADVANCE and is_equal_approx(mover.distance, enemy_end):
		mover.state = SkirmishUnit.State.ARRIVED  # the enemy fort is immune in the feel test
		events.append(_event("arrived", mover))
	elif (
		mover.order == SkirmishUnit.Order.RETREAT
		and is_equal_approx(mover.distance, mover.home_distance)
	):
		mover.order = SkirmishUnit.Order.HOLD
		mover.state = SkirmishUnit.State.HOLDING
		events.append(_event("returned", mover))


func _event(kind: String, subject: SkirmishUnit, extra: Dictionary = {}) -> Dictionary:
	var event := {"type": kind, "tick": _tick, "unit": subject.id, "faction": subject.faction_id}
	event.merge(extra)
	return event
