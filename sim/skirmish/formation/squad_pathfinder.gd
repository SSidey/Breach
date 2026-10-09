class_name SquadPathfinder
extends RefCounted
## Who finds the way for a group (spec 30): one pathfinder per squad, the living unit with
## the best wits, whoever leads it - what the way is for still follows the leader's and
## units' behaviour. Equal wits go to the battle's seeded draw (ScrumContest.draw), never
## to ids or the order the units are listed in (Decision 97). Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


## The squad's pathfinder in the battle seeded `fight_seed`; null with none standing.
static func pick(squad: SkirmishSquad, fight_seed: int) -> SkirmishUnit:
	var best: SkirmishUnit = null
	var best_key := []
	for unit in squad.living():
		var key := [
			int(unit.attributes.get("wits", UnitDef.AVERAGE)), ScrumContest.draw(unit, fight_seed)
		]
		if best == null or ScrumContest.before(best_key, key):
			best = unit
			best_key = key
	return best
