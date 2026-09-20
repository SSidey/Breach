class_name ResponseUnitDef
extends Resource
## Core Task Force response unit definition (Messenger, Hero Party). See
## specs/07-data-resource-schemas.md and specs/04-suspicion-and-response.md.
##
## Deliberately independent of UnitDef (no inheritance, no embedding) - a Task Force
## response unit is not a kind-of player unit in any substitutable sense; the field
## shape is only coincidentally similar.

@export var purpose: String = ""
@export var hp: int = 0
@export var dmg: int = 0
@export var speed: float = 0.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if purpose.is_empty():
		errors.append("purpose must not be empty")
	if hp < 0:
		errors.append("hp must be >= 0, got %d" % hp)
	if dmg < 0:
		errors.append("dmg must be >= 0, got %d" % dmg)
	if speed < 0.0:
		errors.append("speed must be >= 0, got %f" % speed)
	return errors
