class_name FormationSight
extends RefCounted
## What a formation can detect (Decision 87, spec 27 round 2): another squad is detected
## if any of its living units is within the best detection range among the formation's
## living units, measured in cells between unit centres. Nothing else is known to it - no
## formation is telepathic. With terrain, a sight line that passes through more than
## MAX_SCREEN cells that block sight (a wood) is blocked: units at a wood's edge see out and
## are seen, deeper in they are hidden (Decision 87). Light comes later. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

## How many sight-blocking cells a sight line may cross and still see.
const MAX_SCREEN := 2


static func detects(
	squad: SkirmishSquad, other: SkirmishSquad, terrain: FormationTerrain = null
) -> bool:
	for unit in squad.living():
		for seen in other.living():
			if unit.position.distance_to(seen.position) > unit.detection:
				continue
			if terrain == null or clear(terrain, unit.position, seen.position):
				return true
	return false


## True if the sight line between two points crosses at most MAX_SCREEN blocking cells.
static func clear(terrain: FormationTerrain, from: Vector2, to: Vector2) -> bool:
	var screened := {}
	var steps := maxi(1, ceili(from.distance_to(to) * 2.0))
	for index in range(steps + 1):
		var at := from.lerp(to, float(index) / steps)
		if terrain.blocks_sight(at):
			screened[Vector2i(floori(at.x), floori(at.y))] = true
			if screened.size() > MAX_SCREEN:
				return false
	return true
