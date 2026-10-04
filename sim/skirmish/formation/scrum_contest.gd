class_name ScrumContest
extends RefCounted
## Who gets a contested cell in the scrum (Decision 88): the order is the key
## (arrival time, roll + initiative, initiative, speed, unit's draw), compared item by item
## - the earliest arrival first, then the higher roll plus initiative, then the higher
## initiative, the faster unit, and last a draw unique within the fight, so the order never
## ties. The roll is the unit's seeded variance, drawn once per contest from the fight's
## seed, the tick and the unit, so a replay repeats. Pure.

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

## The roll's die: 0 to DIE (placeholder; its size is spec 28's). 0 decides by stats alone.
const DIE := 10


## The unit's key for a cell it would reach in `arrival` seconds.
static func key(unit: SkirmishUnit, arrival: float, fight_seed: int, tick: int) -> Array:
	var roll := posmod(hash([fight_seed, tick, unit.id]), DIE + 1) if DIE > 0 else 0
	return [
		arrival, -(roll + unit.initiative), -unit.initiative, -unit.speed, draw(unit, fight_seed)
	]


## The unit's draw: seeded by the fight and the unit, and never equal to another's.
static func draw(unit: SkirmishUnit, fight_seed: int) -> int:
	return posmod(hash([fight_seed, unit.id]), 1 << 20) * 4096 + unit.id % 4096


## True if key `a` goes before key `b`.
static func before(a: Array, b: Array) -> bool:
	for index in range(mini(a.size(), b.size())):
		if a[index] != b[index]:
			return a[index] < b[index]
	return false
