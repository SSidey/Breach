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
const RoutBlows = preload("res://sim/skirmish/formation/rout_blows.gd")
const ScrumBlows = preload("res://sim/skirmish/formation/scrum_blows.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

const HIGH_GROUND := 1.25
## Modes: lines wrap abstractly (0), wings walk round (1), or units seek contact (Decision
## 88; ScrumBlows replaces the frontal, edge and wing blows).
const WRAP := 0
const WINGS := 1
const SCRUM := 2


## [[attacker, target, damage, flank], ...]; updates each striker's target and cooldown.
## `fight_seed` breaks ties between equal targets (Decision 97).
static func blows(
	squads: Array,
	interval: int,
	tick: int,
	mode: int,
	fight_seed: int,
	terrain: FormationTerrain = null
) -> Array:
	var out := (
		ScrumBlows.blows(squads, interval, fight_seed)
		if mode == SCRUM
		else _lines(squads, interval, tick, mode, fight_seed)
	)
	out.append_array(RoutBlows.blows(squads, interval, fight_seed))
	if terrain != null:
		for blow in out:
			if terrain.high_ground(blow[0].position, blow[1].position):
				blow[2] = roundi(blow[2] * HIGH_GROUND)
	return out


static func _lines(squads: Array, interval: int, tick: int, mode: int, fight_seed: int) -> Array:
	var walk_wings := mode == WINGS
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
	out.append_array(FormationEdges.blows(squads, interval, tick, fight_seed))
	out.append_array(FormationWings.blows(squads, interval, tick, fight_seed))
	return out
