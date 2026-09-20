extends GdUnitTestSuite
## Replays this slice's exact scripted path (specs/00's beats 3-5): a detection spike
## from attacking a fort crosses into Mobilized, dispatching a Hero Party; the
## player's horde then defeats it in combat, consuming the Task Force. Composition
## wiring here mirrors what a future composition root (Phase 3 item 11) will do -
## none of these components self-subscribe to each other, so the test wires them
## explicitly, same as production code will.

const SuspicionSystem = preload("res://sim/suspicion_system.gd")
const TaskForceDispatch = preload("res://sim/task_force_dispatch.gd")
const LaneSimulation = preload("res://sim/lane_simulation.gd")
const CombatResolver = preload("res://sim/combat_resolver.gd")
const NodeDef = preload("res://content/definitions/node_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")


func _map() -> MapDef:
	var map := MapDef.new()
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	var nodes: Array[NodeDef] = [node, node, node, node]
	map.nodes = nodes
	return map


func test_detection_spike_to_mobilized_dispatches_and_defeat_consumes_the_hero_party() -> void:
	var lane := LaneSimulation.new(_map())
	var suspicion := SuspicionSystem.new([25, 50, 75, 90], 0)
	var dispatch := TaskForceDispatch.new(
		lane, 3, -1, {SuspicionSystem.Tier.MOBILIZED: {"hp": 70, "dmg": 18}}
	)
	# A future composition root connects this the same way; wired explicitly here.
	SimEvents.suspicion_tier_changed.connect(dispatch.on_tier_entered)

	# Beat 3: attacking the fort raises suspicion via a detection spike.
	suspicion.add_suspicion(80)

	assert_int(suspicion.current_tier()).is_equal(SuspicionSystem.Tier.MOBILIZED)
	assert_int(dispatch.dispatched().size()).is_equal(1)

	# Beat 5: the player's horde meets the Hero Party and defeats it.
	var hero_party: Dictionary = dispatch.dispatched()[0]
	# Total dmg 80, enough to outright destroy the 70-hp Hero Party.
	var horde := [{"hp": 20, "dmg": 40}, {"hp": 20, "dmg": 40}]
	var outcome := CombatResolver.resolve(horde, hero_party["blocker"])

	assert_bool(outcome["blocker_destroyed"]).is_true()
	dispatch.mark_consumed(hero_party)

	assert_array(dispatch.dispatched()).is_empty()

	SimEvents.suspicion_tier_changed.disconnect(dispatch.on_tier_entered)
