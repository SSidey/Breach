class_name LoadPaths
extends RefCounted
## Load paths through a structure plan (Decisions 61, 65, spec 24), in whole load units.
## - Each element weighs its material's weight x its eighths and carries its strength x
##   its eighths; a ground column carries bearing x 8.
## - Loads flow top-down: an element passes its weight plus whatever rests on it, split
##   equally, to what holds it (StructureSupports). An element with nothing beneath hangs
##   from directly held elements of its own kind within its material's span; with none in
##   reach it fails.
## - An element fails when its load exceeds its capacity; elements standing on a ground
##   column fail together when the column is overloaded.
## settle() removes failures and solves again until nothing more fails. Pure.

const StructurePlanDef = preload("res://content/definitions/structure_plan_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")
const StructureSupports = preload("res://sim/structure/structure_supports.gd")


## {"loads": {key: load units}, "failed": [keys, in the order found]}.
static func solve(plan: StructurePlanDef, library: TerrainLibraryDef, bearing: int) -> Dictionary:
	var supports := StructureSupports.new(plan, library)
	var elements := supports.elements()
	var held := {}  # key -> the keys it passes its load to
	var failed := []
	for key in elements:
		held[key] = supports.direct(elements[key])
	var bridged := _bridge(elements, held, supports, library, failed)
	var loads := {}
	for key in elements:
		var material = library.material(elements[key]["material"])
		loads[key] = (material.weight if material else 0) * elements[key]["eighths"]
	for at in plan.loads:
		var target := supports.load_target(at)
		if target:
			loads[target] = loads.get(target, 0) + int(plan.loads[at])
	for key in _top_down(elements, bridged):
		var material = library.material(elements[key]["material"])
		var capacity: int = (material.strength if material else 0) * elements[key]["eighths"]
		if loads[key] > capacity and not failed.has(key):
			failed.append(key)
		_pass_down(loads, key, held[key])
	for key in elements:
		for target in held[key]:
			if (
				target.begins_with("ground:")
				and loads[target] > bearing * 8
				and not failed.has(key)
			):
				failed.append(key)
	return {"loads": loads, "failed": failed}


## Every element that fails as each failure brings down what it held; the plan is left as
## it was (the solve runs on a copy).
static func settle(plan: StructurePlanDef, library: TerrainLibraryDef, bearing: int) -> Array:
	var working: StructurePlanDef = plan.duplicate(true)
	var fallen := []
	while true:
		var failed: Array = solve(working, library, bearing)["failed"]
		if failed.is_empty():
			return fallen
		fallen.append_array(failed)
		for key in failed:
			if key.begins_with("cell:"):
				var parts: PackedStringArray = key.trim_prefix("cell:").split(",")
				working.solid_cells.erase(Vector3i(int(parts[0]), int(parts[1]), int(parts[2])))
		var faces := working.faces.filter(func(face): return not failed.has(face.key()))
		working.faces.assign(faces)
	return fallen


## Elements with nothing beneath hang from the nearest directly held elements of their kind
## within their material's span; returns the keys that hang, and fails any that can't.
static func _bridge(
	elements: Dictionary,
	held: Dictionary,
	supports: StructureSupports,
	library: TerrainLibraryDef,
	failed: Array
) -> Dictionary:
	var bridged := {}
	for key in elements:
		if not held[key].is_empty():
			continue
		var material = library.material(elements[key]["material"])
		var reach: int = material.span if material else 0
		var anchors := _nearest_held(key, elements, held, supports, reach)
		if anchors.is_empty():
			failed.append(key)
		held[key] = anchors
		bridged[key] = true
	return bridged


## The directly held elements nearest to `start` along its own kind, within `reach` steps.
static func _nearest_held(
	start: String, elements: Dictionary, held: Dictionary, supports: StructureSupports, reach: int
) -> Array:
	var seen := {start: true}
	var frontier := [start]
	for step in range(reach):
		var next := []
		var found := []
		for key in frontier:
			for neighbour in supports.neighbours(elements[key]):
				if seen.has(neighbour):
					continue
				seen[neighbour] = true
				next.append(neighbour)
				if not held[neighbour].is_empty() and not _hangs(held, neighbour, elements):
					found.append(neighbour)
		if not found.is_empty():
			found.sort()
			return found
		frontier = next
	return []


## True if an element's supports are only its own kind's neighbours (it hangs itself).
static func _hangs(held: Dictionary, key: String, elements: Dictionary) -> bool:
	for target in held[key]:
		if elements.has(target) and elements[target]["at"].z == elements[key]["at"].z:
			return true
	return false


## Highest level first; within a level, hanging elements before those they hang from.
static func _top_down(elements: Dictionary, bridged: Dictionary) -> Array:
	var keys := elements.keys()
	keys.sort_custom(
		func(a, b):
			var la: int = elements[a]["at"].z
			var lb: int = elements[b]["at"].z
			if la != lb:
				return la > lb
			if bridged.has(a) != bridged.has(b):
				return bridged.has(a)
			return a < b
	)
	return keys


## Splits a load equally between targets; the remainder goes to the first, in key order.
static func _pass_down(loads: Dictionary, key: String, targets: Array) -> void:
	if targets.is_empty():
		return
	var ordered := targets.duplicate()
	ordered.sort()
	var share: int = loads[key] / ordered.size()
	for index in range(ordered.size()):
		var extra: int = loads[key] % ordered.size() if index == 0 else 0
		loads[ordered[index]] = loads.get(ordered[index], 0) + share + extra
