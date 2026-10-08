class_name BodyParting
extends RefCounted
## UnitBodies' body-parting passes run by a native kernel (NativeKernels): the drawn
## bodies gathered into packed arrays (data in), the kernel's passes, the new points
## written back (data out) - exactly as UnitBodies' own _move would have left them, so
## the battle can't tell which ran. The kernel mirrors the GDScript's precision and order
## (Vector2 maths in 32-bit floats, scalars in 64-bit, pairs in order); a pair lying
## exactly on each other asks `way` (UnitBodies.part_way) which way it parts.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationRout = preload("res://sim/skirmish/formation/formation_rout.gd")

## A body's flags, as the kernels read them.
const LOOSE := 1
const FLEEING := 2
const MOVED := 4

## Microseconds since last zeroed: [gathering, the call, the kernel's own work, writing back].
## The bench reads them to split the boundary's cost from the work; no outcome does.
static var spent := PackedInt64Array([0, 0, 0, 0])


## Parts the drawn bodies ([[squad, unit, draw], ...], UnitBodies._drawn) with `kernel`.
static func step(kernel: Object, drawn: Array, way: Callable, threaded: bool) -> void:
	var began := Time.get_ticks_usec()
	var inputs := gather(drawn)
	var called := Time.get_ticks_usec()
	var out: Array = kernel.callv("part", inputs + [way, threaded])
	var returned := Time.get_ticks_usec()
	_write_back(drawn, out)
	spent[0] += called - began
	spent[1] += returned - called
	spent[2] += out[4][0]
	spent[3] += Time.get_ticks_usec() - returned


## The kernel's inputs for the drawn bodies: [points, bases, nexts, radii, areas, squads,
## factions, flags, tuning]. A point is where the body stands - a fleeing one's offset
## from its base on its route, a loose one's point, a framed one's place.
static func gather(drawn: Array) -> Array:
	var count := drawn.size()
	var points := PackedVector2Array()
	var bases := PackedVector2Array()
	var nexts := PackedVector2Array()
	var radii := PackedFloat64Array()
	var areas := PackedFloat64Array()
	var squads := PackedInt32Array()
	var factions := PackedInt32Array()
	var flags := PackedByteArray()
	for array in [points, bases, nexts, radii, areas, squads, factions, flags]:
		array.resize(count)
	var squad_index := {}
	var faction_index := {}
	for index in range(count):
		var squad: SkirmishSquad = drawn[index][0]
		var unit: SkirmishUnit = drawn[index][1]
		squads[index] = squad_index.get_or_add(squad, squad_index.size())
		factions[index] = faction_index.get_or_add(squad.faction_id, faction_index.size())
		radii[index] = ScrumReach.radius(unit)
		areas[index] = float(unit.footprint_width * unit.footprint_depth)
		var flag := LOOSE if squad.loose.has(unit.id) else 0
		points[index] = unit.position
		if squad.fleeing.has(unit.id):
			flag |= FLEEING
			bases[index] = FormationRout.route_point(squad, unit.id)
			points[index] = squad.fleeing[unit.id]["offset"]
		elif flag:
			points[index] = squad.loose[unit.id]["at"]
			nexts[index] = squad.loose[unit.id]["next"]
		flags[index] = flag
	var tuning := BattleTuning.current()
	var weights := PackedFloat64Array(
		[tuning.bodies_passes, tuning.bodies_resist, tuning.bodies_brush]
	)
	return [points, bases, nexts, radii, areas, squads, factions, flags, weights]


## Writes the kernel's [points, nexts, flags, loosened, stats] back: the units it made
## loose first (in the order the passes did), then every moved body's point.
static func _write_back(drawn: Array, out: Array) -> void:
	var points: PackedVector2Array = out[0]
	var nexts: PackedVector2Array = out[1]
	var flags: PackedByteArray = out[2]
	for index in out[3]:
		var unit: SkirmishUnit = drawn[index][1]
		var entry := {"unit": unit, "at": unit.position, "goal": null, "next": unit.position}
		drawn[index][0].loose[unit.id] = entry
	for index in range(flags.size()):
		if flags[index] & MOVED == 0:
			continue
		var squad: SkirmishSquad = drawn[index][0]
		var unit: SkirmishUnit = drawn[index][1]
		if squad.fleeing.has(unit.id):
			squad.fleeing[unit.id]["offset"] = points[index]
			continue
		var entry: Dictionary = squad.loose[unit.id]
		entry["at"] = points[index]
		entry["next"] = nexts[index]
