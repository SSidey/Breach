extends GdUnitTestSuite
## FormationFieldScene smoke tests, per Decisions 86 and 87 and spec 27: the 2D field
## builds, its waves fill and can be sent, and squads stand in 2D on their routes. How it
## plays - marching, wheeling, meeting head-on - is checked by hand.

const FormationFieldScene = preload(
	"res://presentation/skirmish/formation_2d/formation_field_scene.gd"
)
const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const SCENE := "res://presentation/skirmish/formation_2d/formation_field.tscn"


func _scene() -> FormationFieldScene:
	var scene: FormationFieldScene = auto_free(load(SCENE).instantiate())
	add_child(scene)
	scene.clock().pause()  # the test drives ticks itself
	return scene


func test_the_scene_builds_the_field_with_the_kingdom_line() -> void:
	var scene := _scene()

	assert_object(scene.field()).is_not_null()
	assert_array(scene.field().routes.keys()).contains_exactly(["A", "B", "C"])
	assert_int(scene.field().sim.squads().size()).is_equal(2)  # the line and its reserve


func test_a_sent_wave_marches_down_its_route_in_2d() -> void:
	var scene := _scene()
	scene.run_ticks(100)  # four grem builders fill an 8-wide wave

	scene.act("send A")
	scene.run_ticks(20)

	var squads := scene.field().sim.squads()
	assert_int(squads.size()).is_equal(3)
	var wave = squads[2]
	assert_float(wave.position.y).is_equal_approx(32.0, 0.01)
	assert_float(wave.position.x).is_greater(0.0)
	for unit in wave.living():
		assert_float(unit.position.y).is_between(27.0, 37.0)


func test_waves_can_be_sent_together_and_b_can_wait() -> void:
	var scene := _scene()
	scene.field().set_wait(true)
	scene.run_ticks(200)

	var sent: Array = scene.field().send_together(["A", "B"])
	scene.run_ticks(5)

	assert_int(sent.size()).is_equal(2)
	assert_bool(scene.field().waves["B"].staging.is_empty()).is_false()


func test_the_line_can_be_given_a_captain() -> void:
	var scene := _scene()

	scene.restart(true, 7)

	var line = scene.field().kingdom_line
	assert_bool(line.living().any(func(u): return u.leadership > 0)).is_true()


func test_reset_starts_a_fresh_field_under_a_seed() -> void:
	var scene := _scene()
	scene.run_ticks(50)
	var before = scene.field()

	scene.restart(false, 42)

	assert_object(scene.field()).is_not_same(before)
	assert_int(scene.field().sim.fight_seed).is_equal(42)
	assert_int(scene.field().sim.tick_number()).is_equal(0)


func test_a_sent_wave_can_be_ordered_to_retreat() -> void:
	var scene := _scene()
	scene.run_ticks(100)
	scene.act("send A")
	scene.run_ticks(5)

	scene.act("retreat A")
	scene.run_ticks(1)

	var wave = scene.field().sim.squads()[2]
	assert_int(wave.order).is_equal(2)  # SkirmishUnit.Order.RETREAT


func test_actions_are_logged_with_their_ticks_after_the_seed() -> void:
	var scene := _scene()
	scene.restart(false, 42)
	scene.run_ticks(5)

	scene.act("send A")

	assert_str(scene.action_log()).is_equal("seed 42 captain off\n5 send A")
