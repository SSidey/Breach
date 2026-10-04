class_name FormationScrum
extends RefCounted
## Both sides seek contact (Decision 88, spec 27 round 5). While its squad fights, each
## unit leaves its place for the scrum:
## - **Seeking:** a unit touching no foe walks to the nearest open cell next to one, round
##   friends and the enemy (never through an enemy), anywhere within the route's leash of
##   its place (Decision 75) - the far end of a wide line comes too. Only front-band units
##   of a squad not yet wavering seek; the rest keep to their places. Contested cells go by
##   ScrumContest's key, so the earliest arrival takes a cell and the rest look further.
## - **No delay:** a squad's units seek as soon as its fight begins (Decision 92).
## - **Cohesion:** a disciplined squad whose front is free re-forms its line to meet an
##   enemy closing in at another face, before contact (ScrumStance); a less disciplined one
##   meets it unit by unit, leaving gaps.
## - **Engaging:** squads whose units come within reach fight, whatever their faces.
## - **Regrouping:** when the fight ends the squad closes ranks over its dead (SquadRanks)
##   and its units walk to their places at its re-form pace; it moves on once all are back.
## - **Manoeuvres:** settled each tick by priority (FormationManoeuvre, Decision 94).
## - **A stalled fight** (nobody touching or seeking for STALL_SECONDS) is released.
## Each phase decides from where units stood before it began, never letting a squad listed
## earlier move first and change what a later one sees (Decision 97).
## Squads keep `loose`, `stance`, `fight_since` and `stall_ticks`. Pure over the squads.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const ScrumBlows = preload("res://sim/skirmish/formation/scrum_blows.gd")
const ScrumPaths = preload("res://sim/skirmish/formation/scrum_paths.gd")
const ScrumEngage = preload("res://sim/skirmish/formation/scrum_engage.gd")
const ScrumRegroup = preload("res://sim/skirmish/formation/scrum_regroup.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const FormationManoeuvre = preload("res://sim/skirmish/formation/formation_manoeuvre.gd")
const SquadRanks = preload("res://sim/skirmish/formation/squad_ranks.gd")
const FormationWithdraw = preload("res://sim/skirmish/formation/formation_withdraw.gd")
const FormationPursuit = preload("res://sim/skirmish/formation/formation_pursuit.gd")
const ScrumSpacing = preload("res://sim/skirmish/formation/scrum_spacing.gd")
const ScrumPursuit = preload("res://sim/skirmish/formation/scrum_pursuit.gd")
const ScrumStance = preload("res://sim/skirmish/formation/scrum_stance.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")

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
	var events := ScrumEngage.step(squads, tick, fight_seed)
	for squad in squads:
		_prepare(squad, tick)
	for squad in squads:
		ScrumStance.anticipate(squad, squads, tick, events, terrain, fight_seed)
	FormationManoeuvre.step(squads)
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
	ScrumRegroup.step(squads, ctx["pace"], tick_seconds, fight_seed)
	ScrumPursuit.step(squads, tick, cells_per_second, tick_seconds, fight_seed)
	FormationWithdraw.step(squads, tick, ctx["pace"], tick_seconds, fight_seed, terrain, events)
	ScrumSpacing.step(squads, ctx["pace"], fight_seed)
	FormationPursuit.step(squads, tick, cells_per_second, tick_seconds, events)
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
		if squad.fight_since >= 0 and squad.painted.is_empty():
			SquadRanks.close(squad)  # the dead leave holes: the living close up
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
	var fighting: Array = ctx["squads"].filter(
		func(s): return s.state == SkirmishSquad.State.FIGHTING
	)
	for squad in fighting:  # in the crush, but at the march pace in a pursuit
		_walk(squad, ctx["pace"] * (CROWDING if squad.pursuit.is_empty() else 1.0))
	for squad in fighting:  # after everyone has moved, so a unit stepped up to is seen
		_face(squad, ctx)


## [[key, squad, unit, foe cells], ...] for the squad's units free to seek; the rest stand
## (touching a foe) or keep to their places.
static func _seekers_of(squad: SkirmishSquad, ctx: Dictionary) -> Array:
	var foes := _foe_units(squad, ctx["squads"])
	var foe_cells := {}
	for entry in foes:
		for spot in ScrumPaths.cells_of(ScrumReach.area(entry[1], entry[0])):
			foe_cells[spot] = true
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
		if not (steady and _may_seek(squad, unit)) or foe_cells.is_empty():
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


## Fighting units walk a step to their goal, or back towards their place if they have none
## and touch no one.
static func _walk(squad: SkirmishSquad, pace: float) -> void:
	for unit in squad.living():
		var entry: Dictionary = squad.loose[unit.id]
		var full: float = unit.speed * pace
		entry["toward"] = null
		if entry["goal"] != null:
			entry["toward"] = entry["next"]
			entry["at"] = UnitMotion.move(unit, entry["at"], entry["next"], full)
		elif not entry.get("touch", false):
			var place := ScrumStance.anchor(squad, unit)
			entry["toward"] = place
			entry["at"] = UnitMotion.move(unit, entry["at"], place, full)
			entry["next"] = entry["at"]


## Each unit turns once a tick, at its turn rate: towards the nearest foe it touches, or
## else the way it walked.
static func _face(squad: SkirmishSquad, ctx: Dictionary) -> void:
	var foes := _foe_units(squad, ctx["squads"])
	for unit in squad.living():
		var entry: Dictionary = squad.loose[unit.id]
		var look = ScrumBlows.nearest_touching(squad, unit, foes, ctx["seed"])
		if look == null:
			look = entry.get("toward")
		if look != null:
			var wanted := UnitMotion.bearing_to(entry["at"], look, unit.bearing)
			UnitMotion.turn(unit, wanted, ctx["seconds"])


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
