class_name FormationEdges
extends RefCounted
## Fights on a squad's sides and rear (Decision 78, spec 27 round 2). An attacker whose
## front reaches a hostile squad's side or rear face locks on (a flank lock): the victim
## records the contact on that edge, stops, and the units on the edge turn in place and
## fight back. The attacker's blows are flank blows for the first attack interval. A unit
## on the victim's front rank that is fighting its front foe strikes only there (a corner
## strikes back at one foe). A flank lock ends when the attacker's front no longer reaches
## the face (the edge's units fell back inward), and the attacker advances to it again.
## Pure over the squads it is given; FormationSimulation calls it each tick.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadEdges = preload("res://sim/skirmish/formation/squad_edges.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadGeometry = preload("res://sim/skirmish/formation/squad_geometry.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")

const EPSILON := 0.000001
## How far past a face's end (cells) a unit still meets it: only units in contact strike,
## the ones overlapping the face or touching its corner (Decision 78).
const CONTACT_SLACK := 0.5


## Free attackers whose fronts reach a hostile's side or rear lock on.
static func engage(squads: Array, tick: int, events: Array) -> void:
	for attacker in squads:
		if not _free(attacker):
			continue
		for victim in squads:
			if victim.faction_id == attacker.faction_id or not _reaches(attacker, victim):
				continue
			var edge := SquadEdges.edge_hit(victim, attacker.facing)
			FormationLocks.lock(attacker, victim)
			victim.flank_contacts[edge] = {"foe": attacker.id, "since": tick}
			if victim.state != SkirmishSquad.State.TURNING:
				victim.state = SkirmishSquad.State.FIGHTING
			for unit in SquadEdges.edge_units(victim, edge):
				unit.attack_cooldown = 1
			var extra := {"by": attacker.id, "edge": edge}
			events.append(FormationEvents.squad_event("flanked", tick, victim, extra))
			break


## True if the attacker's lock on `foe` is a flank lock.
static func is_flanking(attacker: SkirmishSquad, foe: SkirmishSquad) -> bool:
	return foe.flank_contacts.values().any(func(c): return c["foe"] == attacker.id)


## This tick's blows on every flanked edge, both ways: [[attacker, target, damage, flank]].
static func blows(squads: Array, interval: int, tick: int) -> Array:
	var by_id := {}
	for entry in squads:
		by_id[entry.id] = entry
	var out := []
	for victim in squads:
		var struck := {}  # victim units already striking this tick
		var edges: Array = victim.flank_contacts.keys()
		edges.sort()
		for edge in edges:
			var contact: Dictionary = victim.flank_contacts[edge]
			var attacker: SkirmishSquad = by_id.get(contact["foe"])
			if attacker == null or attacker.state != SkirmishSquad.State.FIGHTING:
				continue
			var fresh: bool = tick - contact["since"] < interval
			var on_edge := SquadEdges.edge_units(victim, edge)
			var facing: int = attacker.facing
			for fighter in attacker.fighters():
				var aim := [on_edge, victim, facing]
				_strike(fighter, attacker, aim, fresh, interval, out)
			for unit in on_edge:
				if struck.has(unit) or _busy_in_front(victim, unit):
					continue
				struck[unit] = true
				var back := [attacker.fighters(), attacker, facing]
				_strike(unit, victim, back, false, interval, out)
	return out


## Ends flank locks whose attacker is gone, retreating, or no longer reaches the face.
static func prune(squads: Array, tick: int, events: Array) -> void:
	var by_id := {}
	for entry in squads:
		by_id[entry.id] = entry
	for victim in squads:
		for edge in victim.flank_contacts.keys():
			var attacker: SkirmishSquad = by_id.get(victim.flank_contacts[edge]["foe"])
			if attacker != null and not victim.is_destroyed() and _holds(attacker, victim):
				continue
			victim.flank_contacts.erase(edge)
			if attacker != null and attacker.engaged_with == victim.id:
				attacker.engaged_with = 0
				if attacker.state == SkirmishSquad.State.FIGHTING:
					attacker.state = SkirmishSquad.State.MOVING
				events.append(FormationEvents.squad_event("flank_released", tick, attacker))
		var idle: bool = victim.flank_contacts.is_empty() and victim.engaged_with == 0
		if idle and victim.state == SkirmishSquad.State.FIGHTING:
			victim.state = SkirmishSquad.State.MOVING


static func _free(attacker: SkirmishSquad) -> bool:
	return (
		FormationContact.can_engage(attacker)
		and attacker.engaged_with == 0
		and attacker.state != SkirmishSquad.State.TURNING
	)


## True if the attacker's front reaches a hostile's side or rear face, overlapping it.
static func _reaches(attacker: SkirmishSquad, victim: SkirmishSquad) -> bool:
	if not FormationContact.can_engage(victim) or victim.is_destroyed():
		return false
	if SquadGeometry.facing_off(attacker, victim):
		return false  # front to front: FormationContact's frontal lock
	var gap := SquadEdges.face_gap(attacker, victim)
	return (
		gap > -EPSILON
		and gap <= FormationContact.MELEE_REACH + EPSILON
		and SquadEdges.overlap_across(attacker, victim)
	)


## True while a flank lock still holds: the attacker fights it and still reaches the face.
static func _holds(attacker: SkirmishSquad, victim: SkirmishSquad) -> bool:
	if attacker.engaged_with != victim.id or attacker.order == SkirmishUnit.Order.RETREAT:
		return false
	var gap := SquadEdges.face_gap(attacker, victim)
	return (
		gap <= FormationContact.MELEE_REACH + EPSILON
		and SquadEdges.overlap_across(attacker, victim)
	)


static func _busy_in_front(squad: SkirmishSquad, unit: SkirmishUnit) -> bool:
	return squad.engaged_with != 0 and unit.rank == 0


## One unit's strike. aim = [targets, their squad, the facing whose lateral axis matches
## them]: it strikes the target it overlaps most across that axis, or one whose corner it
## touches; with none in contact it doesn't strike. Counts down its cooldown and adds a
## blow when it lands.
static func _strike(
	unit: SkirmishUnit, own: SkirmishSquad, aim: Array, flank: bool, interval: int, out: Array
) -> void:
	var target := _pick(unit, own, aim)
	if target == null:
		return
	unit.target_id = target.id
	unit.attack_cooldown -= 1
	if unit.attack_cooldown > 0:
		return
	unit.attack_cooldown = interval
	out.append([unit, target, FormationCombat.damage(unit, flank), flank])


static func _pick(unit: SkirmishUnit, own: SkirmishSquad, aim: Array) -> SkirmishUnit:
	var facing: int = aim[2]
	var span := SquadFrame.lateral_interval(_rect(own, unit), facing)
	var best: SkirmishUnit = null
	var best_key := INF
	for target in aim[0]:
		var other := SquadFrame.lateral_interval(_rect(aim[1], target), facing)
		var overlap := minf(span.y, other.y) - maxf(span.x, other.x)
		var key := -overlap if overlap > EPSILON else maxf(other.x - span.y, span.x - other.y)
		if key < best_key - EPSILON:
			best = target
			best_key = key
	return best if best_key <= CONTACT_SLACK + EPSILON else null


static func _rect(squad: SkirmishSquad, unit: SkirmishUnit) -> Rect2:
	return SquadFrame.unit_rect(squad.position, squad.facing, squad.width, squad.centre_shift, unit)
