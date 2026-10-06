class_name FormationUnits
extends RefCounted
## Makes a formation SkirmishUnit from its UnitDef (specs/22-formation-feel-test.md): its
## footprint, preferred band and - from its weapons (Decision 47) - its melee strike (all
## melee weapons together) and its best ranged weapon. Pure.

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


static func make(
	unit_def: UnitDef, place: Vector2i, faction_id: String, direction: int, unit_id: int
) -> SkirmishUnit:
	var unit := SkirmishUnit.new()
	unit.id = unit_id
	unit.faction_id = faction_id
	unit.hp = unit_def.hp
	unit.max_hp = unit_def.hp
	unit.dmg = unit_def.melee_damage()
	unit.speed = unit_def.speed
	unit.footprint_depth = unit_def.footprint_depth
	unit.footprint_width = unit_def.footprint_width
	unit.preferred_position = unit_def.preferred_position
	unit.position_priority = unit_def.position_priority
	unit.detection = unit_def.detection_range
	unit.courage = unit_def.courage
	unit.leadership = unit_def.leadership
	unit.tactics = unit_def.tactics.duplicate()
	unit.height = unit_def.height
	unit.initiative = unit_def.initiative
	unit.discipline = unit_def.discipline
	unit.turn_rate = unit_def.turn_rate
	unit.backward_pace = unit_def.backward_pace
	unit.definition = unit_def
	unit.tags = unit_def.tags.duplicate()
	for attribute in UnitDef.ATTRIBUTES:
		unit.attributes[attribute] = unit_def.get(attribute)
	unit.traits = unit_def.traits.duplicate()
	for item in unit_def.items:  # a tool's traits are its carrier's (Decision 120)
		for trait_id in item.traits:
			if unit_def.trait_level(trait_id) > 0:
				unit.traits[trait_id] = unit_def.trait_level(trait_id)
	unit.melee_seconds = unit_def.melee_seconds()
	unit.melee_skill = unit_def.melee_skill
	unit.ranged_skill = unit_def.ranged_skill
	unit.defence = unit_def.defence
	unit.critical = unit_def.critical
	unit.parries = unit_def.can_parry()
	var ranged := unit_def.ranged_weapon()
	if ranged != null:
		unit.attack_range = ranged.attack_range
		unit.ranged_dmg = ranged.damage
		unit.damage_type = ranged.damage_type
		unit.ranged_seconds = ranged.attack_seconds / unit_def.attack_speed
	unit.rank = place.x
	unit.column = place.y
	unit.advance_direction = direction
	return unit
