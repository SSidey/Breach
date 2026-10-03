class_name FormationContact
extends RefCounted
## Contact between squads on one lane (specs/22-formation-feel-test.md, Decisions 40 and
## 44). Covers:
## - who can fight, and which hostile front is within melee reach
## - where an advancing squad must stop: at reach of a hostile front, or behind the back
##   rank of a friendly squad ahead (squads never pass through their own side)
## - how a wave that reaches a friendly squad in combat joins it from the back, as rear
##   ranks that step up as the front falls; a wave that merges (Decision 51) joins a
##   friendly squad on the march the same way
## - when a squad without front units holds to skirmish (Decision 47)
## Pure over the squads it is given; FormationSimulation calls it each tick.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadGeometry = preload("res://sim/skirmish/formation/squad_geometry.gd")
const SquadEdges = preload("res://sim/skirmish/formation/squad_edges.gd")

## Tiles between engaged fronts: a little over one cell (Decision 68).
const MELEE_REACH := 0.0175
const EPSILON := 0.000001


static func can_engage(candidate: SkirmishSquad) -> bool:
	return (
		candidate.state != SkirmishSquad.State.DESTROYED
		and candidate.state != SkirmishSquad.State.ARRIVED
		and candidate.state != SkirmishSquad.State.ROUTING
		and candidate.order != SkirmishUnit.Order.RETREAT
		and candidate.wait_ticks == 0
	)


static func nearest_hostile(from: SkirmishSquad, squads: Array) -> SkirmishSquad:
	var best: SkirmishSquad = null
	var best_gap := INF
	for other in squads:
		if other.faction_id == from.faction_id or not can_engage(other):
			continue
		if not SquadGeometry.facing_off(from, other) or not SquadGeometry.overlaps(from, other):
			continue
		var gap := absf(SquadGeometry.gap(from, other))
		if gap <= MELEE_REACH + EPSILON and gap < best_gap:
			best = other
			best_gap = gap
	return best


## The furthest an advancing squad may get this tick, wanting to reach `next`.
static func limit(mover: SkirmishSquad, squads: Array, next: float) -> float:
	for other in squads:
		if other == mover or not can_engage(other):
			continue
		var room := _room(mover, other)
		if room == INF:
			continue
		var reachable := mover.front_distance + mover.direction * maxf(room, 0.0)
		next = minf(next, reachable) if mover.direction > 0 else maxf(next, reachable)
	return next


## True if an advancing squad with no front-preferring units has an enemy within its
## ranged reach: it holds there, skirmishing, rather than marching into melee (Decision 47).
static func skirmishing(mover: SkirmishSquad, squads: Array) -> bool:
	var living := mover.living()
	if (
		mover.order != SkirmishUnit.Order.ADVANCE
		or living.any(func(u): return u.preferred_position == 0)
	):
		return false
	var reach: int = living.reduce(func(most, u): return maxi(most, u.attack_range), 0)
	if reach == 0:
		return false
	for other in squads:
		if (
			other.faction_id != mover.faction_id
			and can_engage(other)
			and not other.is_destroyed()
			and SquadGeometry.overlaps(mover, other)
		):
			var gap := absf(SquadGeometry.gap(mover, other))
			if gap <= reach * SkirmishSquad.RANK_DEPTH + EPSILON:
				return true
	return false


## The friendly squad whose back rank `mover` has reached and may join, or null: one in
## combat, or - when `mover` merges - one on the march that isn't retreating.
static func joinable(mover: SkirmishSquad, squads: Array) -> SkirmishSquad:
	for other in squads:
		if (
			other == mover
			or other.faction_id != mover.faction_id
			or not _accepts(mover, other)
			or not _ahead(mover, other)
		):
			continue
		if SquadGeometry.gap(mover, other) - _depth(other) <= EPSILON:
			return other
	return null


## Moves the joining squad's living units in behind the leader's back rank, both lines
## centred on the wider of the two, and steps them up. They are the leader's joined units,
## free to spread in a fight (Decision 51). Returns the units that moved up.
static func reinforce(leader: SkirmishSquad, joining: SkirmishSquad) -> Array[SkirmishUnit]:
	var width := maxi(leader.width, joining.width)
	var back := _back_rows(leader)
	var shift := (width - leader.width) / 2
	for unit in leader.units:
		unit.column += shift
	for unit in joining.living():
		unit.column += (width - joining.width) / 2
		unit.rank += back
		unit.squad_id = leader.id
		unit.attack_cooldown = 1
		leader.units.append(unit)
		leader.joined.append(unit)
	leader.centre_shift += (width - leader.width) / 2.0 - shift  # the leader stays put
	leader.width = width
	joining.units.clear()
	return leader.compact()


## How far the mover may come toward `other` (tiles): to melee reach of a hostile's front
## or of its side or rear face (Decision 78), or to just behind a friend; INF if `other`
## isn't ahead across the mover's line.
static func _room(mover: SkirmishSquad, other: SkirmishSquad) -> float:
	if other.faction_id != mover.faction_id and not SquadGeometry.facing_off(mover, other):
		var face := SquadEdges.face_gap(mover, other)
		if face > EPSILON and SquadEdges.overlap_across(mover, other):
			return face - MELEE_REACH
		return INF
	if not _ahead(mover, other):
		return INF
	if other.faction_id != mover.faction_id:
		return SquadGeometry.gap(mover, other) - MELEE_REACH
	return SquadGeometry.gap(mover, other) - _depth(other)


static func _accepts(mover: SkirmishSquad, leader: SkirmishSquad) -> bool:
	if leader.state == SkirmishSquad.State.FIGHTING:
		return true
	return (
		mover.merges
		and leader.state in [SkirmishSquad.State.MOVING, SkirmishSquad.State.HOLDING]
		and leader.order != SkirmishUnit.Order.RETREAT
	)


static func _ahead(mover: SkirmishSquad, other: SkirmishSquad) -> bool:
	return SquadGeometry.gap(mover, other) > EPSILON and SquadGeometry.overlaps(mover, other)


## How deep a squad is in tiles: a squad behind it stops that far behind its front.
static func _depth(friend: SkirmishSquad) -> float:
	return _back_rows(friend) * SkirmishSquad.RANK_DEPTH


static func _back_rows(squad: SkirmishSquad) -> int:
	var rows := 0
	for unit in squad.living():
		rows = maxi(rows, unit.rank + unit.footprint_depth)
	return rows
