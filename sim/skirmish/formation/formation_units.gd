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
	var ranged := unit_def.ranged_weapon()
	if ranged != null:
		unit.attack_range = ranged.attack_range
		unit.ranged_dmg = ranged.damage
		unit.damage_type = ranged.damage_type
	unit.rank = place.x
	unit.column = place.y
	unit.advance_direction = direction
	return unit
