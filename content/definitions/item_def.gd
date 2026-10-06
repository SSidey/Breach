class_name ItemDef
extends Resource
## Anything a unit carries (Decision 120, spec 28): a weapon (WeaponDef), armour or a tool.
## An item names the slots it takes - a unit carries it only if its body has them free (a
## creature with no hands has no hand slot) - and has a weight (load), a strength needed
## to wield it well, tags a unit may be proficient with (axe, polearm, heavy armour), and
## rated traits it grants whoever carries it (a shovel, burrower 1: Decision 54). A
## natural weapon (fists, a bite, a claw) is innate.

@export var item_name: String = ""
## The slots it takes (hand, hand for a two-handed spear); none for an innate item.
@export var slots: Array[String] = []
## Its weight, in load.
@export var weight: float = 0.0
## The strength needed to wield it well.
@export var strength_requirement: int = 0
## What kind of item it is, for proficiency (axe, polearm, heavy armour...).
@export var tags: Array[String] = []
## Rated traits it grants whoever carries it, e.g. {"burrower": 1}, or that mark what it
## does, e.g. {"siege": 1} for a weapon that damages structures.
@export var traits: Dictionary = {}
## Part of the creature (fists, a bite, a claw, its spit): it can't be dropped or taken,
## weighs nothing and takes no slot.
@export var innate: bool = false


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if weight < 0.0:
		errors.append("%s: weight must be >= 0, got %f" % [item_name, weight])
	if strength_requirement < 0:
		errors.append(
			"%s: strength_requirement must be >= 0, got %d" % [item_name, strength_requirement]
		)
	if innate and (weight > 0.0 or not slots.is_empty()):
		errors.append("%s: an innate item weighs nothing and takes no slot" % item_name)
	return errors
