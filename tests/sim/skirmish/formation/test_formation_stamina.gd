extends GdUnitTestSuite
## Load and stamina, per spec 28 part 7 (Decisions 117 and 120): what a unit carries
## against its strength sets its encumbrance - slower, tiring faster, dodging worse - and
## its stamina, from its constitution, is spent running and striking and regained
## otherwise; tired it is slower and less skilled, and a tired pursuer gives up the chase.

const FormationStamina = preload("res://sim/skirmish/formation/formation_stamina.gd")
const FormationUnits = preload("res://sim/skirmish/formation/formation_units.gd")
const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const UnitArms = preload("res://content/definitions/unit_arms.gd")
const ItemDef = preload("res://content/definitions/item_def.gd")


## A unit of strength 10 (carry limit 20 with the usual tuning) carrying `weight`.
func _laden(weight: float, hauler: int = 0) -> UnitDef:
	var pack := ItemDef.new()
	pack.item_name = "pack"
	pack.weight = weight
	var unit_def := UnitDef.new()
	unit_def.hp = 10
	unit_def.speed = 1.0
	unit_def.items = [pack]
	if hauler > 0:
		unit_def.traits = {"hauler": hauler}
	return unit_def


func _unit(stamina: float = 100.0) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.id = 1
	unit.hp = 10
	unit.speed = 1.0
	unit.max_stamina = 100.0
	unit.stamina = stamina
	return unit


func _squad(units: Array) -> SkirmishSquad:
	var typed: Array[SkirmishUnit] = []
	typed.assign(units)
	return SkirmishSquad.new(1, "player", 1, 0.0, units.size(), typed)


func test_its_load_against_its_strength_sets_its_encumbrance() -> void:
	assert_int(UnitArms.load_stage(_laden(10.0))).is_equal(0)
	assert_int(UnitArms.load_stage(_laden(15.0))).is_equal(1)
	assert_int(UnitArms.load_stage(_laden(30.0))).is_equal(2)
	assert_int(UnitArms.load_stage(_laden(45.0))).is_equal(3)
	assert_int(UnitArms.load_stage(_laden(45.0, 1))).is_equal(2)  # a hauler carries more


func test_a_laden_unit_is_slower_tires_faster_and_dodges_worse() -> void:
	var tuning := BattleTuning.current()
	var light := FormationUnits.make(_laden(5.0), Vector2i.ZERO, "player", 1, 1)
	var heavy := FormationUnits.make(_laden(30.0), Vector2i.ZERO, "player", 1, 2)

	assert_float(light.speed).is_equal(1.0)
	assert_float(heavy.speed).is_equal_approx(tuning.load_pace[2], 0.0001)
	assert_float(heavy.tiring).is_greater(light.tiring)
	assert_float(heavy.dodging).is_less(light.dodging)
	assert_float(light.max_stamina).is_equal(10 * tuning.stamina_per_constitution)


func test_running_tires_it_resting_restores_it_and_striking_costs() -> void:
	var tuning := BattleTuning.current()
	var runner := _unit()
	var fleeing := _squad([runner])
	fleeing.state = SkirmishSquad.State.ROUTING
	var rester := _unit(50.0)
	var striker := _unit()

	FormationStamina.step([fleeing, _squad([rester])], 1.0)
	FormationStamina.strike([[striker]])

	assert_float(runner.stamina).is_equal_approx(100.0 - tuning.stamina_run, 0.0001)
	assert_float(rester.stamina).is_equal_approx(50.0 + tuning.stamina_recovery, 0.0001)
	assert_float(striker.stamina).is_equal_approx(100.0 - tuning.stamina_blow, 0.0001)
	assert_bool(striker.exerted).is_true()


func test_tired_it_is_slower_and_less_skilled() -> void:
	var tuning := BattleTuning.current()
	var fresh := _unit()
	var tired := _unit(40.0)
	var spent := _unit(5.0)
	FormationStamina.step([_squad([fresh, tired, spent])], 0.0)

	assert_float(fresh.speed).is_equal(1.0)
	assert_float(tired.speed).is_equal_approx(tuning.stamina_pace[1], 0.0001)
	assert_float(spent.speed).is_equal_approx(tuning.stamina_pace[2], 0.0001)
	assert_float(FormationStamina.skill_shift(fresh)).is_equal(0.0)
	assert_float(FormationStamina.skill_shift(spent)).is_less(FormationStamina.skill_shift(tired))


func test_a_tired_pursuer_gives_up() -> void:
	var keen := _unit()
	var worn := _unit(10.0)

	assert_bool(FormationStamina.gives_up(keen)).is_false()
	assert_bool(FormationStamina.gives_up(worn)).is_true()
	assert_bool(FormationStamina.squad_gives_up(_squad([keen, worn]))).is_false()
	assert_bool(FormationStamina.squad_gives_up(_squad([worn, _unit(5.0), keen]))).is_true()
