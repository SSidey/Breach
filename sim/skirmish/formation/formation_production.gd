class_name FormationProduction
extends RefCounted
## One lane's wave build (Decisions 39 and 42, specs/22-formation-feel-test.md): it builds
## toward the lane's painted WaveTemplate, front-first. A new template takes effect at
## once - units already built fold into matching places (same unit type, front-first) and
## any left over are banked in the lane's reserve, which fills matching places instantly
## before anything new is built. "wave_full" is emitted once when every place is filled;
## the wave departs as one squad, manually (send()) or automatically. Never pauses itself.

enum Departure { MANUAL, AUTO_WHEN_FULL }

const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

var faction_id: String
var at_player_end: bool
var departure: Departure = Departure.MANUAL
## Seconds to build a 1x1 unit; larger footprints take twice as long.
var build_seconds: float = 2.0
## 0..1 through the unit currently being built.
var progress: float = 0.0

var _template := WaveTemplate.new(1, 0)
var _filled := []  # one bool per _template.ordered() place
var _reserve: Array[UnitDef] = []
var _ticks := 0
var _building: UnitDef
var _announced := false


func _init(faction: String, player_end: bool) -> void:
	faction_id = faction
	at_player_end = player_end


## Switches to a new template now: built units fold into matching places, the rest are
## banked. Returns a "folded" event describing it.
func set_template(template: WaveTemplate) -> Array:
	var built_defs := []
	var places := _template.ordered()
	for index in range(places.size()):
		if _filled[index]:
			built_defs.append(places[index][0])
	_template = template
	_filled = []
	var kept := 0
	for place in _template.ordered():
		var match_at := built_defs.find(place[0])
		_filled.append(match_at != -1)
		if match_at != -1:
			built_defs.remove_at(match_at)
			kept += 1
	for leftover in built_defs:
		_reserve.append(leftover)
	_announced = is_full() and _announced
	return [{"type": "folded", "faction": faction_id, "kept": kept, "banked": built_defs.size()}]


func step(sim: FormationSimulation) -> Array:
	var events := []
	var places := _template.ordered()
	for index in range(places.size()):
		var banked := _reserve.find(places[index][0])
		if not _filled[index] and banked != -1:
			_reserve.remove_at(banked)
			_filled[index] = true
			events.append(_event("from_reserve", sim, {"built": built()}))
	var next := _filled.find(false)
	if next != -1:
		_build_toward(places[next][0], next, sim, events)
	if is_full() and not _announced:
		_announced = true
		events.append(_event("wave_full", sim, {"built": built()}))
		if departure == Departure.AUTO_WHEN_FULL:
			send(sim)
			events.append(_event("departed", sim, {"units": events[-1]["built"]}))
	return events


## Deploys the filled places as one squad (the painted layout) and restarts the same
## template, empty; null when nothing is built.
func send(sim: FormationSimulation) -> SkirmishSquad:
	if built() == 0:
		return null
	var layout := _template.layout()
	var placements := []
	for index in range(_filled.size()):
		if _filled[index]:
			placements.append(layout[1][index])
	var squad := sim.spawn_squad(layout[0], placements, faction_id, at_player_end)
	_filled.fill(false)
	_ticks = 0
	progress = 0.0
	_announced = false
	return squad


func is_full() -> bool:
	return not _filled.is_empty() and not _filled.has(false)


func built() -> int:
	return _filled.count(true)


func reserve_count() -> int:
	return _reserve.size()


## [[rank, column, depth, width, filled], ...] for every template place (template grid).
func preview() -> Array:
	var places := _template.ordered()
	var out := []
	for index in range(places.size()):
		var unit_def: UnitDef = places[index][0]
		var at: Vector2i = places[index][1]
		out.append([at.x, at.y, unit_def.footprint_depth, unit_def.footprint_width, _filled[index]])
	return out


func _build_toward(unit_def: UnitDef, index: int, sim: FormationSimulation, events: Array) -> void:
	if _building != unit_def:
		_building = unit_def
		_ticks = 0
	_ticks += 1
	var area := unit_def.footprint_depth * unit_def.footprint_width
	var needed := maxi(1, roundi(build_seconds * (2.0 if area > 1 else 1.0) / sim.tick_seconds))
	progress = float(_ticks) / float(needed)
	if _ticks < needed:
		return
	_ticks = 0
	progress = 0.0
	_filled[index] = true
	events.append(_event("built", sim, {"built": built()}))


func _event(kind: String, sim: FormationSimulation, extra: Dictionary) -> Dictionary:
	var event := {"type": kind, "tick": sim.tick_number(), "faction": faction_id}
	event.merge(extra)
	return event
