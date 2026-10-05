class_name FormationMelee
extends RefCounted
## This tick's melee blows (Decision 88): units in the scrum strike the foes they touch
## (ScrumBlows), and hostiles strike routers within reach from behind (RoutBlows).
## A striker on higher ground hits harder (Decision 85; x HIGH_GROUND, a placeholder until
## spec 28 defines a step of damage).
## Pure over the squads it is given; FormationSimulation applies the blows.

const RoutBlows = preload("res://sim/skirmish/formation/rout_blows.gd")
const ScrumBlows = preload("res://sim/skirmish/formation/scrum_blows.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

const HIGH_GROUND := 1.25


## [[attacker, target, damage, flank], ...]; updates each striker's target and cooldown.
## `fight_seed` breaks ties between equal targets (Decision 97).
static func blows(
	squads: Array, interval: int, fight_seed: int, terrain: FormationTerrain = null
) -> Array:
	var out := ScrumBlows.blows(squads, interval, fight_seed)
	out.append_array(RoutBlows.blows(squads, interval, fight_seed))
	if terrain != null:
		for blow in out:
			if terrain.high_ground(blow[0].position, blow[1].position):
				blow[2] = roundi(blow[2] * HIGH_GROUND)
	return out
