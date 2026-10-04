class_name FormationCombat
extends RefCounted
## Who a front-rank fighter strikes, per specs/22-formation-feel-test.md and Decision 40.
## Pure: FormationSimulation calls it each tick, so targets follow the lines as they change.
##
## A fighter strikes the enemy fighter it overlaps most laterally (a frontal attack). With
## no overlap - it stands past the end of a narrower enemy line - it wraps onto the nearest
## enemy end fighter instead, as a flank attack worth FLANK_BONUS.
##
## Ranged units (Decisions 46-47) strike with their best ranged weapon from anywhere in
## their squad, moving or fighting: the nearest enemy unit within its range in ranks,
## preferring one they overlap laterally, with no flank bonus. A ranged unit in the front
## rank of an engaged squad strikes with its melee weapons instead.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadGeometry = preload("res://sim/skirmish/formation/squad_geometry.gd")

const FLANK_BONUS := 1.5
const EPSILON := 0.000001

## The flank bonus in use: FLANK_BONUS unless a tuning trial overrides it (BattleTrials).
static var flank_bonus := FLANK_BONUS


## [target, is_flank], or [] when the enemy has no fighters.
static func pick_target(
	own: SkirmishSquad, fighter: SkirmishUnit, foe: SkirmishSquad, foe_fighters: Array
) -> Array:
	var span := own.lateral_span(fighter)
	var frontal: SkirmishUnit = null
	var best_overlap := EPSILON
	var nearest: SkirmishUnit = null
	var best_gap := INF
	for candidate in foe_fighters:
		var other := foe.lateral_span(candidate)
		var overlap := minf(span.y, other.y) - maxf(span.x, other.x)
		if overlap > best_overlap:
			frontal = candidate
			best_overlap = overlap
		var gap := maxf(other.x - span.y, span.x - other.y)
		if gap < best_gap:
			nearest = candidate
			best_gap = gap
	if frontal != null:
		return [frontal, false]
	return [] if nearest == null else [nearest, true]


## This tick's ranged strikes: [[shooter, target, damage, shooter's squad], ...]. Updates
## each shooter's target and cooldown, like melee fighters.
static func ranged_blows(squads: Array, interval_ticks: int) -> Array:
	var blows := []
	for own in squads:
		if own.is_destroyed() or own.state == SkirmishSquad.State.ARRIVED:
			continue
		if own.state == SkirmishSquad.State.TURNING:
			continue  # a turning squad doesn't strike (Decision 74)
		var melee: Array = own.fighters() if own.state == SkirmishSquad.State.FIGHTING else []
		for shooter in own.living():
			if shooter.attack_range <= 0 or melee.has(shooter):
				continue
			var target := _in_range(own, shooter, squads)
			if target == null:
				continue
			shooter.target_id = target.id
			shooter.attack_cooldown -= 1
			if shooter.attack_cooldown <= 0:
				shooter.attack_cooldown = interval_ticks
				blows.append([shooter, target, shooter.ranged_dmg, own])
	return blows


static func damage(fighter: SkirmishUnit, is_flank: bool) -> int:
	return roundi(fighter.dmg * (flank_bonus if is_flank else 1.0))


## The nearest enemy unit within the shooter's range (ties: one it overlaps laterally).
static func _in_range(own: SkirmishSquad, shooter: SkirmishUnit, squads: Array) -> SkirmishUnit:
	var reach := shooter.attack_range * SkirmishSquad.RANK_DEPTH + EPSILON
	var here := SquadGeometry.unit_gap(own, own, shooter)
	var span := own.lateral_span(shooter)
	var best: SkirmishUnit = null
	var best_key := Vector2(INF, INF)
	for other in squads:
		if (
			other.faction_id == own.faction_id
			or other.is_destroyed()
			or other.state == SkirmishSquad.State.ARRIVED
		):
			continue
		for unit in other.living():
			var gap: float = absf(SquadGeometry.unit_gap(own, other, unit) - here)
			var target_span: Vector2 = other.lateral_span(unit)
			var overlap := minf(span.y, target_span.y) - maxf(span.x, target_span.x)
			var key := Vector2(gap, 0.0 if overlap > EPSILON else 1.0)
			var nearer := key.x < best_key.x - EPSILON
			var level := absf(key.x - best_key.x) <= EPSILON and key.y < best_key.y
			if gap <= reach and (nearer or level):
				best = unit
				best_key = key
	return best
