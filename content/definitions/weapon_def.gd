class_name WeaponDef
extends Resource
## What a unit fights with (Decision 47): a unit's damage comes from its weapons, not from
## stats on the creature. Melee weapons (range 0) are used together when the unit is in
## the front rank of a fight; a ranged weapon is used from further back. The attack
## profile Decision 34 says units and emplacements share. See specs/07-data-resource-schemas.md.

@export var weapon_name: String = ""
@export var damage: int = 0
## acid, piercing, slashing, bludgeoning... no effect yet; resistances come later.
@export var damage_type: String = ""
## Reach in ranks (a rank is one cell - Decisions 48 and 68); 0 is melee.
@export var attack_range: int = 0
## Named traits, e.g. {"siege": 1} for weapons that damage structures (later).
@export var traits: Dictionary = {}


func is_melee() -> bool:
	return attack_range == 0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if damage < 0:
		errors.append("%s: damage must be >= 0, got %d" % [weapon_name, damage])
	if attack_range < 0:
		errors.append("%s: attack_range must be >= 0, got %d" % [weapon_name, attack_range])
	return errors
