class_name FormationSimulation
extends RefCounted
## The formation fight (specs/22-formation-feel-test.md, Decision 40): squads of both
## factions, each on its route (spec 27). Deterministic - every phase iterates squads and
## units in id order, and blows land simultaneously.
##
## step() runs one tick in this fixed order:
##   1. orders  - queued wave orders apply (a retreat disengages at once)
##   2. engage  - hostile squads whose fronts are within MELEE_REACH lock together, and a
##                free squad whose front reaches a hostile's side or rear locks onto that
##                edge (FormationEdges, Decision 78)
##   3. move    - a squad that must face another way turns first, standing (an about-face
##                to go back the way it faces, a wheel where its route bends: Decision
##                74); free squads move as a block at their slowest unit's speed (one with no
##                front units holds once an enemy is in its ranged reach), stopping at
##                contact or behind a friendly squad; one that reaches a friendly squad
##                in combat joins it from the back (Decision 44), as does one that merges
##                into a friendly squad on the march (Decision 51); reaching the enemy end
##                is arrival (the fort is immune)
##   4. combat  - each squad's front-rank fighters strike: the enemy fighter they overlap
##                laterally, or - past the end of a narrower enemy line - the nearest end
##                fighter as a flank attack (x FLANK_BONUS). A unit struck by several foes
##                takes every blow but strikes back at only one. Ranged units strike the
##                nearest enemy in range from anywhere in their squad (Decision 46)
##   5. deaths  - the fallen die, the ranks behind step up, and a squad with no one left
##                is destroyed, freeing whoever fought it
##   6. re-form - a reinforced squad's units swap toward their preferred places, and in a
##                fight its joined units spread across the combat width (FormationShuffle,
##                Decisions 46 and 51)
## Timing constants match the spec 21 SkirmishSimulation, so a 1v1 plays out the same.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationShuffle = preload("res://sim/skirmish/formation/formation_shuffle.gd")
const FormationUnits = preload("res://sim/skirmish/formation/formation_units.gd")
const FormationMarch = preload("res://sim/skirmish/formation/formation_march.gd")
const FormationTurning = preload("res://sim/skirmish/formation/formation_turning.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationEdges = preload("res://sim/skirmish/formation/formation_edges.gd")
const FormationWings = preload("res://sim/skirmish/formation/formation_wings.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const MELEE_REACH := FormationContact.MELEE_REACH
const ATTACK_INTERVAL_SECONDS := 1.0
const TRAVEL_SCALE := 0.125  # tiles per second at speed 1: 8 cells a second (Decision 68)
const EPSILON := 0.000001

var route_length: float
var tick_seconds: float
## The lane's width, which squads spawned from now on may spread to (Decision 51); 0 keeps
## each squad within its own columns.
var combat_width := 0
## Overlapping front units walk round an enemy line's end (Decision 81) rather than wrap.
var walk_wings := false

var _route: FormationRoute
var _squads: Array[SkirmishSquad] = []
var _next_squad_id := 1
var _next_unit_id := 1
var _pending_orders := {}  # squad id -> SkirmishUnit.Order
var _tick := 0


func _init(length: float, seconds_per_tick: float) -> void:
	route_length = length
	tick_seconds = seconds_per_tick
	_route = FormationRoute.straight(length * MapLayoutDef.CELLS_PER_TILE)


## placements: [[UnitDef, Vector2i(rank, column)], ...] from a WaveTemplate layout. The
## squad follows `route` (Decision 75), or the lane's straight route if null.
func spawn_squad(
	width: int,
	placements: Array,
	faction_id: String,
	at_player_end: bool,
	wait_ticks: int = 0,
	route: FormationRoute = null
) -> SkirmishSquad:
	var path := route if route != null else _route
	var direction := 1 if at_player_end else -1
	var home := 0.0 if at_player_end else path.length_cells() / MapLayoutDef.CELLS_PER_TILE
	var members: Array[SkirmishUnit] = []
	for placement in placements:
		members.append(
			FormationUnits.make(placement[0], placement[1], faction_id, direction, _next_unit_id)
		)
		_next_unit_id += 1
	var squad := SkirmishSquad.new(_next_squad_id, faction_id, direction, home, width, members)
	_next_squad_id += 1
	squad.route = path
	FormationMarch.face(squad)
	squad.wait_ticks = wait_ticks
	squad.combat_width = combat_width
	_squads.append(squad)
	FormationMarch.sync_units(_squads)
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
	if walk_wings:
		var pace := TRAVEL_SCALE * MapLayoutDef.CELLS_PER_TILE
		events.append_array(FormationWings.march(_squads, _tick, pace, tick_seconds))
	_fight(events)
	_bury(events)
	FormationEdges.prune(_squads, _tick, events)
	for entry in _squads:
		events.append_array(FormationShuffle.step(entry, tick_seconds, TRAVEL_SCALE, _tick))
	FormationMarch.sync_units(_squads)
	return events


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
			FormationLocks.release(target, _squads)
			events.append(FormationEvents.squad_event("disengaged", _tick, target))
	_pending_orders.clear()


func _engage(events: Array) -> void:
	for attacker in _squads:
		if not FormationContact.can_engage(attacker) or attacker.engaged_with != 0:
			continue
		if attacker.state == SkirmishSquad.State.TURNING:
			continue  # it turns first (Decision 74)
		var foe := FormationContact.nearest_hostile(attacker, _squads)
		if foe == null:
			continue
		FormationLocks.lock(attacker, foe)
		if foe.engaged_with == 0:
			FormationLocks.lock(foe, attacker)
		events.append(FormationEvents.squad_event("engaged", _tick, attacker, {"with": foe.id}))
	FormationEdges.engage(_squads, _tick, events)


func _move(events: Array) -> void:
	var joins := []  # [leader, joining]
	for mover in _squads:
		if FormationTurning.step(mover, _tick, events):
			continue
		if mover.state in [SkirmishSquad.State.DESTROYED, SkirmishSquad.State.FIGHTING]:
			continue
		if mover.state == SkirmishSquad.State.ARRIVED:
			continue
		if mover.wait_ticks > 0:
			mover.wait_ticks -= 1
			continue
		if mover.order == SkirmishUnit.Order.HOLD or FormationContact.skirmishing(mover, _squads):
			mover.state = SkirmishSquad.State.HOLDING
			continue
		mover.state = SkirmishSquad.State.MOVING
		var advancing := mover.order == SkirmishUnit.Order.ADVANCE
		var end := FormationMarch.length(mover, route_length)
		var travel := FormationMarch.travel_sign(mover, end)
		var step := mover.speed() * TRAVEL_SCALE * tick_seconds
		if _turns_first(mover, travel, events):
			continue
		var next := clampf(mover.front_distance + travel * step, 0.0, end)
		if advancing:
			next = FormationContact.limit(mover, _squads, next)
		mover.front_distance = next
		var leader := FormationContact.joinable(mover, _squads) if advancing else null
		if leader != null:
			joins.append([leader, mover])
		FormationMarch.check_ends(mover, end, _tick, events)
	for pair in joins:
		_join(pair[0], pair[1], events)


## True if the squad must turn before moving `travel` along its route: it starts the turn.
func _turns_first(mover: SkirmishSquad, travel: int, events: Array) -> bool:
	var cells_per_second := mover.speed() * TRAVEL_SCALE * MapLayoutDef.CELLS_PER_TILE
	if not FormationTurning.begin(mover, travel, cells_per_second, tick_seconds):
		return false
	events.append(FormationEvents.squad_event("turning", _tick, mover, {"facing": mover.turn_to}))
	return true


## A wave reaching a friendly squad in combat becomes its rear ranks (Decision 44); one
## merging on the march does the same (Decision 51).
func _join(leader: SkirmishSquad, joining: SkirmishSquad, events: Array) -> void:
	var kind := "reinforced" if leader.state == SkirmishSquad.State.FIGHTING else "merged"
	events.append(FormationEvents.squad_event(kind, _tick, joining, {"into": leader.id}))
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
		if foe == null or foe.is_destroyed() or FormationEdges.is_flanking(attacker_squad, foe):
			continue
		var foe_fighters := foe.fighters()
		for fighter in attacker_squad.fighters():
			var pick := FormationCombat.pick_target(attacker_squad, fighter, foe, foe_fighters)
			if pick.is_empty() or FormationWings.is_wing(attacker_squad, fighter):
				continue
			if pick[1] and walk_wings:
				continue  # past the line's end: it walks round instead (FormationWings)
			fighter.target_id = pick[0].id
			fighter.attack_cooldown -= 1
			if fighter.attack_cooldown <= 0:
				fighter.attack_cooldown = _attack_interval_ticks()
				var flank: bool = pick[1] or foe.state == SkirmishSquad.State.TURNING
				var damage := FormationCombat.damage(fighter, flank)
				blows.append([fighter, pick[0], damage, flank])
	blows.append_array(FormationEdges.blows(_squads, _attack_interval_ticks(), _tick))
	blows.append_array(FormationWings.blows(_squads, _attack_interval_ticks(), _tick))
	var shots := FormationCombat.ranged_blows(_squads, _attack_interval_ticks())
	for shot in shots:
		shot[1].hp -= shot[2]
		var spat := {"target": shot[1].id, "dmg": shot[2], "damage_type": shot[0].damage_type}
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
		var front_before := fallen_squad.front_distance
		for moved in fallen_squad.compact():
			events.append(
				FormationEvents.unit_event(
					"stepped_up", _tick, fallen_squad, moved, {"rank": moved.rank}
				)
			)
		fallen_squad.reforming = true  # front units may close gaps (Decision 49)
		if not is_equal_approx(front_before, fallen_squad.front_distance):
			# Its front fell: the enemy must advance (Decision 47).
			FormationLocks.release(fallen_squad, _squads)
			events.append(FormationEvents.squad_event("front_fell", _tick, fallen_squad))
		if fallen_squad.is_destroyed() and fallen_squad.state != SkirmishSquad.State.DESTROYED:
			fallen_squad.state = SkirmishSquad.State.DESTROYED
			FormationLocks.release(fallen_squad, _squads)
			events.append(FormationEvents.squad_event("destroyed", _tick, fallen_squad))


func _attack_interval_ticks() -> int:
	return maxi(1, roundi(ATTACK_INTERVAL_SECONDS / tick_seconds))
