class_name UnitDef
extends Resource
## Player unit definition (e.g. Grem). See specs/07-data-resource-schemas.md.

@export var cost_food: int = 0
@export var hp: int = 0
@export var dmg: int = 0
@export var speed: float = 0.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if cost_food < 0:
		errors.append("cost_food must be >= 0, got %d" % cost_food)
	if hp < 0:
		errors.append("hp must be >= 0, got %d" % hp)
	if dmg < 0:
		errors.append("dmg must be >= 0, got %d" % dmg)
	if speed < 0.0:
		errors.append("speed must be >= 0, got %f" % speed)
	return errors
