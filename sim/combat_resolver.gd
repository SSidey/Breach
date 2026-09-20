class_name CombatResolver
extends RefCounted
## Horde-vs-blocker combat, ported faithfully from
## reference/breach-prototype.html's killUnitsWithDamage/resolveFrontCombat/
## resolveHeroParty (Decision 11) - not invented. See
## specs/02-lane-movement-and-combat.md for the full rule in prose.
##
## A horde is an Array of {"hp": int, "dmg": int} dictionaries (individually-tracked
## units). A blocker is a single {"hp": int, "dmg": int} dictionary (a fort/garrison
## or a Hero Party - CombatResolver doesn't care which). Plain data in, plain data
## out - never reads LaneSimulation state directly.


static func resolve(horde: Array, blocker: Dictionary) -> Dictionary:
	var horde_dmg := 0
	for unit in horde:
		horde_dmg += unit["dmg"]

	var remaining_blocker_hp: int = blocker["hp"] - horde_dmg
	if remaining_blocker_hp <= 0:
		# The blocker dies before it can retaliate - the horde takes zero casualties.
		return {
			"blocker_destroyed": true,
			"remaining_blocker_hp": 0,
			"surviving_horde": horde.duplicate(),
		}

	return {
		"blocker_destroyed": false,
		"remaining_blocker_hp": remaining_blocker_hp,
		"surviving_horde": _apply_damage_weakest_first(horde, blocker["dmg"]),
	}


static func _apply_damage_weakest_first(horde: Array, dmg_pool: int) -> Array:
	var sorted_horde: Array = horde.duplicate()
	sorted_horde.sort_custom(func(a, b): return a["hp"] < b["hp"])

	var index := 0
	while dmg_pool > 0 and index < sorted_horde.size():
		var unit: Dictionary = sorted_horde[index].duplicate()
		unit["hp"] -= dmg_pool
		if unit["hp"] <= 0:
			dmg_pool = -unit["hp"]
			sorted_horde.remove_at(index)
		else:
			sorted_horde[index] = unit
			dmg_pool = 0

	return sorted_horde
