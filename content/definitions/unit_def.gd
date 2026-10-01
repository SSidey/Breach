class_name UnitDef
extends Resource
## Player unit definition (e.g. Grem). See specs/07-data-resource-schemas.md.

## Where in a formation the unit wants to stand (Decision 46).
enum Position { FRONT, MID, BACK }

const MAX_FOOTPRINT := 8

@export var cost_food: int = 0
@export var hp: int = 0
@export var dmg: int = 0
@export var speed: float = 0.0
## Formation slots the unit occupies, depth (ranks) x width (columns), per Decision 40:
## 1x1 a grem, 2x1 cavalry, 2x2 a brute, up to 8x8 (a dragon, the widest lane).
@export var footprint_depth: int = 1
@export var footprint_width: int = 1
## Seconds one of the domain's builders takes to build this unit (Decision 45).
@export var build_seconds: float = 1.0
## The formation band the unit prefers, and its claim within that band (higher claims a
## forward place first). Reinforcements re-form by these (Decision 46).
@export var preferred_position: Position = Position.FRONT
@export var position_priority: int = 0
## Reach in ranks (formation cells); 0 fights in melee only (Decision 46).
@export var attack_range: int = 0


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
	for field in ["footprint_depth", "footprint_width"]:
		if get(field) < 1 or get(field) > MAX_FOOTPRINT:
			errors.append("%s must be 1..%d, got %d" % [field, MAX_FOOTPRINT, get(field)])
	for field in ["position_priority", "attack_range"]:
		if get(field) < 0:
			errors.append("%s must be >= 0, got %d" % [field, get(field)])
	if build_seconds <= 0.0:
		errors.append("build_seconds must be > 0, got %f" % build_seconds)
	return errors
