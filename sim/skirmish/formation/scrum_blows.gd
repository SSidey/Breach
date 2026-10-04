class_name ScrumBlows
extends RefCounted
## Melee blows in the scrum (Decision 88, spec 27 round 5): every unit of a fighting squad
## strikes one enemy it touches (ScrumReach), on a face or a corner - one in its front
## first, then the nearest, then the lowest id. A blow from outside the target's front, or
## on a turning squad, is a flank blow. Blows land together; then each unit whose target
## stood outside its front turns to it, so a unit fighting one foe is flanked by a second.
## Routing squads are left to FormationRout. Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")


## This tick's blows: [[attacker, target, damage, flank], ...]. Updates each striker's
## target, cooldown and facing.
static func blows(squads: Array, interval: int) -> Array:
	var out := []
	var turns := []  # [unit, facing]
	for squad in squads:
		if squad.state != SkirmishSquad.State.FIGHTING:
			continue
		var pace := FormationMorale.interval(squad, interval)
		var foes := _hostile(squad, squads)
		for unit in squad.living():
			var pick := _pick(squad, unit, foes)
			if pick.is_empty():
				continue
			var target: SkirmishUnit = pick[0]
			var where := ScrumReach.at(squad, unit)
			var target_at: Vector2 = pick[2]
			if not ScrumReach.in_front(unit.facing, where, target_at):
				turns.append([unit, ScrumReach.facing_to(where, target_at)])
			unit.target_id = target.id
			unit.attack_cooldown -= 1
			if unit.attack_cooldown > 0:
				continue
			unit.attack_cooldown = pace
			var target_squad: SkirmishSquad = pick[1]
			var flank := (
				target_squad.state == SkirmishSquad.State.TURNING
				or not ScrumReach.in_front(target.facing, target_at, where)
			)
			out.append([unit, target, FormationCombat.damage(unit, flank), flank])
	for turn in turns:
		turn[0].facing = turn[1]
	return out


## True if the unit touches a living unit of any of `foes` ([[unit, squad], ...]).
static func touches_any(squad: SkirmishSquad, unit: SkirmishUnit, foes: Array) -> bool:
	var mine := ScrumReach.area(squad, unit)
	for entry in foes:
		if ScrumReach.touching(mine, ScrumReach.area(entry[1], entry[0])):
			return true
	return false


## [[unit, squad], ...] for the living units of squads hostile to `squad`, but not routing.
static func _hostile(squad: SkirmishSquad, squads: Array) -> Array:
	var out := []
	for other in squads:
		if other.faction_id == squad.faction_id:
			continue
		if other.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
			continue
		for unit in other.living():
			out.append([unit, other])
	return out


## [target, its squad, where it stands] for the enemy the unit strikes; [] if it touches none.
static func _pick(squad: SkirmishSquad, unit: SkirmishUnit, foes: Array) -> Array:
	var mine := ScrumReach.area(squad, unit)
	var where := ScrumReach.at(squad, unit)
	var best := []
	var best_key := []
	for entry in foes:
		var other: SkirmishUnit = entry[0]
		if not ScrumReach.touching(mine, ScrumReach.area(entry[1], other)):
			continue
		var there := ScrumReach.at(entry[1], other)
		var front := 0 if ScrumReach.in_front(unit.facing, where, there) else 1
		var key := [front, where.distance_to(there), other.id]
		if best.is_empty() or key < best_key:
			best = [other, entry[1], there]
			best_key = key
	return best
