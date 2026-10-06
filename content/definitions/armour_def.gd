class_name ArmourDef
extends ItemDef
## Armour (Decisions 119 and 120, spec 28 part 5): an item that takes a flat amount off
## each blow its wearer suffers - `armour` off a mundane blow, `ward` off a magical one -
## after the wearer's weaknesses and resistances have had their say. A unit's own hide or
## a spell on it is its sheet's armour and ward; this is what it wears.

@export var armour: int = 0
@export var ward: int = 0


func validate() -> PackedStringArray:
	var errors := super()
	if armour < 0:
		errors.append("%s: armour must be >= 0, got %d" % [item_name, armour])
	if ward < 0:
		errors.append("%s: ward must be >= 0, got %d" % [item_name, ward])
	return errors
