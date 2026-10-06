class_name BlowDamage
extends RefCounted
## What a landed blow deals (Decision 119, spec 28 part 5). Its weapons' damage is rolled
## within their range: no lower than their floor share, which the striker's skill lifts
## toward the full (all of the way at damage_floor_skill; skill past that spills into
## its margin, BlowLanding). How it landed takes its share (a graze part, a critical its
## multiple). Each weapon's part is then taken against the target by its damage type -
## weakness, resistance, immunity - and its armour comes off the mundane parts, its ward
## off the magical. A blow it doesn't stop deals at least 1. Numbers: BattleTuning. Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const BlowRoll = preload("res://sim/skirmish/formation/blow_roll.gd")


## The damage a blow of `nominal` that landed as `landed` deals to the target; `roll` (0 to
## 1) places it in its weapons' range (1: the full).
static func dealt(
	striker: SkirmishUnit,
	target: SkirmishUnit,
	nominal: int,
	landed: String,
	ranged: bool,
	roll: float
) -> int:
	if landed == BlowRoll.PARRIED or landed == BlowRoll.DODGED or nominal <= 0:
		return 0
	var parts: Array = striker.ranged_parts if ranged else striker.melee_parts
	var whole := 0.0
	for part in parts:
		whole += part[0]
	if whole <= 0.0:
		parts = [[float(nominal), "", false]]
		whole = nominal
	var share := _share(striker, ranged, roll) * _landed_share(landed, striker.critical)
	var mundane := 0.0
	var magical := 0.0
	for part in parts:
		var amount: float = part[0] * nominal / whole * share * kind_factor(target, part[1])
		if part[2]:
			magical += amount
		else:
			mundane += amount
	var total := maxf(0.0, mundane - target.armour) + maxf(0.0, magical - target.ward)
	return maxi(1, roundi(total)) if total > 0.0 else 0


## A damage type's worth against the target: its weakness, resistance or immunity to it
## (immunity first, then resistance), else 1.
static func kind_factor(target: SkirmishUnit, damage_type: String) -> float:
	var tuning := BattleTuning.current()
	if target.immunities.has(damage_type):
		return tuning.damage_immune
	if target.resistances.has(damage_type):
		return tuning.damage_resist
	return tuning.damage_weak if target.weaknesses.has(damage_type) else 1.0


## The margin a striker's skill past damage_floor_skill adds (crits, not more damage).
static func spill(striker: SkirmishUnit, ranged: bool) -> float:
	var tuning := BattleTuning.current()
	var skill := striker.ranged_skill if ranged else striker.melee_skill
	return maxf(0.0, skill - tuning.damage_floor_skill) * tuning.damage_spill


## Where in its weapons' range the roll falls: from its floor, lifted by skill, to 1.
static func _share(striker: SkirmishUnit, ranged: bool, roll: float) -> float:
	var skill := striker.ranged_skill if ranged else striker.melee_skill
	var lift := clampf(skill / maxf(1.0, BattleTuning.current().damage_floor_skill), 0.0, 1.0)
	var low := lerpf(striker.ranged_floor if ranged else striker.melee_floor, 1.0, lift)
	return lerpf(low, 1.0, roll)


static func _landed_share(landed: String, critical: float) -> float:
	if landed == BlowRoll.GRAZED:
		return BattleTuning.current().blow_graze_share
	return critical if landed == BlowRoll.CRITICAL else 1.0
