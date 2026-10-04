class_name FormationMelee
extends RefCounted
## This tick's melee blows (specs/22-formation-feel-test.md, Decisions 40, 78 and 81): each
## fighting squad's front-rank fighters strike the enemy fighter they overlap, or past a
## narrower line's end wrap onto it as a flank attack (x FLANK_BONUS) unless wings walk;
## blows on a turning squad are flank blows; flank locks and wings strike edges
## (FormationEdges, FormationWings). A wavering squad strikes more slowly (FormationMorale).
## A striker on higher ground hits harder (Decision 85; x HIGH_GROUND, a placeholder until
## spec 28 defines a step of damage).
## Pure over the squads it is given; FormationSimulation applies the blows.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")
const FormationEdges = preload("res://sim/skirmish/formation/formation_edges.gd")
const FormationWings = preload("res://sim/skirmish/formation/formation_wings.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const FormationRout = preload("res://sim/skirmish/formation/formation_rout.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

const HIGH_GROUND := 1.25


## [[attacker, target, damage, flank], ...]; updates each striker's target and cooldown.
static func blows(
	squads: Array, interval: int, tick: int, walk_wings: bool, terrain: FormationTerrain = null
) -> Array:
	var by_id := {}
	for entry in squads:
		by_id[entry.id] = entry
	var out := []
	for own in squads:
		if own.state != SkirmishSquad.State.FIGHTING:
			continue
		var foe: SkirmishSquad = by_id.get(own.engaged_with)
		if foe == null or foe.is_destroyed() or FormationEdges.is_flanking(own, foe):
			continue
		var pace := FormationMorale.interval(own, interval)
		var foe_fighters := foe.fighters()
		for fighter in own.fighters():
			var pick := FormationCombat.pick_target(own, fighter, foe, foe_fighters)
			if pick.is_empty() or FormationWings.is_wing(own, fighter):
				continue
			if pick[1] and walk_wings:
				continue  # past the line's end: it walks round instead (FormationWings)
			fighter.target_id = pick[0].id
			fighter.attack_cooldown -= 1
			if fighter.attack_cooldown <= 0:
				fighter.attack_cooldown = pace
				var flank: bool = pick[1] or foe.state == SkirmishSquad.State.TURNING
				out.append([fighter, pick[0], FormationCombat.damage(fighter, flank), flank])
	out.append_array(FormationEdges.blows(squads, interval, tick))
	out.append_array(FormationWings.blows(squads, interval, tick))
	out.append_array(FormationRout.blows(squads, interval))
	if terrain != null:
		for blow in out:
			if terrain.high_ground(blow[0].position, blow[1].position):
				blow[2] = roundi(blow[2] * HIGH_GROUND)
	return out
