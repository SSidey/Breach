class_name FormationSkirmishReadout
extends RefCounted
## The formation feel test's HUD text (specs/22-formation-feel-test.md): pure formatting
## over the scene's state, kept out of FormationSkirmishScene so that stays glue.

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishSlotPool = preload("res://sim/skirmish/formation/skirmish_slot_pool.gd")
const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")


static func status(seconds: float, speed: float, paused: bool) -> String:
	return "%.1f s · ×%d%s" % [seconds, int(speed), " · PAUSED" if paused else ""]


static func pool(slot_pool: SkirmishSlotPool) -> String:
	return (
		"Slot pool %d: c %d · k %d · free %d (erase in one lane to paint in another)"
		% [
			slot_pool.total,
			slot_pool.assigned("c"),
			slot_pool.assigned("k"),
			slot_pool.free_slots()
		]
	)


## [summary text, build share 0..1, template places] for one lane.
static func lane(production: FormationProduction, allowance: int) -> Array:
	var places := production.preview()
	var used := 0
	for place in places:
		used += place[2] * place[3]
	var state := "ready - send it" if production.is_full() else "building"
	var text := (
		"cells %d/%d · built %d/%d · reserve %d · %s"
		% [used, allowance, production.built(), places.size(), production.reserve_count(), state]
	)
	var share := 1.0 if production.is_full() else production.progress
	return [text, share, places]


## chosen: [lane key, squad id], or empty when nothing is selected.
static func selected(chosen: Array, squad: SkirmishSquad) -> String:
	if chosen.is_empty():
		return "Click a squad (or Tab) to select it"
	if squad == null or squad.is_destroyed():
		return "Selected squad is gone"
	return (
		"Lane %s squad #%d: %d alive · %s · %s"
		% [
			chosen[0],
			squad.id,
			squad.living().size(),
			SkirmishUnit.Order.keys()[squad.order],
			SkirmishSquad.State.keys()[squad.state]
		]
	)
