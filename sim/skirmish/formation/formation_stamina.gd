class_name FormationStamina
extends RefCounted
## Stamina (spec 28 part 7; Decisions 117 and 120): a unit's pool - its constitution times
## stamina_per_constitution - spent running (pursuing as a formation, chasing on its own or
## fleeing) a second and per blow it strikes, faster the heavier its load, and regained a
## second when it neither runs nor strikes. Below stamina_tired of it a unit is tired,
## below stamina_spent spent: slower, and less skilled. A pursuit ends when its pursuers
## tire (FormationPursuit, ScrumPursuit), as well as at its leash: the chase wears off by
## itself. All numbers: BattleTuning. Pure over the squads it is given.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")


## Each unit's stamina spent on this tick's blows ([striker, ...]).
static func strike(blows: Array) -> void:
	var tuning := BattleTuning.current()
	for blow in blows:
		var striker: SkirmishUnit = blow[0]
		striker.stamina = maxf(0.0, striker.stamina - tuning.stamina_blow * striker.tiring)
		striker.exerted = true


## One tick of `seconds`: runners tire, the rest recover, and each unit's pace follows how
## tired it is.
static func step(squads: Array, seconds: float) -> void:
	var tuning := BattleTuning.current()
	for squad in squads:
		var running: bool = squad.state == SkirmishSquad.State.ROUTING
		running = running or (not squad.pursuit.is_empty() and not squad.pursuit["returning"])
		for unit in squad.living():
			if running or squad.chasers.has(unit.id):
				unit.stamina -= tuning.stamina_run * unit.tiring * seconds
			elif not unit.exerted:
				unit.stamina += tuning.stamina_recovery * seconds
			unit.stamina = clampf(unit.stamina, 0.0, unit.max_stamina)
			unit.exerted = false
			if unit.fresh_speed <= 0.0:
				unit.fresh_speed = unit.speed  # one made by hand, not from its sheet
			unit.speed = unit.fresh_speed * tuning.stamina_pace[stage(unit)]


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
