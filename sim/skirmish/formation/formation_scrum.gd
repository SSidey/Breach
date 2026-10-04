class_name FormationScrum
extends RefCounted
## Both sides seek contact (Decision 88, spec 27 round 5). While its squad fights, each
## unit leaves its place for the scrum:
## - **Seeking:** a unit touching no foe walks to the nearest open cell next to one, round
##   friends and the enemy (never through an enemy), anywhere within the route's leash of
##   its place (Decision 75) - the far end of a wide line comes too. Only front-band units
##   of a squad not yet wavering seek; the rest keep to their places. Contested cells go by
##   ScrumContest's key, so the earliest arrival takes a cell and the rest look further.
## - **Reaction:** a squad's units start seeking REACTION_SECONDS after its fight begins,
##   divided by one plus its leadership.
## - **Cohesion:** a led squad whose front is free and that sees an enemy coming at
##   another face turns its line to meet it before contact - its places re-laid facing the
##   threat at that face (its stance) - from further off the better it is led. A leaderless
##   squad meets it unit by unit, leaving gaps.
## - **Regrouping:** when the fight ends its units walk back to their places at the march
##   pace, and the squad moves on once all are back.
## - **A stalled fight** (no unit on either side touching or seeking for STALL_SECONDS) is
##   released, so it can't freeze.
## Squads keep `loose`, `stance`, `fight_since` and `stall_ticks`. Pure over the squads.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const ScrumBlows = preload("res://sim/skirmish/formation/scrum_blows.gd")
const ScrumPaths = preload("res://sim/skirmish/formation/scrum_paths.gd")
const ScrumStance = preload("res://sim/skirmish/formation/scrum_stance.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

const REACTION_SECONDS := 1.5
const STALL_SECONDS := 2.0
## Walking within a fight is slowed by the crush (Decision 48; FormationShuffle.CROWDING).
const CROWDING := 0.2


## One tick of the scrum. `cells_per_second` is the march pace at speed 1. Returns
## "faced" and "disengaged" events.
static func step(
	squads: Array,
	tick: int,
	cells_per_second: float,
	tick_seconds: float,
	fight_seed: int,
	terrain: FormationTerrain = null
) -> Array:
	var events := []
	for squad in squads:
		_prepare(squad, tick)
	for squad in squads:
		ScrumStance.anticipate(squad, squads, tick, events, terrain)
	var ctx := {
		"squads": squads,
		"tick": tick,
		"seconds": tick_seconds,
		"pace": cells_per_second * tick_seconds,
		"seed": fight_seed,
		"terrain": terrain,
		"cells": ScrumPaths.occupancy(squads),
		"active": {},
	}
	_seek(ctx)
	_regroup(squads, ctx["pace"])
	_stall(squads, ctx["active"], tick, tick_seconds, events)
	return events


## True while the squad's units are out of their places: it doesn't march.
static func regrouping(squad: SkirmishSquad) -> bool:
	return not squad.loose.is_empty()


static func _prepare(squad: SkirmishSquad, tick: int) -> void:
	if squad.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
		squad.loose.clear()
		squad.stance = {}
		squad.fight_since = -1
		return
	for unit_id in squad.loose.keys():
		if not squad.loose[unit_id]["unit"].is_alive():
			squad.loose.erase(unit_id)
	var fighting := squad.state == SkirmishSquad.State.FIGHTING
	if fighting and squad.fight_since < 0:
		squad.fight_since = tick
		squad.stall_ticks = 0
	elif not fighting:
		squad.fight_since = -1
	if not fighting and squad.stance.is_empty():
		return
	for unit in squad.living():
		if not squad.loose.has(unit.id):
			squad.loose[unit.id] = {"unit": unit, "at": unit.position, "goal": null}
			squad.loose[unit.id]["next"] = unit.position


## Plans and walks every fighting squad's units, seekers in contest order.
static func _seek(ctx: Dictionary) -> void:
	var seekers := []
	for squad in ctx["squads"]:
		if squad.state == SkirmishSquad.State.FIGHTING:
			seekers.append_array(_seekers_of(squad, ctx))
	seekers.sort_custom(func(a, b): return ScrumContest.before(a[0], b[0]))
	var claimed := {}
	for seeker in seekers:
		var entry: Dictionary = seeker[1].loose[seeker[2].id]
		if entry["goal"] != null and entry["at"] != entry["next"]:
			claimed[entry["goal"]] = true  # mid-step: it keeps its claim
	for seeker in seekers:
		var squad: SkirmishSquad = seeker[1]
		var unit: SkirmishUnit = seeker[2]
		var entry: Dictionary = squad.loose[unit.id]
		if entry["goal"] == null or entry["at"] == entry["next"]:
			var plan := ScrumPaths.path(
				ScrumReach.cell(entry["at"]),
				ScrumReach.cell(ScrumStance.anchor(squad, unit)),
				unit,
				seeker[3],
				claimed,
				ctx["cells"],
				ctx["terrain"]
			)
			entry["goal"] = null if plan.is_empty() else plan[0]
			entry["next"] = entry["at"] if plan.is_empty() else ScrumReach.centre(plan[1])
		if entry["goal"] != null:
			claimed[entry["goal"]] = true
			ctx["active"][squad.id] = true
	for squad in ctx["squads"]:
		if squad.state == SkirmishSquad.State.FIGHTING:
			_walk(squad, ctx["pace"] * CROWDING)


## [[key, squad, unit, foe cells], ...] for the squad's units free to seek; the rest stand
## (touching a foe) or keep to their places.
static func _seekers_of(squad: SkirmishSquad, ctx: Dictionary) -> Array:
	var foes := _foe_units(squad, ctx["squads"])
	var foe_cells := {}
	for entry in foes:
		for spot in ScrumPaths.cells_of(ScrumReach.area(entry[1], entry[0])):
			foe_cells[spot] = true
	var waited: bool = ctx["tick"] - squad.fight_since >= _reaction_ticks(squad, ctx["seconds"])
	if not waited:
		ctx["active"][squad.id] = true
	var steady := FormationMorale.band(squad) < FormationMorale.Band.WAVERING
	var out := []
	for unit in squad.living():
		var entry: Dictionary = squad.loose[unit.id]
		entry["touch"] = ScrumBlows.touches_any(squad, unit, foes)
		if entry["touch"]:
			entry["goal"] = null
			entry["next"] = entry["at"]
			ctx["active"][squad.id] = true
			continue
		if not (waited and steady and _may_seek(squad, unit)) or foe_cells.is_empty():
			entry["goal"] = null
			continue
		var arrival := (
			ScrumPaths.nearest(ScrumReach.cell(entry["at"]), foe_cells) / maxf(unit.speed, 0.01)
		)
		var key := ScrumContest.key(unit, arrival, ctx["seed"], ctx["tick"])
		out.append([key, squad, unit, foe_cells])
	return out


## Front-band units seek; the rest too once no front-band unit is left.
static func _may_seek(squad: SkirmishSquad, unit: SkirmishUnit) -> bool:
	var front_left := squad.living().any(func(u): return u.preferred_position == 0)
	return (
		(unit.preferred_position == 0 or not front_left)
		and unit.footprint_width == 1
		and unit.footprint_depth == 1
		and squad.order != SkirmishUnit.Order.RETREAT
	)


static func _reaction_ticks(squad: SkirmishSquad, tick_seconds: float) -> int:
	var seconds := REACTION_SECONDS / (1.0 + FormationMorale.leadership(squad))
	return roundi(seconds / tick_seconds)


## Fighting units walk a step to their goal, or back towards their place if they have none
## and touch no one.
static func _walk(squad: SkirmishSquad, pace: float) -> void:
	for unit in squad.living():
		var entry: Dictionary = squad.loose[unit.id]
		if entry["goal"] != null:
			entry["at"] = entry["at"].move_toward(entry["next"], unit.speed * pace)
		elif not entry.get("touch", false):
			entry["at"] = entry["at"].move_toward(
				ScrumStance.anchor(squad, unit), unit.speed * pace
			)
			entry["next"] = entry["at"]


## Units of squads out of the fight walk to their places (in the stance, if any) at the
## march pace; back in place they rejoin the squad's frame unless it holds a stance.
static func _regroup(squads: Array, pace: float) -> void:
	for squad in squads:
		if squad.state in [SkirmishSquad.State.FIGHTING, SkirmishSquad.State.ROUTING]:
			continue
		for unit_id in squad.loose.keys():
			var entry: Dictionary = squad.loose[unit_id]
			var unit: SkirmishUnit = entry["unit"]
			var place := ScrumStance.anchor(squad, unit)
			entry["at"] = entry["at"].move_toward(place, unit.speed * pace)
			entry["next"] = entry["at"]
			entry["goal"] = null
			unit.facing = squad.facing if squad.stance.is_empty() else squad.stance["facing"]
			if squad.stance.is_empty() and entry["at"].distance_to(place) < 0.000001:
				squad.loose.erase(unit_id)


## Releases fights where nobody on either side has touched or sought a foe for a while.
static func _stall(
	squads: Array, active: Dictionary, tick: int, tick_seconds: float, events: Array
) -> void:
	var stalled := []
	for squad in squads:
		if squad.state != SkirmishSquad.State.FIGHTING:
			continue
		var quiet := not active.has(squad.id)
		for foe_id in _foe_ids(squad, squads):
			quiet = quiet and not active.has(foe_id)
		squad.stall_ticks = squad.stall_ticks + 1 if quiet else 0
		if squad.stall_ticks >= roundi(STALL_SECONDS / tick_seconds):
			stalled.append(squad)
	for squad in stalled:
		squad.stall_ticks = 0
		FormationLocks.release(squad, squads)
		events.append(FormationEvents.squad_event("disengaged", tick, squad))


## Ids of the squads it fights: on its front, its edges, or that fight it.
static func _foe_ids(squad: SkirmishSquad, squads: Array) -> Array:
	var out := []
	for other in squads:
		if other.faction_id == squad.faction_id:
			continue
		var theirs: bool = other.flank_contacts.values().any(func(c): return c["foe"] == squad.id)
		var mine: bool = squad.flank_contacts.values().any(func(c): return c["foe"] == other.id)
		if other.id == squad.engaged_with or other.engaged_with == squad.id or theirs or mine:
			out.append(other.id)
	return out


## [[unit, squad], ...] for the living units of the squads it fights.
static func _foe_units(squad: SkirmishSquad, squads: Array) -> Array:
	var ids := _foe_ids(squad, squads)
	var out := []
	for other in squads:
		if ids.has(other.id) and other.state != SkirmishSquad.State.ROUTING:
			for unit in other.living():
				out.append([unit, other])
	return out
