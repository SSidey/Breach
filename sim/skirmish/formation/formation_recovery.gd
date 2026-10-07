class_name FormationRecovery
extends RefCounted
## What the wounded come to (Decisions 121, 125 and 126). A unit's **condition** is 1 less
## wounds_condition for each wound past those it is hardened to (a "hardened N" trait), and
## later its other statuses; below condition_drain_below it loses condition_drain HP a
## second, standing or downed - so one in a bad enough state dies of it. A **downed** unit
## lies a seeded while (wounds_wake_seconds, shorter the hardier it is) and then comes to at
## 1 HP: it rejoins its formation at the back if that formation stands and it can see it,
## and otherwise makes for home on its own, as a lone router (FormationStrays), to be
## caught, taken, or reach the reserve. **Regeneration** mends HP up to its limit per rest,
## times its condition, through damage; a blow of a type it fears stops it a while; downed,
## it runs only with "regenerates_downed". Pure over the squads it is given.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const BattleRolls = preload("res://sim/skirmish/formation/battle_rolls.gd")
const FormationDeaths = preload("res://sim/skirmish/formation/formation_deaths.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")


## One tick of `seconds`. Returns [[unit, its squad], ...] for those that came to apart from
## their formation, to make for home (FormationStrays).
static func step(squads: Array, seconds: float, tick: int, fight_seed: int, events: Array) -> Array:
	var strays := []
	for squad in squads:
		for unit in squad.units:
			var downed: bool = unit.state in [SkirmishUnit.State.DOWNED, SkirmishUnit.State.CARRIED]
			if not (unit.is_alive() or downed):
				continue
			unit.condition = condition_of(unit)
			_regenerate(unit, downed, seconds)
			if _drain(unit, seconds) and downed and unit.hp <= -FormationDeaths.depth(unit):
				unit.state = SkirmishUnit.State.DEAD
				events.append(FormationEvents.unit_event("died_of_wounds", tick, squad, unit))
				continue
			if downed and _wakes(unit, seconds, fight_seed):
				unit.hp = maxi(unit.hp, 1)
				unit.state = SkirmishUnit.State.MOVING
				if _rejoins(unit, squad):
					events.append(FormationEvents.unit_event("came_to", tick, squad, unit))
				else:
					strays.append([unit, squad])
					var extra := {"alone": true}
					events.append(FormationEvents.unit_event("came_to", tick, squad, unit, extra))
	return strays


## Its condition: 1, less a step for each wound past those it is hardened to; 0 to the cap.
static func condition_of(unit: SkirmishUnit) -> float:
	var tuning := BattleTuning.current()
	var wounds := maxi(0, unit.wounded - int(unit.traits.get("hardened", 0)))
	return clampf(1.0 - wounds * tuning.wounds_condition, 0.0, tuning.condition_cap)


## A blow that landed of a type that stops the target's regeneration stops it a while.
static func scorch(target: SkirmishUnit, parts: Array, dealt: int) -> void:
	if dealt <= 0 or target.regeneration_stops.is_empty():
		return
	for part in parts:
		if target.regeneration_stops.has(part[1]):
			target.regeneration_halt = BattleTuning.current().wounds_regeneration_halt
			return


static func _regenerate(unit: SkirmishUnit, downed: bool, seconds: float) -> void:
	if unit.regeneration <= 0.0:
		return
	if downed and unit.traits.get("regenerates_downed", 0) <= 0:
		return
	if unit.regeneration_halt > 0.0:
		unit.regeneration_halt = maxf(0.0, unit.regeneration_halt - seconds)
		return
	var gain := minf(unit.regeneration * unit.condition * seconds, unit.regeneration_left)
	gain = minf(gain, float(unit.max_hp - unit.hp) - unit.regeneration_carry)
	if gain <= 0.0:
		return
	unit.regeneration_left -= gain
	unit.regeneration_carry += gain
	var whole := floori(unit.regeneration_carry + 0.000001)  # float sums fall short
	unit.hp += whole
	unit.regeneration_carry -= whole


## A poor condition drains its HP; true if it lost any this tick.
static func _drain(unit: SkirmishUnit, seconds: float) -> bool:
	var tuning := BattleTuning.current()
	if unit.condition >= tuning.condition_drain_below:
		return false
	unit.drain_carry += tuning.condition_drain * seconds
	var whole := floori(unit.drain_carry + 0.000001)
	unit.hp -= whole
	unit.drain_carry -= whole
	return whole > 0


## Counts down its time downed, reckoning it first if it hasn't been; true once it is up.
static func _wakes(unit: SkirmishUnit, seconds: float, fight_seed: int) -> bool:
	var tuning := BattleTuning.current()
	if unit.wake_left < 0.0:
		var spread: Array[float] = tuning.wounds_wake_spread
		var roll := BattleRolls.uniform(fight_seed, [unit.id, unit.wounded, "wake"])
		var hardiness: float = (
			maxf(1.0, unit.attributes.get("constitution", UnitDef.AVERAGE)) / UnitDef.AVERAGE
		)
		unit.wake_left = tuning.wounds_wake_seconds * lerpf(spread[0], spread[1], roll) / hardiness
	unit.wake_left -= seconds
	return unit.wake_left <= 0.0


## True if it rejoins its formation at the back: that formation stands and it can see it.
static func _rejoins(unit: SkirmishUnit, squad: SkirmishSquad) -> bool:
	if squad.state in [SkirmishSquad.State.DESTROYED, SkirmishSquad.State.ROUTING]:
		return false
	var living := squad.living().filter(func(u): return u != unit)
	if living.is_empty():
		return false
	if not living.any(func(u): return u.position.distance_to(unit.position) <= unit.detection):
		return false
	var back := 0
	for other in living:
		back = maxi(back, other.rank + other.footprint_depth)
	unit.rank = back
	unit.column = 0
	squad.reforming = true
	return true
