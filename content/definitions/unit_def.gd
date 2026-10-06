class_name UnitDef
extends Resource
## A unit type's sheet (Decision 117, spec 28; specs/07-data-resource-schemas.md): its
## archetype tags, attributes and rated traits; body; movement; mind; senses; band; what
## it fights with; and its cost. Derived stats (load, death's door...) are worked out from
## the attributes where they are used, never set here.

## Where in a formation the unit wants to stand (Decision 46).
enum Position { FRONT, MID, BACK }

const MAX_FOOTPRINT := 8
## The five attributes (Decision 117), each defaulting to AVERAGE.
const ATTRIBUTES := ["strength", "agility", "constitution", "willpower", "wits"]
const AVERAGE := 10

## Archetype tags tech can target as a group, beside the type itself (human, martial,
## cavalry, archer...).
@export var tags: Array[String] = []
## Attributes (Decision 117): strength (load, wield and damage scaling, shoving), agility
## (dodge, attack speed, turning, initiative), constitution (HP, stamina, physical maladies,
## death's door), willpower (magical maladies, fear, courage, ward) and wits (casting,
## mana, initiative, perception). AVERAGE is ordinary.
@export var strength: int = AVERAGE
@export var agility: int = AVERAGE
@export var constitution: int = AVERAGE
@export var willpower: int = AVERAGE
@export var wits: int = AVERAGE
## Rated traits (Decision 64), id -> level: climber 2, darksight 1, mob 16...
@export var traits: Dictionary = {}
@export var cost_food: int = 0
@export var hp: int = 0
## Its natural blow (fists, bite), struck when it has no melee weapon; every unit so far
## carries its natural weapons as weapons. Retires when weapons become items (spec 28).
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
## How far it detects others, in cells (Decision 87; placeholder). Line of sight and light
## come with terrain.
@export var detection_range: float = 40.0
## Its will to fight (Decision 82): a formation's morale ceiling is its units' mean courage.
@export var courage: int = 60
## How much it steadies a formation it leads (Decision 81); 0 for rank and file.
@export var leadership: int = 0
## How it leads (Decision 81), e.g. "coordinated": times a waiting wave's departure from
## what it sees (Decision 87).
@export var tactics: Array[String] = []
## How tall it stands, in cells (Decision 85): water a quarter of this deep slows it.
@export var height: float = 1.0
## How quickly it acts (Decision 88; placeholder, equal for all until spec 28): it wins a
## contested cell in the scrum over a slower-witted unit arriving at the same time.
@export var initiative: int = 10
## How drilled it is (Decision 92; placeholder: rank and file 30, drilled 60): a
## formation's mean, bolstered by its leader, decides whether it re-forms as a whole to meet
## a flank and how fast it re-forms.
@export var discipline: int = 30
## How it turns and backs away (Decision 95; placeholders until spec 28): degrees a second
## it turns, and the share of its speed it makes moving straight back (sideways is between).
@export var turn_rate: float = 450.0
@export var backward_pace: float = 0.4
## What it fights with (Decision 47). Without weapons it strikes once for `dmg`.
@export var weapons: Array[WeaponDef] = []


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
	if position_priority < 0:
		errors.append("position_priority must be >= 0, got %d" % position_priority)
	for weapon in weapons:
		if weapon == null:
			errors.append("weapons must not contain an empty entry")
		else:
			errors.append_array(weapon.validate())
	if build_seconds <= 0.0:
		errors.append("build_seconds must be > 0, got %f" % build_seconds)
	for attribute in ATTRIBUTES:
		if get(attribute) < 0:
			errors.append("%s must be >= 0, got %d" % [attribute, get(attribute)])
	for trait_id in traits:
		if not trait_id is String or not traits[trait_id] is int or traits[trait_id] < 0:
			errors.append("traits must map names to levels >= 0, got %s" % str(trait_id))
	return errors


## The level of a rated trait it has (0: not at all).
func trait_level(trait_id: String) -> int:
	return int(traits.get(trait_id, 0))


## The damage of one melee strike: every melee weapon together, or `dmg` without weapons.
func melee_damage() -> int:
	if weapons.is_empty():
		return dmg
	var total := 0
	for weapon in weapons:
		if weapon.is_melee():
			total += weapon.damage
	return total


## The hardest-hitting ranged weapon, or null for a melee-only unit.
func ranged_weapon() -> WeaponDef:
	var best: WeaponDef = null
	for weapon in weapons:
		if not weapon.is_melee() and (best == null or weapon.damage > best.damage):
			best = weapon
	return best
