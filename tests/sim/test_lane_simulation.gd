extends GdUnitTestSuite

const LaneSimulation = preload("res://sim/lane_simulation.gd")
const NodeDef = preload("res://content/definitions/node_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")


func _origin_node() -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.ORIGIN
	return node


func _fort_node(garrison_hp: int, garrison_dmg: int) -> NodeDef:
	var node := NodeDef.new()
	node.node_type = NodeDef.NodeType.FORT
	node.garrison = 1
	node.garrison_hp = garrison_hp
	node.garrison_dmg = garrison_dmg
	return node


func _map(nodes: Array) -> MapDef:
	var map := MapDef.new()
	var typed_nodes: Array[NodeDef] = []
	typed_nodes.assign(nodes)
	map.nodes = typed_nodes
	return map


func test_wave_advances_one_segment_per_tick() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _origin_node(), _origin_node()]))
	var wave := sim.spawn_wave("player", [{"hp": 10, "dmg": 2}], 0, 1)

	sim.advance_positions()

	assert_int(wave["position"]).is_equal(1)


func test_reaching_an_undefended_node_captures_it() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _origin_node()]))
	monitor_signals(SimEvents, false)
	sim.spawn_wave("player", [{"hp": 10, "dmg": 2}], 0, 1)

	sim.advance_positions()

	assert_str(sim.node_state(1)["owner"]).is_equal("player")
	await assert_signal(SimEvents).is_emitted("node_captured", 1)


func test_horde_destroys_a_defended_node_and_captures_it_with_no_casualties() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _fort_node(10, 3)]))
	sim.spawn_wave("player", [{"hp": 10, "dmg": 6}, {"hp": 8, "dmg": 6}], 0, 1)

	sim.advance_positions()

	assert_str(sim.node_state(1)["owner"]).is_equal("player")
	assert_int(sim.waves()[0]["units"].size()).is_equal(2)


func test_horde_fails_to_destroy_a_defended_node_and_takes_casualties_without_capturing() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _fort_node(50, 7)]))
	sim.spawn_wave("player", [{"hp": 4, "dmg": 1}, {"hp": 10, "dmg": 1}], 0, 1)

	sim.advance_positions()

	var state := sim.node_state(1)
	assert_str(state["owner"]).is_equal("")
	assert_int(state["garrison_hp"]).is_equal(48)
	var survivors: Array = sim.waves()[0]["units"]
	assert_int(survivors.size()).is_equal(1)
	assert_int(survivors[0]["hp"]).is_equal(7)


func test_wave_wiped_out_by_a_defended_node_is_removed() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _fort_node(50, 20)]))
	sim.spawn_wave("player", [{"hp": 4, "dmg": 1}], 0, 1)

	sim.advance_positions()

	assert_array(sim.waves()).is_empty()


func test_mid_lane_clash_with_a_moving_blocker_resolves_the_same_way() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _origin_node(), _origin_node()]))
	sim.spawn_wave("player", [{"hp": 10, "dmg": 6}, {"hp": 8, "dmg": 6}], 0, 1)
	sim.spawn_moving_blocker("defender", {"hp": 10, "dmg": 5}, 2, -1)

	sim.advance_positions()

	assert_array(sim.moving_blockers()).is_empty()
	assert_int(sim.waves()[0]["units"].size()).is_equal(2)


func test_a_surviving_moving_blocker_keeps_its_reduced_hp_for_the_next_clash() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _origin_node(), _origin_node()]))
	sim.spawn_wave("player", [{"hp": 10, "dmg": 6}], 0, 1)
	var mover := sim.spawn_moving_blocker("defender", {"hp": 50, "dmg": 3}, 1, 0)

	sim.advance_positions()

	assert_int(mover["blocker"]["hp"]).is_equal(44)


func test_advancing_after_a_wave_is_wiped_does_not_error() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _fort_node(50, 20)]))
	sim.spawn_wave("player", [{"hp": 4, "dmg": 1}], 0, 1)
	sim.advance_positions()

	sim.advance_positions()

	assert_array(sim.waves()).is_empty()


func test_despawn_wave_removes_it_from_tracking() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _origin_node()]))
	var wave := sim.spawn_wave("player", [{"hp": 10, "dmg": 2}], 0, 1)

	sim.despawn_wave(wave)

	assert_array(sim.waves()).is_empty()


func test_despawned_wave_is_not_moved_by_a_later_tick() -> void:
	var sim := LaneSimulation.new(_map([_origin_node(), _origin_node(), _origin_node()]))
	var wave := sim.spawn_wave("player", [{"hp": 10, "dmg": 2}], 0, 1)
	sim.despawn_wave(wave)

	sim.advance_positions()

	assert_array(sim.waves()).is_empty()
