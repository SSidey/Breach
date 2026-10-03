class_name FormationStaging
extends RefCounted
## Hold-until orders (Decision 87, spec 27 round 2). A staged wave marches to its staging
## point and holds there until its trigger, judged only on what it detects:
## - SEES_PARTNER: it detects its partner squad
## - SEES_FIGHT: it detects its partner (or, with no partner named, any friendly squad)
##   fighting
## or until its fallback runs out, when it goes on ("go") or turns back ("back"). Without a
## leader it goes as soon as the trigger fires. Led by a **coordinated** leader (Decision
## 81), a wave waiting to see its partner times its own departure: from the partner's
## distance to the meeting point and its pace, as seen, against its own predicted march,
## it goes when it would arrive no earlier than the partner. A squad's `staging`: {"at":
## cells along its route, "trigger", "partner": squad id or 0, "fallback": ticks, "then":
## "go" or "back", optionally "meet": the meeting point and "meet_cells": how far along its
## own route that is}. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const FormationSight = preload("res://sim/skirmish/formation/formation_sight.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationRendezvous = preload("res://sim/skirmish/formation/formation_rendezvous.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const SEES_PARTNER := "sees_partner"
const SEES_FIGHT := "sees_fight"
## A coordinated leader leaves this many ticks early at most.
const SLACK_TICKS := 2


## True if the squad holds this tick: it is at its staging point and its trigger hasn't
## fired. Emits "staged" when it first holds, then "signalled" or "gave_up".
## `pace` = [cells a second at speed 1, seconds a tick].
static func holds(
	squad: SkirmishSquad, squads: Array, tick: int, events: Array, pace: Array = [8.0, 0.1]
) -> bool:
	if squad.staging.is_empty() or squad.order != SkirmishUnit.Order.ADVANCE:
		return false
	var partner := _triggered(squad, squads)
	if partner != null and _time_to_go(squad, partner, pace):
		squad.staging = {}
		events.append(FormationEvents.squad_event("signalled", tick, squad))
		return false
	var cells := squad.front_distance * MapLayoutDef.CELLS_PER_TILE
	if absf(cells - squad.home_distance * MapLayoutDef.CELLS_PER_TILE) < squad.staging["at"]:
		return false  # still on its way
	if squad.state != SkirmishSquad.State.HOLDING:
		squad.state = SkirmishSquad.State.HOLDING
		events.append(FormationEvents.squad_event("staged", tick, squad))
	squad.staging["fallback"] -= 1
	if squad.staging["fallback"] > 0:
		return true
	var then: String = squad.staging.get("then", "go")
	squad.staging = {}
	events.append(FormationEvents.squad_event("gave_up", tick, squad, {"then": then}))
	if then == "back":
		squad.order = SkirmishUnit.Order.RETREAT
	return false


## True unless a coordinated leader judges it too soon: it would arrive before its partner.
static func _time_to_go(squad: SkirmishSquad, partner: SkirmishSquad, pace: Array) -> bool:
	if not squad.staging.has("meet") or not _coordinated(squad) or partner.speed() <= 0.0:
		return true
	var tick_seconds: float = pace[1]
	var partner_ticks: float = (
		partner.position.distance_to(squad.staging["meet"])
		/ (partner.speed() * pace[0] * tick_seconds)
	)
	var own_ticks := FormationRendezvous.ticks_to(
		squad.route,
		squad.staging["meet_cells"],
		squad.width,
		squad.speed() * pace[0],
		tick_seconds,
		squad.front_distance * MapLayoutDef.CELLS_PER_TILE
	)
	return own_ticks >= partner_ticks - SLACK_TICKS


static func _coordinated(squad: SkirmishSquad) -> bool:
	return squad.living().any(func(u): return u.tactics.has("coordinated"))


## The friend whose sight fires the trigger, or null.
static func _triggered(squad: SkirmishSquad, squads: Array) -> SkirmishSquad:
	var partner: int = squad.staging.get("partner", 0)
	for other in squads:
		if other == squad or other.faction_id != squad.faction_id:
			continue
		if partner != 0 and other.id != partner:
			continue
		var wanted: bool = (
			squad.staging["trigger"] == SEES_PARTNER or other.state == SkirmishSquad.State.FIGHTING
		)
		if wanted and FormationSight.detects(squad, other):
			return other
	return null
