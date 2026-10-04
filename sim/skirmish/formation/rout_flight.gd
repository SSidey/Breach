class_name RoutFlight
extends RefCounted
## How a disorderly flight spreads (Decision 99, spec 27 round 10): a fleeing unit makes for
## the nearest safety. With a standing friendly formation between it and home (its
## refuge), it steers for that friend, which catches it (RoutCatch). Otherwise a rout's
## units don't keep to their route's line but fan out from it, each by its own angle -
## seeded by the battle and the unit - up to FAN_DEGREES either side, until FAN_CELLS out
## or the ground to the side can't be crossed. A ragged retreat fans out by its disorder
## (FormationWithdraw). Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const RoutCatch = preload("res://sim/skirmish/formation/rout_catch.gd")
const BattleRolls = preload("res://sim/skirmish/formation/battle_rolls.gd")

## A wholly disorderly flight fans out up to this far off its route's line, and this many
## cells out at most (placeholders).
const FAN_DEGREES := 45.0
const FAN_CELLS := 6.0


## The unit's own flight angle (radians) off its route's line, at full disorder.
static func fan(unit: SkirmishUnit, fight_seed: int) -> float:
	var roll := BattleRolls.uniform(fight_seed, [unit.id, "fan"]) * 2.0 - 1.0
	return deg_to_rad(FAN_DEGREES) * roll


## A router's step (its `entry` in its squad's `fleeing`): towards `home` along the route
## and out to the side, or towards its refuge. `motion` is [pace (cells a tick at speed 1),
## fight seed, terrain or null, where it stands, the squads].
static func step(
	squad: SkirmishSquad, unit: SkirmishUnit, entry: Dictionary, home: float, motion: Array
) -> void:
	var full: float = unit.speed * motion[0]
	var aside := sin(fan(unit, motion[1])) * full
	var fanned: float = entry.get("fanned", 0.0)
	var heading: Vector2 = (
		squad.route.heading_at(entry["along"]) if squad.route != null else Vector2.RIGHT
	)
	var side := heading.orthogonal()
	var at: Vector2 = motion[3]
	var refuge = _refuge(squad, at, entry["along"], home, motion[4])
	if refuge != null:  # it makes for the friend, as fast as it may turn aside
		var most := sin(deg_to_rad(FAN_DEGREES)) * full
		aside = clampf((refuge - at).dot(side), -most, most)
	var terrain = motion[2]
	var open: bool = terrain == null or terrain.factor(unit.height, at, at + side * aside) > 0.0
	if (refuge == null and absf(fanned + aside) > FAN_CELLS) or not open:
		aside = 0.0
	entry["fanned"] = fanned + aside
	entry["offset"] += side * aside
	entry["along"] = move_toward(entry["along"], home, sqrt(full * full - aside * aside))


## The unit of a standing friendly formation nearest `at`, among those between `along`
## and `home` on the route (cells), or null if there is none.
static func _refuge(squad: SkirmishSquad, at: Vector2, along: float, home: float, squads: Array):
	if squad.route == null:
		return null
	var best = null
	var best_gap := INF
	for friend in squads:
		if friend == squad or friend.faction_id != squad.faction_id or not RoutCatch.stands(friend):
			continue
		for unit in friend.living():
			var there := ScrumReach.at(friend, unit)
			var ahead := (squad.route.distance_of(there) - along) * (home - along) > 0.0
			if ahead and there.distance_to(at) < best_gap:
				best = there
				best_gap = there.distance_to(at)
	return best
