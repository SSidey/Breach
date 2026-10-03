extends GdUnitTestSuite
## FormationFieldScene smoke tests, per Decision 86 and spec 27 round 1: the 2D field
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
	assert_int(scene.field().sim.squads().size()).is_equal(1)


func test_a_sent_wave_marches_down_its_route_in_2d() -> void:
	var scene := _scene()
	scene.run_ticks(100)  # four grem builders fill an 8-wide wave

	scene._on_send("A")
	scene.run_ticks(20)

	var squads := scene.field().sim.squads()
	assert_int(squads.size()).is_equal(2)
	var wave = squads[1]
	assert_float(wave.position.y).is_equal_approx(32.0, 0.01)
	assert_float(wave.position.x).is_greater(0.0)
	for unit in wave.living():
		assert_float(unit.position.y).is_between(27.0, 37.0)
