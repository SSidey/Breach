class_name FormationStamina
extends RefCounted
## Gaits and stamina (spec 28 part 7, Decisions 125 and 126). A unit marches at its speed
## or runs at its speed times its run pace, building up to it over a moment; a pursuer
## first reacts, giving a retreat its head start. A formation runs while it flees, pursues
## or retreats - unless its leader, or all its units, keep to a march then - or when the
## player hurries it; a unit chasing on its own runs; a spent unit can't run, so a
## formation of them walks. Marching costs nothing unless its load makes it (load_march_tiring);
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
				var pursuing: bool = not squad.pursuit.is_empty() or squad.chasers.has(unit.id)
				gait = _build(unit, pursuing, seconds)
				if unit.run_build > 0.0:
					_spend(unit, tuning.stamina_run * unit.tiring * seconds)
			elif marching and _march_cost(unit) > 0.0:
				_spend(unit, _march_cost(unit) * seconds)
			unit.was_running = runner
			if not unit.exerted:
				_breathe(unit, seconds)
			unit.exerted = false
			unit.speed = unit.fresh_speed * gait * tuning.stamina_pace[stage(unit)]


## True if the formation runs: fleeing; pursuing or retreating, unless its leader - or
## every one of its units - keeps to a march then ("pursues_at_march", "retreats_at_march");
## or hurried by the player - while it isn't fighting.
static func runs(squad: SkirmishSquad) -> bool:
	if squad.state == SkirmishSquad.State.ROUTING:
		return true
	if not squad.pursuit.is_empty() and not squad.pursuit["returning"]:
		return not _marches(squad, "pursues_at_march")
	if squad.state == SkirmishSquad.State.FIGHTING:
		return false
	if squad.order == SkirmishUnit.Order.RETREAT and not _marches(squad, "retreats_at_march"):
		return true
	return squad.hurry


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


## Its gait this tick of a run: building from its march to its run pace over
## run_build_seconds, a pursuer first reacting (the sooner, the quicker its wits).
static func _build(unit: SkirmishUnit, pursuing: bool, seconds: float) -> float:
	var tuning := BattleTuning.current()
	if not unit.was_running:
		var wits: float = maxf(1.0, unit.attributes.get("wits", UnitDef.AVERAGE))
		unit.run_build = -tuning.run_reaction * UnitDef.AVERAGE / wits if pursuing else 0.0
	unit.run_build += seconds
	var built := clampf(unit.run_build / maxf(tuning.run_build_seconds, 0.000001), 0.0, 1.0)
	return 1.0 + (unit.run_pace - 1.0) * built


## True if the squad keeps to a march for `trait_id`: its leader has it, or all its units.
static func _marches(squad: SkirmishSquad, trait_id: String) -> bool:
	var living := squad.living()
	if living.any(func(u): return u.leadership > 0 and u.traits.get(trait_id, 0) > 0):
		return true
	return not living.is_empty() and living.all(func(u): return u.traits.get(trait_id, 0) > 0)


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
