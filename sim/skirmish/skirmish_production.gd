class_name SkirmishProduction
extends RefCounted
## One lane's build order in the real-time skirmish feel test
## (specs/21-realtime-skirmish-feel-test.md, Decisions 38-39). It builds a unit every
## build_ticks until wave_size are ready, emits "wave_full" once, and stops building until
## the wave departs - manually (send()) or automatically on the tick it fills. It never
## pauses anything itself: whether a full wave pauses the game is the player's option,
## applied by the presentation layer reacting to "wave_full".

enum Departure { MANUAL, AUTO_WHEN_FULL }

const SkirmishSimulation = preload("res://sim/skirmish/skirmish_simulation.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

## Ticks between one departing unit and the next, so a wave reads as a group.
const DEPART_STAGGER_TICKS := 2

var unit_def: UnitDef
var faction_id: String
var at_player_end: bool
var wave_size: int = 3
var build_ticks: int = 8
var departure: Departure = Departure.MANUAL
var built: int = 0

var _progress := 0


func _init(def: UnitDef, faction: String, player_end: bool) -> void:
	unit_def = def
	faction_id = faction
	at_player_end = player_end


func is_full() -> bool:
	return built >= wave_size


## 0..1 progress on the unit currently being built (0 when the wave is full).
func progress() -> float:
	return 0.0 if is_full() else float(_progress) / float(build_ticks)


func step(sim: SkirmishSimulation) -> Array:
	var events := []
	if is_full():
		return events
	_progress += 1
	if _progress < build_ticks:
		return events
	_progress = 0
	built += 1
	events.append(_event("built", sim, {"built": built, "wave_size": wave_size}))
	if is_full():
		events.append(_event("wave_full", sim, {"wave_size": wave_size}))
		if departure == Departure.AUTO_WHEN_FULL:
			send(sim)
			events.append(_event("departed", sim, {"units": wave_size}))
	return events


## Sends whatever is ready (the full wave, or a partial one early) and restarts building.
func send(sim: SkirmishSimulation) -> Array[SkirmishUnit]:
	var sent: Array[SkirmishUnit] = []
	for i in range(built):
		sent.append(sim.spawn(unit_def, faction_id, at_player_end, i * DEPART_STAGGER_TICKS))
	built = 0
	_progress = 0
	return sent


func _event(kind: String, sim: SkirmishSimulation, extra: Dictionary) -> Dictionary:
	var event := {"type": kind, "tick": sim.tick_number(), "faction": faction_id}
	event.merge(extra)
	return event
