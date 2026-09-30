extends GdUnitTestSuite
## SkirmishScene smoke tests, per specs/21-realtime-skirmish-feel-test.md: the scene
## loads the P-c map into a simulation, and "on wave full" pauses or only notifies.
## Playing it (pace, readability, intervention feel) is checked by hand.

const SkirmishScene = preload("res://presentation/skirmish/skirmish_scene.gd")
const SkirmishUnitLayer = preload("res://presentation/skirmish/skirmish_unit_layer.gd")
const SCENE := "res://presentation/skirmish/skirmish.tscn"


func _scene() -> SkirmishScene:
	var scene: SkirmishScene = auto_free(load(SCENE).instantiate())
	add_child(scene)
	return scene


func test_the_scene_builds_a_simulation_from_the_map_route() -> void:
	var scene := _scene()

	assert_object(scene.map_view().map).is_not_null()
	assert_float(scene.simulation().route_length).is_equal_approx(9.0, 0.001)
	assert_bool(scene.clock().is_paused()).is_false()


func test_a_full_wave_pauses_the_game_when_the_option_is_pause() -> void:
	var scene := _scene()
	scene.pause_on_wave_full = true

	scene.handle_events([{"type": "wave_full", "tick": 1, "faction": "player", "wave_size": 3}])

	assert_bool(scene.clock().is_paused()).is_true()


func test_a_full_wave_only_notifies_when_the_option_is_notify() -> void:
	var scene := _scene()
	scene.pause_on_wave_full = false

	scene.handle_events([{"type": "wave_full", "tick": 1, "faction": "player", "wave_size": 3}])

	assert_bool(scene.clock().is_paused()).is_false()


func test_the_unit_layer_constructs() -> void:
	var layer: SkirmishUnitLayer = auto_free(SkirmishUnitLayer.new())

	assert_object(layer).is_not_null()
