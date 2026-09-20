class_name CaptureResolution
extends RefCounted
## Per-node capture choice: auto-extraction default (Decision 2) on resource-node
## capture, Ravage/Fortify/Dismantle player choices, and harvest-yield ticking. See
## specs/03-resource-nodes-and-workers.md.
##
## Does not self-subscribe to SimEvents - on_tick_advanced() is a plain method,
## same reasoning as CommandQueue (specs/01): a RefCounted connected to a long-lived
## global signal never gets freed.
##
## Deferred (see specs/03's Notes): ground-must-be-held reversion (no Task Force
## movement exists yet to trigger it) and Fortify's mechanical defensive effect (no
## scripted scenario re-attacks a fortified node in this slice) - only Fortify's
## resource cost is implemented here.

enum ResourceChoice { HARVEST, RAVAGED }
enum FortChoice { AWAITING, FORTIFIED, DISMANTLED }

var _economy: EconomySystem
var _resource_states: Dictionary = {}
var _fort_states: Dictionary = {}


func _init(economy: EconomySystem) -> void:
	_economy = economy


func on_node_captured(node_index: int, node: NodeDef) -> void:
	if node.node_type == NodeDef.NodeType.RESOURCE:
		_resource_states[node_index] = {
			"node": node, "choice": ResourceChoice.HARVEST, "ticks_since_capture": 0
		}
	elif node.node_type == NodeDef.NodeType.FORT:
		_fort_states[node_index] = {"node": node, "choice": FortChoice.AWAITING}


func is_awaiting_choice(node_index: int) -> bool:
	return (
		_fort_states.has(node_index) and _fort_states[node_index]["choice"] == FortChoice.AWAITING
	)


func issue_choice(node_index: int, choice: String) -> void:
	match choice:
		"ravage":
			_ravage(node_index)
		"fortify":
			_fortify(node_index)
		"dismantle":
			_dismantle(node_index)


func on_tick_advanced(_tick_number: int) -> void:
	for node_index in _resource_states.keys():
		var state: Dictionary = _resource_states[node_index]
		if state["choice"] != ResourceChoice.HARVEST:
			continue
		var node: NodeDef = state["node"]
		state["ticks_since_capture"] += 1
		var yield_amount := _economy.decayed_yield(
			node.yield_food_per_tick,
			state["ticks_since_capture"],
			node.decay_interval_ticks,
			node.decay_floor_food
		)
		_economy.add("food", yield_amount)


func _ravage(node_index: int) -> void:
	var state: Dictionary = _resource_states.get(node_index, {})
	if state.is_empty() or state["choice"] != ResourceChoice.HARVEST:
		return
	var node: NodeDef = state["node"]
	_economy.add("food", node.ravage_yield_food)
	state["choice"] = ResourceChoice.RAVAGED


func _fortify(node_index: int) -> void:
	var state: Dictionary = _fort_states.get(node_index, {})
	if state.is_empty() or state["choice"] != FortChoice.AWAITING:
		return
	var node: NodeDef = state["node"]
	if (
		_economy.balance("wood") < node.fortify_wood_cost
		or _economy.balance("stone") < node.fortify_stone_cost
	):
		return
	_economy.spend("wood", node.fortify_wood_cost)
	_economy.spend("stone", node.fortify_stone_cost)
	state["choice"] = FortChoice.FORTIFIED


func _dismantle(node_index: int) -> void:
	var state: Dictionary = _fort_states.get(node_index, {})
	if state.is_empty() or state["choice"] != FortChoice.AWAITING:
		return
	var node: NodeDef = state["node"]
	_economy.add("wood", node.dismantle_wood_yield)
	_economy.add("stone", node.dismantle_stone_yield)
	state["choice"] = FortChoice.DISMANTLED
