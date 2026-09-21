class_name LaneSimulation
extends RefCounted
## Node occupancy and per-tick movement (Decision 4: abstracted lane capture, not
## spatial). See specs/02-lane-movement-and-combat.md.
##
## A wave is a Dictionary {"owner", "units" (Array of {"hp","dmg"}), "position",
## "direction"} - the player's horde. A moving blocker is a Dictionary {"owner",
## "blocker" ({"hp","dmg"}), "position", "direction"} - a defender-side single-entity
## mover (Hero Party, Messenger; dispatched by specs/04, spawned here directly via
## spawn_moving_blocker() as a test-only entry point until that item exists).
## Plain Dictionaries throughout, matching CombatResolver's plain-data contract.
##
## node_owner()/node_garrison_hp() were merged into node_state() (Phase 3 item 11,
## specs/08) to keep this file's public surface within the ISP method-count threshold
## once despawn_wave() was added for auto-extraction - both queries were only ever
## used together by callers wanting a node's current state, and neither had a real
## consumer outside this file's own tests yet.

const CombatResolver = preload("res://sim/combat_resolver.gd")

var _map: MapDef
var _node_owners: Array = []
var _node_garrison_hp: Array = []
var _waves: Array = []
var _moving_blockers: Array = []


func _init(map: MapDef) -> void:
	_map = map
	for node in map.nodes:
		_node_owners.append("")
		_node_garrison_hp.append(node.garrison_hp)


func node_state(index: int) -> Dictionary:
	return {"owner": _node_owners[index], "garrison_hp": _node_garrison_hp[index]}


func waves() -> Array:
	return _waves


func moving_blockers() -> Array:
	return _moving_blockers


func spawn_wave(owner: String, units: Array, start_index: int, direction: int) -> Dictionary:
	var wave := {"owner": owner, "units": units, "position": start_index, "direction": direction}
	_waves.append(wave)
	return wave


func despawn_wave(wave: Dictionary) -> void:
	_waves.erase(wave)


func spawn_moving_blocker(
	owner: String, blocker: Dictionary, start_index: int, direction: int
) -> Dictionary:
	var mover := {
		"owner": owner, "blocker": blocker, "position": start_index, "direction": direction
	}
	_moving_blockers.append(mover)
	return mover


func advance_positions() -> void:
	for wave in _waves:
		wave["position"] += wave["direction"]
	for mover in _moving_blockers:
		mover["position"] += mover["direction"]
	for wave in _waves.duplicate():
		_resolve_wave_arrival(wave)


func _resolve_wave_arrival(wave: Dictionary) -> void:
	var index: int = wave["position"]

	for mover in _moving_blockers.duplicate():
		if mover["owner"] == wave["owner"] or mover["position"] != index:
			continue
		var outcome := CombatResolver.resolve(wave["units"], mover["blocker"])
		SimEvents.combat_resolved.emit(index, outcome)
		wave["units"] = outcome["surviving_horde"]
		if outcome["blocker_destroyed"]:
			_moving_blockers.erase(mover)
		if wave["units"].is_empty():
			_waves.erase(wave)
		return

	if index < 0 or index >= _node_owners.size():
		return
	if _node_owners[index] == wave["owner"]:
		return

	var node: NodeDef = _map.nodes[index]
	if node.garrison <= 0 or _node_garrison_hp[index] <= 0:
		_node_owners[index] = wave["owner"]
		SimEvents.node_captured.emit(index)
		return

	var blocker := {"hp": _node_garrison_hp[index], "dmg": node.garrison_dmg}
	var outcome := CombatResolver.resolve(wave["units"], blocker)
	SimEvents.combat_resolved.emit(index, outcome)
	wave["units"] = outcome["surviving_horde"]
	_node_garrison_hp[index] = outcome["remaining_blocker_hp"]
	if outcome["blocker_destroyed"]:
		_node_owners[index] = wave["owner"]
		SimEvents.node_captured.emit(index)
	if wave["units"].is_empty():
		_waves.erase(wave)
