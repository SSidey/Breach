class_name RoutFlight
extends RefCounted
## How a disorderly flight spreads (Decision 99, spec 27 round 10): a fleeing unit makes for
## the nearest safety. With a standing friendly formation between it and home (its
## refuge), it steers for that friend, which catches it (RoutCatch). Otherwise a rout's
## units don't keep to their route's line but fan out from it, each by its own angle -
## seeded by the battle and the unit - up to rout_fan_degrees either side, until
## rout_fan_cells out (BattleTuning) or the ground to the side can't be crossed. A ragged
## retreat fans out by its disorder (FormationWithdraw). Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const RoutCatch = preload("res://sim/skirmish/formation/rout_catch.gd")
const BattleRolls = preload("res://sim/skirmish/formation/battle_rolls.gd")
const DetMath = preload("res://sim/skirmish/formation/det_math.gd")


## The unit's own flight angle (radians) off its route's line, at full disorder.
static func fan(unit: SkirmishUnit, fight_seed: int) -> float:
	var roll := BattleRolls.uniform(fight_seed, [unit.id, "fan"]) * 2.0 - 1.0
	return deg_to_rad(BattleTuning.current().rout_fan_degrees) * roll


## A router's step (its `entry` in its squad's `fleeing`): towards `home` along the route
## and out to the side, or towards its refuge. `motion` is [pace (cells a tick at speed 1),
## fight seed, terrain or null, where it stands, the squads].
static func step(
	squad: SkirmishSquad, unit: SkirmishUnit, entry: Dictionary, home: float, motion: Array
) -> void:
	var full: float = unit.speed * motion[0]
	var aside := DetMath.sin(fan(unit, motion[1])) * full
	var fanned: float = entry.get("fanned", 0.0)
	var heading: Vector2 = (
		squad.route.heading_at(entry["along"]) if squad.route != null else Vector2.RIGHT
	)
	var side := heading.orthogonal()
	var at: Vector2 = motion[3]
	var refuge = _refuge(squad, at, [entry["along"], home, motion[1]], motion[4])
	if refuge != null:  # it makes for the friend, turning aside only if it would miss it
		var most := DetMath.sin(deg_to_rad(BattleTuning.current().rout_fan_degrees)) * full
		aside = clampf(_short_of(refuge, at, side), -most, most)
	var terrain = motion[2]
	var open: bool = terrain == null or terrain.factor(unit, at, at + side * aside) > 0.0
	if (
		(refuge == null and absf(fanned + aside) > BattleTuning.current().rout_fan_cells)
		or not open
	):
		aside = 0.0
	entry["fanned"] = fanned + aside
	entry["offset"] += side * aside
	entry["along"] = move_toward(entry["along"], home, sqrt(full * full - aside * aside))


## The standing friendly formation whose unit is nearest `at`, among those between the
## router and home on the route - `along` is [its distance along it, home's, the fight
## seed] - or null if there is none. Equally near ones go by their draws (Decision 97).
static func _refuge(squad: SkirmishSquad, at: Vector2, along: Array, squads: Array):
	if squad.route == null:
		return null
	var best = null
	var best_key := []
	for friend in squads:
		if friend == squad or friend.faction_id != squad.faction_id or not RoutCatch.stands(friend):
			continue
		for unit in friend.living():
			var there := ScrumReach.at(friend, unit)
			var ahead: bool = (
				(squad.route.distance_of(there) - along[0]) * (along[1] - along[0]) > 0.0
			)
			var key := [
				snappedf(there.distance_to(at), 0.000001), ScrumContest.draw(unit, along[2])
			]
			if ahead and (best == null or key < best_key):
				best = friend
				best_key = key
	return best


## How far across its route (along `side`) a router at `at` must turn aside to run into
## the friend's ranks: 0 if it is already heading into them.
static func _short_of(friend: SkirmishSquad, at: Vector2, side: Vector2) -> float:
	var across: Array = friend.living().map(
		func(u): return (ScrumReach.at(friend, u) - at).dot(side)
	)
	var lowest: float = across.min() - 0.5
	var highest: float = across.max() + 0.5
	return clampf(0.0, lowest, highest)
