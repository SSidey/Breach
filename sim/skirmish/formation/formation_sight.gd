class_name FormationSight
extends RefCounted
## What a formation can detect (Decision 87, spec 27 round 2): another squad is detected
## if any of its living units is within the best detection range among the formation's
## living units, measured in cells between unit centres. Nothing else is known to it - no
## formation is telepathic. Line of sight (woods, ridges) and light come with terrain.
## Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")


static func detects(squad: SkirmishSquad, other: SkirmishSquad) -> bool:
	for unit in squad.living():
		for seen in other.living():
			if unit.position.distance_to(seen.position) <= unit.detection:
				return true
	return false
