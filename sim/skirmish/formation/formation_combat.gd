class_name FormationCombat
extends RefCounted
## Who a front-rank fighter strikes, per specs/22-formation-feel-test.md and Decision 40.
## Pure: FormationSimulation calls it each tick, so targets follow the lines as they change.
##
## A fighter strikes the enemy fighter it overlaps most laterally (a frontal attack). With
## no overlap - it stands past the end of a narrower enemy line - it wraps onto the nearest
## enemy end fighter instead, as a flank attack worth FLANK_BONUS.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

const FLANK_BONUS := 1.5
const EPSILON := 0.000001


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


static func damage(fighter: SkirmishUnit, is_flank: bool) -> int:
	return roundi(fighter.dmg * (FLANK_BONUS if is_flank else 1.0))
