class_name ScrumTurn
extends RefCounted
## Turning as a re-form (Decision 92, spec 27 round 6): with contact-seeking, a squad that
## must face another way takes its new facing at once - an about-face reversing its ranks,
## a wheel pivoting on its front centre - and its units walk from where they stand to
## their new places at its re-form pace (FormationDiscipline). It moves on once they are
## all in place, so a disciplined squad turns quickly and a ragged one slowly. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadTurn = preload("res://sim/skirmish/formation/squad_turn.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")


## Turns the squad if it must face another way before moving `travel_sign` along its
## route. True if it turned; its units then re-form before it moves.
static func begin(squad: SkirmishSquad, travel_sign: int, tick: int, events: Array) -> bool:
	var wanted := squad.facing
	if travel_sign != squad.direction:
		var depth := SquadTurn.reverse_ranks(squad)
		squad.front_distance -= squad.direction * depth * SkirmishSquad.RANK_DEPTH
		squad.direction = -squad.direction
		wanted = SquadFrame.opposite(squad.facing)
	elif squad.route != null:
		var cells := squad.front_distance * MapLayoutDef.CELLS_PER_TILE
		wanted = squad.route.facing_at(cells, squad.direction, squad.facing)
	if wanted == squad.facing and travel_sign == squad.direction:
		return false
	for unit in squad.living():
		if not squad.loose.has(unit.id):
			squad.loose[unit.id] = {"unit": unit, "at": unit.position, "goal": null}
			squad.loose[unit.id]["next"] = unit.position
	squad.facing = wanted
	events.append(FormationEvents.squad_event("turning", tick, squad, {"facing": wanted}))
	events.append(FormationEvents.squad_event("turned", tick, squad, {"facing": wanted}))
	return true
