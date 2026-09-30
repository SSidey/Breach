extends GdUnitTestSuite
## FormationSkirmishScene smoke tests, per specs/22-formation-feel-test.md: two lanes from
## the map, a shared slot pool, and the wave-full pause (Decision 39). Playing it - width,
## flanking, step-up, splitting the pool - is checked by hand.

const FormationSkirmishScene = preload(
	"res://presentation/skirmish/formation/formation_skirmish_scene.gd"
)
const SkirmishSquadLayer = preload("res://presentation/skirmish/formation/skirmish_squad_layer.gd")
const SCENE := "res://presentation/skirmish/formation/formation_skirmish.tscn"
const SPEC_21_SCENE := "res://presentation/skirmish/skirmish.tscn"


func _scene() -> FormationSkirmishScene:
	var scene: FormationSkirmishScene = auto_free(load(SCENE).instantiate())
	add_child(scene)
	return scene


func test_the_scene_builds_a_simulation_per_lane_from_the_map() -> void:
	var scene := _scene()

	assert_array(scene.lane_keys()).contains_exactly(["c", "k"])
	assert_float(scene.simulation("c").route_length).is_greater(9.0)
	assert_float(scene.simulation("k").route_length).is_greater(9.0)


func test_the_pool_starts_split_and_clamps_reassignment() -> void:
	var scene := _scene()

	assert_int(scene.pool().assigned("c") + scene.pool().assigned("k")).is_equal(scene.pool().total)
	scene.assign_slots("c", 99)
	assert_int(scene.pool().assigned("c") + scene.pool().assigned("k")).is_less_equal(
		scene.pool().total
	)


func test_a_full_wave_pauses_and_sending_it_resumes() -> void:
	var scene := _scene()
	scene.pause_on_wave_full = true

	scene.handle_events("c", [{"type": "wave_full", "tick": 1, "faction": "player", "built": 5}])
	assert_bool(scene.clock().is_paused()).is_true()
	scene.send_wave("c")

	assert_bool(scene.clock().is_paused()).is_false()


func test_notify_only_keeps_the_game_running() -> void:
	var scene := _scene()
	scene.pause_on_wave_full = false

	scene.handle_events("k", [{"type": "wave_full", "tick": 1, "faction": "player", "built": 3}])

	assert_bool(scene.clock().is_paused()).is_false()


func test_the_squad_layer_constructs_and_the_spec_21_scene_still_loads() -> void:
	var layer: SkirmishSquadLayer = auto_free(SkirmishSquadLayer.new())
	var old: Node = auto_free(load(SPEC_21_SCENE).instantiate())

	assert_object(layer).is_not_null()
	assert_object(old).is_not_null()


func test_units_in_different_lanes_with_the_same_id_stay_apart() -> void:
	var scene := _scene()
	var line := [[preload("res://content/units/grem.tres"), Vector2i(0, 0)]]
	var in_c = scene.simulation("c").spawn_squad(1, line, "player", true)
	var in_k = scene.simulation("k").spawn_squad(1, line, "player", true)
	in_k.front_distance = 4.0
	scene.simulation("k").step()
	var layer: SkirmishSquadLayer = scene.get_node("Squads")
	layer.snapshot()
	layer.fraction = 1.0

	assert_int(in_c.units[0].id).is_equal(in_k.units[0].id)  # ids are per lane
	assert_float(layer._distance("k", in_k.units[0])).is_greater(
		layer._distance("c", in_c.units[0])
	)


# --- Decision 42: painted templates, applied at once -----------------------------


func test_painting_a_brute_changes_the_lanes_template_at_once() -> void:
	var scene := _scene()
	scene._choose_brush("c", 1)  # Brute 2x2
	scene.assign_slots("k", 0)
	scene.assign_slots("c", 8)

	scene._paint_cell("c", Vector2i(0, 1))

	var places: Array = scene._lanes["c"].production.preview()
	assert_bool(places.any(func(p): return p[2] == 2 and p[3] == 2 and p[0] == 0)).is_true()


func test_lowering_a_lanes_share_trims_its_template_and_banks_built_units() -> void:
	var scene := _scene()
	var production = scene._lanes["c"].production
	for i in range(110):  # a grem takes 2 s (20 ticks): lane c's 5-grem line
		production.step(scene.simulation("c"))
	assert_int(production.built()).is_equal(5)

	scene.assign_slots("c", 2)

	assert_int(production.preview().size()).is_equal(2)
	assert_int(production.reserve_count()).is_equal(3)
