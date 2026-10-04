class_name ScrumBlows
extends RefCounted
## Melee blows in the scrum (Decisions 88 and 95, spec 27 rounds 5 and 8): every unit of a
## fighting squad - and of any squad, at a retreating enemy - strikes one enemy it touches
## (ScrumReach), on a face or a corner: one in its front first, then the nearest, then by
## the battle's seeded draw (ScrumContest; never by id, Decision 97). A blow from outside
## the target's front, or on a turning squad, is a flank blow. Blows land together. Units
## turn to their foes at their turn rate as they move (FormationScrum, UnitMotion), so a
## unit fighting one foe is flanked by a second, and one turning away is struck from behind.
## Routing squads are left to FormationRout. Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const FormationDiscipline = preload("res://sim/skirmish/formation/formation_discipline.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")


## This tick's blows: [[attacker, target, damage, flank], ...]. Updates each striker's
## target and cooldown.
static func blows(squads: Array, interval: int, fight_seed: int) -> Array:
	var out := []
	for squad in squads:
		var foes := _struck_by(squad, squads)
		if foes.is_empty():
			continue
		var pace := FormationMorale.interval(squad, interval)
		for unit in squad.living():
			var pick := _pick(squad, unit, foes, fight_seed)
			if pick.is_empty():
				continue
			var target: SkirmishUnit = pick[0]
			var where := ScrumReach.at(squad, unit)
			var target_at: Vector2 = pick[2]
			unit.target_id = target.id
			unit.attack_cooldown -= 1
			if unit.attack_cooldown > 0:
				continue
			unit.attack_cooldown = pace
			var target_squad: SkirmishSquad = pick[1]
			var flank := (
				target_squad.state == SkirmishSquad.State.TURNING
				or not ScrumReach.in_front(target.bearing, target_at, where)
			)
			out.append([unit, target, FormationCombat.damage(unit, flank), flank])
	return out


## True if the unit touches a living unit of any of `foes` ([[unit, squad], ...]).
static func touches_any(squad: SkirmishSquad, unit: SkirmishUnit, foes: Array) -> bool:
	var mine := ScrumReach.area(squad, unit)
	for entry in foes:
		if ScrumReach.touching(mine, ScrumReach.area(entry[1], entry[0])):
			return true
	return false


## [[unit, squad], ...] for the living units of squads hostile to `squad`, but not routing.
## The enemies the squad's units strike when they touch them: any, for a squad fighting;
## for one retreating, any if it is drilled (a fighting withdrawal), else none; for any
## other, only the units of retreating squads - a retreat is struck as it goes (Decision 95).
static func _struck_by(squad: SkirmishSquad, squads: Array) -> Array:
	if squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
		return []
	var all := _hostile(squad, squads)
	if squad.state == SkirmishSquad.State.FIGHTING:
		return all
	if squad.order == SkirmishUnit.Order.RETREAT:
		return all if FormationDiscipline.meets_threats(squad) else []
	return all.filter(func(e): return e[1].order == SkirmishUnit.Order.RETREAT)


## [[unit, squad], ...] for the living units of squads hostile to `squad`, not routing.
static func hostile_units(squad: SkirmishSquad, squads: Array) -> Array:
	return _hostile(squad, squads)


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
static func _pick(squad: SkirmishSquad, unit: SkirmishUnit, foes: Array, fight_seed: int) -> Array:
	var mine := ScrumReach.area(squad, unit)
	var where := ScrumReach.at(squad, unit)
	var best := []
	var best_key := []
	for entry in foes:
		var other: SkirmishUnit = entry[0]
		if not ScrumReach.touching(mine, ScrumReach.area(entry[1], other)):
			continue
		var there := ScrumReach.at(entry[1], other)
		var front := 0 if ScrumReach.in_front(unit.bearing, where, there) else 1
		var key := [front, where.distance_to(there), ScrumContest.draw(other, fight_seed)]
		if best.is_empty() or key < best_key:
			best = [other, entry[1], there]
			best_key = key
	return best


## Where the nearest enemy the unit touches stands, or null if it touches none.
static func nearest_touching(
	squad: SkirmishSquad, unit: SkirmishUnit, foes: Array, fight_seed: int
):
	var pick := _pick(squad, unit, foes, fight_seed)
	return null if pick.is_empty() else pick[2]
