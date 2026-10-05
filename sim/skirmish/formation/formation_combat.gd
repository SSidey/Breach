class_name FormationCombat
extends RefCounted
## How hard a blow lands, and ranged strikes, per specs/22-formation-feel-test.md and
## Decision 40. Pure: FormationSimulation calls it each tick.
##
## A flank blow (Decision 88: from outside the target's front) is worth FLANK_BONUS.
##
## Ranged units (Decisions 46-47) strike with their best ranged weapon from anywhere in
## their squad, moving or fighting: the nearest enemy unit within its range in ranks,
## preferring one they overlap laterally, then by the seeded draw (Decision 97), with no
## flank bonus. A ranged unit in the front
## rank of an engaged squad strikes with its melee weapons instead.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadGeometry = preload("res://sim/skirmish/formation/squad_geometry.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")

const FLANK_BONUS := 1.5
const EPSILON := 0.000001

## The flank bonus in use: FLANK_BONUS unless a tuning trial overrides it (BattleTrials).
static var flank_bonus := FLANK_BONUS


## This tick's ranged strikes: [[shooter, target, damage, shooter's squad], ...]. Updates
## each shooter's target and cooldown, like melee fighters.
static func ranged_blows(squads: Array, interval_ticks: int, fight_seed: int = 0) -> Array:
	var blows := []
	for own in squads:
		if own.is_destroyed() or own.state == SkirmishSquad.State.ARRIVED:
			continue
		var melee: Array = own.fighters() if own.state == SkirmishSquad.State.FIGHTING else []
		for shooter in own.living():
			if shooter.attack_range <= 0 or melee.has(shooter):
				continue
			var target := _in_range(own, shooter, squads, fight_seed)
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


## The nearest enemy unit within the shooter's range (ties: one it overlaps laterally,
## then the targets' draws).
static func _in_range(
	own: SkirmishSquad, shooter: SkirmishUnit, squads: Array, fight_seed: int
) -> SkirmishUnit:
	var reach := shooter.attack_range * SkirmishSquad.RANK_DEPTH + EPSILON
	var here := SquadGeometry.unit_gap(own, own, shooter)
	var axis := SquadFrame.lateral_axis(own.heading)
	var span := own.lateral_span(shooter)
	var best: SkirmishUnit = null
	var best_key := []
	for other in squads:
		if (
			other.faction_id == own.faction_id
			or other.is_destroyed()
			or other.state == SkirmishSquad.State.ARRIVED
		):
			continue
		for unit in other.living():
			var gap: float = absf(SquadGeometry.unit_gap(own, other, unit) - here)
			var target_span: Vector2 = other.lateral_span(unit, axis)
			var overlap := minf(span.y, target_span.y) - maxf(span.x, target_span.x)
			var key := [
				snappedf(gap, EPSILON),
				0 if overlap > EPSILON else 1,
				ScrumContest.draw(unit, fight_seed)
			]
			if gap <= reach and (best == null or key < best_key):
				best = unit
				best_key = key
	return best
