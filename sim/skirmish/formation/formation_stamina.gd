class_name FormationStamina
extends RefCounted
## Gaits and stamina (spec 28 part 7, Decision 125). A unit marches at its speed or runs at
## its speed times its run pace. A formation runs while it flees (routing), pursues, or
## retreats or advances hurried - by the player's order, or on a retreat its leader
## "hastens" - and a unit chasing on its own runs; a spent unit can't run, so a formation
## of them walks. Marching costs nothing unless its load makes it (load_march_tiring);
## running costs stamina_run a second and each blow stamina_blow, faster the heavier the
## load. Each cost restarts a breather: once stamina_delay seconds pass with none, stamina
## is regained at stamina_recovery a second - the delay shorter and the rate faster the
## hardier the unit (its constitution), the rate times its condition. Below stamina_tired
## a unit is tired, below stamina_spent spent: slower and less skilled; a pursuit ends when
## its pursuers tire, as well as at its leash. All numbers: BattleTuning. Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")


## Each unit's stamina spent on this tick's blows ([striker, ...]).
static func strike(blows: Array) -> void:
	for blow in blows:
		_spend(blow[0], BattleTuning.current().stamina_blow * blow[0].tiring)


## One tick of `seconds`: runners and laden marchers tire, the rest recover after their
## breather, and each unit's pace follows its gait and how tired it is.
static func step(squads: Array, seconds: float) -> void:
	var tuning := BattleTuning.current()
	for squad in squads:
		var running := runs(squad)
		var marching: bool = squad.state == SkirmishSquad.State.MOVING
		for unit in squad.living():
			if unit.fresh_speed <= 0.0:
				unit.fresh_speed = unit.speed  # one made by hand, not from its sheet
			var gait := 1.0
			var runner: bool = (running or squad.chasers.has(unit.id)) and stage(unit) < 2
			if runner:
				gait = unit.run_pace
				_spend(unit, tuning.stamina_run * unit.tiring * seconds)
			elif marching and _march_cost(unit) > 0.0:
				_spend(unit, _march_cost(unit) * seconds)
			if not unit.exerted:
				_breathe(unit, seconds)
			unit.exerted = false
			unit.speed = unit.fresh_speed * gait * tuning.stamina_pace[stage(unit)]


## True if the formation runs: fleeing, pursuing, or hurried - ordered to, or retreating
## under a leader who hastens - while it isn't fighting.
static func runs(squad: SkirmishSquad) -> bool:
	if squad.state == SkirmishSquad.State.ROUTING:
		return true
	if not squad.pursuit.is_empty() and not squad.pursuit["returning"]:
		return true
	if squad.state == SkirmishSquad.State.FIGHTING:
		return false
	if squad.hurry:
		return true
	if squad.order == SkirmishUnit.Order.RETREAT:
		for unit in squad.living():
			if unit.leadership > 0 and unit.traits.get("hastens", 0) > 0:
				return true
	return false


## 0 fresh, 1 tired, 2 spent.
static func stage(unit: SkirmishUnit) -> int:
	var tuning := BattleTuning.current()
	var share := unit.stamina / maxf(unit.max_stamina, 0.000001)
	if share < tuning.stamina_spent:
		return 2
	return 1 if share < tuning.stamina_tired else 0


## The shift to its blows' margins its tiredness makes.
static func skill_shift(unit: SkirmishUnit) -> float:
	return BattleTuning.current().stamina_skill[stage(unit)]


## True if the unit is too tired to keep up a chase.
static func gives_up(unit: SkirmishUnit) -> bool:
	return unit.stamina < unit.max_stamina * BattleTuning.current().stamina_give_up


## True if most of the squad's units are too tired to keep up a chase.
static func squad_gives_up(squad: SkirmishSquad) -> bool:
	var living := squad.living()
	var tired := living.filter(func(u): return gives_up(u)).size()
	return not living.is_empty() and tired * 2 > living.size()


## Spends stamina: it restarts the unit's breather.
static func _spend(unit: SkirmishUnit, amount: float) -> void:
	unit.stamina = maxf(0.0, unit.stamina - amount)
	unit.exerted = true
	unit.breather = 0.0


## A tick without cost: once its breather is long enough, it recovers.
static func _breathe(unit: SkirmishUnit, seconds: float) -> void:
	var tuning := BattleTuning.current()
	var hardiness := (
		maxf(1.0, unit.attributes.get("constitution", UnitDef.AVERAGE)) / UnitDef.AVERAGE
	)
	unit.breather += seconds
	if unit.breather < tuning.stamina_delay / hardiness:
		return
	var condition := clampf(unit.condition, 0.0, tuning.condition_cap)
	var gain := tuning.stamina_recovery * hardiness * condition * seconds
	unit.stamina = minf(unit.max_stamina, unit.stamina + gain)


static func _march_cost(unit: SkirmishUnit) -> float:
	var costs: Array[float] = BattleTuning.current().load_march_tiring
	return costs[clampi(unit.load_stage, 0, costs.size() - 1)]
