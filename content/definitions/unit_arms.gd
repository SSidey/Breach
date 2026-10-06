class_name UnitArms
extends RefCounted
## What a unit strikes with and wears, as the fight reckons it (Decisions 119 and 120,
## spec 28 part 5): each weapon's damage with its wielder's strength over the weapon's
## requirement times the weapon's own scaling (a maul much, a dagger little); the skill
## it wields them at - less without proficiency in their tags, more mastered, less for
## each point of strength it lacks; how far its damage may fall short (the weapons'
## floors); its armour and ward, its own and what it wears; and its encumbrance. Numbers:
## BattleTuning. Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const WeaponDef = preload("res://content/definitions/weapon_def.gd")
const ArmourDef = preload("res://content/definitions/armour_def.gd")


## [[damage, damage type, magical], ...] for the weapons it strikes with: all its melee
## weapons together, or its best ranged one.
static func parts(unit_def: UnitDef, ranged: bool) -> Array:
	var out := []
	for weapon in _used(unit_def, ranged):
		out.append([_damage(unit_def, weapon), weapon.damage_type, weapon.magical])
	return out


## The least share of its damage a blow may deal before skill lifts it: its weapons'
## floors, weighted by their damage (1 with no weapons).
static func floor_share(unit_def: UnitDef, ranged: bool) -> float:
	var total := 0.0
	var weighted := 0.0
	for weapon in _used(unit_def, ranged):
		total += weapon.damage
		weighted += weapon.damage * weapon.damage_floor
	return weighted / total if total > 0.0 else 1.0


## Its melee or ranged skill as it wields its weapons: shifted by its proficiency with the
## least familiar of them, and lowered for the most strength any of them asks that it
## lacks.
static func skill(unit_def: UnitDef, ranged: bool) -> int:
	var tuning := BattleTuning.current()
	var trained := unit_def.ranged_skill if ranged else unit_def.melee_skill
	var least := 2
	var short := 0
	for weapon in _used(unit_def, ranged):
		least = mini(least, _proficiency(unit_def, weapon))
		short = maxi(short, weapon.strength_requirement - unit_def.strength)
	var shift: float = [tuning.item_untrained_skill, 0.0, tuning.item_mastered_skill][least]
	return maxi(0, roundi(trained + shift - short * tuning.item_weak_skill))


## Its encumbrance (Decision 120): 0 none, 1 mild, 2 steep, 3 immobile - the weight of what
## it carries (innate parts weigh nothing) against its carry limit from strength, a hauler
## carrying more before it can't move.
static func load_stage(unit_def: UnitDef) -> int:
	var tuning := BattleTuning.current()
	var carried := 0.0
	for item in unit_def.items:
		carried += item.weight
	var limit := unit_def.strength * tuning.load_per_strength
	var most := tuning.load_most + unit_def.trait_level("hauler") * tuning.load_hauler
	if carried <= limit * tuning.load_easy:
		return 0
	if carried <= limit:
		return 1
	return 2 if carried <= limit * most else 3


## Its armour (against mundane blows) and its ward (against magical ones): its own and
## what it wears.
static func protection(unit_def: UnitDef) -> Vector2i:
	var out := Vector2i(unit_def.armour, unit_def.ward)
	for item in unit_def.items:
		if item is ArmourDef:
			out += Vector2i(item.armour, item.ward)
	return out


static func _used(unit_def: UnitDef, ranged: bool) -> Array:
	if ranged:
		var best := unit_def.ranged_weapon()
		return [] if best == null else [best]
	return unit_def.weapons().filter(func(w): return w.is_melee())


static func _damage(unit_def: UnitDef, weapon: WeaponDef) -> float:
	var over := maxi(0, unit_def.strength - weapon.strength_requirement)
	return weapon.damage + weapon.strength_scaling * over


## 0 untrained, 1 trained, 2 mastered: its best level in the weapon's tags; trained in an
## innate weapon or one with no tags.
static func _proficiency(unit_def: UnitDef, weapon: WeaponDef) -> int:
	if weapon.innate or weapon.tags.is_empty():
		return 1
	var best := 0
	for tag in weapon.tags:
		best = maxi(best, int(unit_def.proficiencies.get(tag, 0)))
	return mini(best, 2)
