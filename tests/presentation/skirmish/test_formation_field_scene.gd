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
	assert_array(scene.field().routes.keys()).contains_exactly(["A", "B"])
	assert_int(scene.field().sim.squads().size()).is_equal(2)  # the line and its reserve


func test_a_sent_wave_marches_down_its_route_in_2d() -> void:
	var scene := _scene()
	scene.run_ticks(100)  # four grem builders fill an 8-wide wave

	scene._on_send("A")
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
