class_name ScrumEngage
extends RefCounted
## Fights start where units meet (Decision 88, spec 27 round 6): with contact-seeking, two hostile
## squads whose units come within reach of each other (reach_engage, BattleTuning) lock into a
## fight, whatever their faces - a squad passing beside a line, or a line it brushes, fights rather
## than walking by. A squad already fighting is joined by the one that reached it, and keeps its own
## foe. Any standing squad may be engaged, one retreating or routing too; only one not getting away
## seeks combat (Decision 111). Every free squad picks the nearest hostile it has come within reach
## of, all from one snapshot before any lock lands, a tie going to the squads' seeded draws - never
## to the order they are listed in (Decision 97). Pure over the squads it is given.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const ScrumNear = preload("res://sim/skirmish/formation/scrum_near.gd")

## Cells added to how far apart two squads' boxes may be and still have units within
## reach: far above float rounding, so no pair is missed.
const MARGIN := 0.01


## Locks free squads onto hostile squads their units have come within reach of. Returns
## "engaged" events.
static func step(squads: Array, tick: int, fight_seed: int = 0) -> Array:
	var picks := {}  # squad -> the foe it locks onto, every one chosen before any lands
	var near := {}  # squad -> its units, found by where they stand (ScrumNear), made as needed
	var spans := {}  # squad -> _span's, made as needed
	for squad in squads:
		if _free(squad):
			var foe := _nearest(squad, squads, fight_seed, [near, spans])
			if foe != null:
				picks[squad] = foe
	var events := []
	for squad in picks:
		FormationLocks.lock(squad, picks[squad])
		events.append(
			FormationEvents.squad_event("engaged", tick, squad, {"with": picks[squad].id})
		)
	return events


static func _free(squad: SkirmishSquad) -> bool:
	return (
		FormationContact.can_engage(squad)
		and squad.engaged_with == 0
		and squad.flank_contacts.is_empty()
		and squad.state != SkirmishSquad.State.FIGHTING
	)


## The hostile squad nearest `squad` within reach_engage (between their nearest units' cells),
## ties by the squads' draws; null if none is. A squad whose units' box is too far from
## `squad`'s for any two to be in reach is passed over unlooked-at. `found` = [ScrumNear's
## index of each squad's units, each squad's _span], filled as needed.
static func _nearest(
	squad: SkirmishSquad, squads: Array, fight_seed: int, found: Array
) -> SkirmishSquad:
	var near: Dictionary = found[0]
	var mine := _span(squad, found[1])
	var reach := BattleTuning.current().reach_engage + 0.000001
	var best: SkirmishSquad = null
	var best_key := []
	for other in squads:
		if other.faction_id == squad.faction_id or other.state == SkirmishSquad.State.DESTROYED:
			continue
		var theirs := _span(other, found[1])
		if (
			theirs[2].is_empty()
			or _apart(mine[0], theirs[0]) > reach + mine[1] + theirs[1] + MARGIN
		):
			continue  # not engageable (FormationContact), or out of reach
		if not near.has(other):
			near[other] = ScrumNear.index(theirs[2].map(func(foe): return [foe, other]))
		var gap := _gap(squad, other, near[other])
		var key := [snappedf(gap, 0.000001), ScrumContest.squad_draw(other, fight_seed)]
		if (
			gap <= BattleTuning.current().reach_engage + 0.000001
			and (best == null or key < best_key)
		):
			best = other
			best_key = key
	return best


## [the box round where the squad's living units stand (ScrumReach.at), its widest body's
## radius, its living units].
static func _span(squad: SkirmishSquad, spans: Dictionary) -> Array:
	if not spans.has(squad):
		var living := squad.living()
		var box := Rect2()
		var widest := 0.0
		for index in range(living.size()):
			var at := ScrumReach.at(squad, living[index])
			box = Rect2(at, Vector2.ZERO) if index == 0 else box.expand(at)
			widest = maxf(widest, ScrumReach.radius(living[index]))
		spans[squad] = [box, widest, living]
	return spans[squad]


## How far apart two boxes are (0 where they meet).
static func _apart(one: Rect2, other: Rect2) -> float:
	var across := maxf(maxf(other.position.x - one.end.x, one.position.x - other.end.x), 0.0)
	var down := maxf(maxf(other.position.y - one.end.y, one.position.y - other.end.y), 0.0)
	return Vector2(across, down).length()


## Cells between the two squads' nearest units' bodies (0 where they touch or overlap),
## if within reach_engage; past it, some gap past it, or INF. `theirs`: ScrumNear's index
## of the other's units.
static func _gap(squad: SkirmishSquad, other: SkirmishSquad, theirs: Dictionary) -> float:
	var reach := BattleTuning.current().reach_engage + 0.000001
	var least := INF
	for unit in squad.living():
		var at := ScrumReach.at(squad, unit)
		for entry in ScrumNear.around(theirs, at, ScrumReach.radius(unit) + reach):
			least = minf(least, ScrumReach.gap(squad, unit, other, entry[0]))
	return least
