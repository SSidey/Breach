class_name LaneSimulation
extends RefCounted
## Node occupancy and per-tick movement (Decision 4: abstracted lane capture, not
## spatial). See specs/02-lane-movement-and-combat.md.
##
## A wave is a Dictionary {"owner", "units" (Array of {"hp","dmg"}), "position",
## "direction", "engaged"} - the player's horde. A moving blocker is a Dictionary
## {"owner", "blocker" ({"hp","dmg"}), "position", "direction", "engaged"} - a
## defender-side single-entity mover (Hero Party, Messenger; dispatched by specs/04,
## spawned here directly via spawn_moving_blocker() as a test-only entry point until
## that item exists). Plain Dictionaries throughout, matching CombatResolver's
## plain-data contract.
##
## "engaged" (Phase 3 item 11, specs/08) holds a wave/mover in place across ticks
## while a clash is unresolved (both sides survive) - without it, advance_positions()
## unconditionally incremented position every tick regardless of combat outcome, so a
## horde that failed to destroy a blocker would silently walk past it (or a Hero Party
## past an undefeated horde) on the very next tick instead of the multi-tick siege
## specs/02's own Notes describe ("the same clash resolves again next tick"). Cleared
## the moment that side's clash actually resolves (capture, blocker destroyed, or the
## wave/mover is removed).
##
## node_owner()/node_garrison_hp() were merged into node_state() (Phase 3 item 11,
## specs/08) to keep this file's public surface within the ISP method-count threshold
## once despawn_wave() was added for auto-extraction - both queries were only ever
## used together by callers wanting a node's current state, and neither had a real
## consumer outside this file's own tests yet.
##
## _init(nodes: Array[NodeDef]) instead of _init(map: MapDef) (Phase 4 item 2,
## specs/09) - this class already only ever read map.nodes, so taking the raw array
## directly drops its dependency on MapDef's authoring-format shape entirely. Genuinely
## "one lane's simulation" now, per this file's own purpose - it never has to change
## again when MapDef's shape changes further (e.g. MapDef.lanes: Array[LaneDef]).

const CombatResolver = preload("res://sim/combat_resolver.gd")

var _nodes: Array[NodeDef]
var _node_owners: Array = []
var _node_garrison_hp: Array = []
var _waves: Array = []
var _moving_blockers: Array = []


func _init(nodes: Array[NodeDef]) -> void:
	_nodes = nodes
	for node in nodes:
		_node_owners.append("")
		_node_garrison_hp.append(node.garrison_hp)


func node_state(index: int) -> Dictionary:
	return {"owner": _node_owners[index], "garrison_hp": _node_garrison_hp[index]}


func waves() -> Array:
	return _waves


func moving_blockers() -> Array:
	return _moving_blockers


func spawn_wave(owner: String, units: Array, start_index: int, direction: int) -> Dictionary:
	var wave := {
		"owner": owner,
		"units": units,
		"position": start_index,
		"direction": direction,
		"engaged": false,
	}
	_waves.append(wave)
	return wave


func despawn_wave(wave: Dictionary) -> void:
	_waves.erase(wave)


func spawn_moving_blocker(
	owner: String, blocker: Dictionary, start_index: int, direction: int
) -> Dictionary:
	var mover := {
		"owner": owner,
		"blocker": blocker,
		"position": start_index,
		"direction": direction,
		"engaged": false,
	}
	_moving_blockers.append(mover)
	return mover


func advance_positions() -> void:
	for wave in _waves:
		if not wave["engaged"]:
			wave["position"] += wave["direction"]
	for mover in _moving_blockers:
		if not mover["engaged"]:
			mover["position"] += mover["direction"]
	for wave in _waves.duplicate():
		_resolve_wave_arrival(wave)


func _resolve_wave_arrival(wave: Dictionary) -> void:
	var index: int = wave["position"]

	for mover in _moving_blockers.duplicate():
		if mover["owner"] == wave["owner"] or mover["position"] != index:
			continue
		_resolve_mid_lane_clash(wave, mover, index)
		return

	if index < 0 or index >= _node_owners.size():
		return
	if _node_owners[index] == wave["owner"]:
		return

	_resolve_node_arrival(wave, index)


func _resolve_mid_lane_clash(wave: Dictionary, mover: Dictionary, index: int) -> void:
	var outcome := CombatResolver.resolve(wave["units"], mover["blocker"])
	SimEvents.combat_resolved.emit(index, outcome)
	wave["units"] = outcome["surviving_horde"]
	mover["blocker"]["hp"] = outcome["remaining_blocker_hp"]
	if outcome["blocker_destroyed"]:
		_moving_blockers.erase(mover)
		wave["engaged"] = false
	else:
		mover["engaged"] = true
		wave["engaged"] = true
	if wave["units"].is_empty():
		_waves.erase(wave)


func _resolve_node_arrival(wave: Dictionary, index: int) -> void:
	var node: NodeDef = _nodes[index]
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
		wave["engaged"] = false
	else:
		wave["engaged"] = true
	if wave["units"].is_empty():
		_waves.erase(wave)
