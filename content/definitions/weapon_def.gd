class_name WeaponDef
extends ItemDef
## What a unit fights with (Decision 47): a unit's damage comes from its weapons, not from
## stats on the creature. Melee weapons (range 0) are used together when the unit is in
## the front rank of a fight; a ranged weapon is used from further back. The attack
## profile Decision 34 says units and emplacements share. A weapon is an item (ItemDef:
## slots, weight, tags, traits). See specs/07-data-resource-schemas.md.

@export var damage: int = 0
## acid, piercing, slashing, bludgeoning... no effect yet; resistances come later.
@export var damage_type: String = ""
## Reach in ranks (a rank is one cell - Decisions 48 and 68); 0 is melee.
@export var attack_range: int = 0
## Seconds between its blows (Decision 120): an unwieldy weapon strikes more slowly. The
## wielder's attack speed scales it.
@export var attack_seconds: float = 1.0


## A natural melee weapon striking for `damage` (Decision 120): what a unit fights
## with when it carries nothing else.
static func innate_weapon(damage_of: int, named: String = "fists") -> WeaponDef:
	var weapon := WeaponDef.new()
	weapon.item_name = named
	weapon.damage = damage_of
	weapon.innate = true
	return weapon


func is_melee() -> bool:
	return attack_range == 0


func validate() -> PackedStringArray:
	var errors := super()
	if damage < 0:
		errors.append("%s: damage must be >= 0, got %d" % [item_name, damage])
	if attack_range < 0:
		errors.append("%s: attack_range must be >= 0, got %d" % [item_name, attack_range])
	if attack_seconds <= 0.0:
		errors.append("%s: attack_seconds must be > 0, got %f" % [item_name, attack_seconds])
	return errors
