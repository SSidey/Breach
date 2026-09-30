class_name FormationProduction
extends RefCounted
## One lane's wave build in the formation feel test (specs/22-formation-feel-test.md,
## Decisions 39-40). When a wave starts building it snapshots the lane's slots and width
## into a SkirmishFormation, so a slot-pool change made meanwhile applies to the next
## wave. Units are built one at a time per the composition preset and placed front-first.
## "wave_full" is emitted once when the next unit won't fit; the wave then departs as one
## squad, manually (send()) or automatically. Never pauses anything itself.

## Grems only; one brute at the front centre then grems; brutes only.
enum Preset { LIGHT, HEAVY_FRONT, HEAVY }
enum Departure { MANUAL, AUTO_WHEN_FULL }

const SkirmishFormation = preload("res://sim/skirmish/formation/skirmish_formation.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

var faction_id: String
var at_player_end: bool
var light_def: UnitDef
var heavy_def: UnitDef
var preset: Preset = Preset.LIGHT
var departure: Departure = Departure.MANUAL
## The lane's maximum frontline width (Decision 41: never more than 8).
var lane_width: int = SkirmishFormation.MAX_LANE_WIDTH
## Seconds to build a 1x1 unit; larger footprints take twice as long.
var build_seconds: float = 2.0
## 0..1 through the unit currently being built.
var progress: float = 0.0

var _slots := 0  # the lane's current pool share (applies from the next wave)
var _width := 1
var _formation: SkirmishFormation  # the wave being built; null between waves
var _placements := []  # [[UnitDef, Vector2i(rank, column)], ...]
var _ticks := 0
var _announced := false


func _init(faction: String, player_end: bool, light: UnitDef, heavy: UnitDef) -> void:
	faction_id = faction
	at_player_end = player_end
	light_def = light
	heavy_def = heavy


## The lane's pool share and requested width - used when the next wave starts.
func configure(slot_count: int, requested_width: int) -> void:
	_slots = slot_count
	_width = requested_width


func step(sim: FormationSimulation) -> Array:
	var events := []
	if _formation == null:
		if _slots <= 0:
			return events
		var width := SkirmishFormation.clamp_width(_width, lane_width, _slots)
		_formation = SkirmishFormation.new(width, _slots)
	var next := _next_def()
	if next == null:
		return events
	_ticks += 1
	var needed := _build_ticks(next, sim)
	progress = float(_ticks) / float(needed)
	if _ticks < needed:
		return events
	_ticks = 0
	progress = 0.0
	var prefer_centre := preset == Preset.HEAVY_FRONT and next == heavy_def
	var at := _formation.place(next.footprint_depth, next.footprint_width, prefer_centre)
	_placements.append([next, at])
	events.append(_event("built", sim, {"built": _placements.size()}))
	if _next_def() == null and not _announced:
		_announced = true
		events.append(_event("wave_full", sim, {"built": _placements.size()}))
		if departure == Departure.AUTO_WHEN_FULL:
			send(sim)
			events.append(_event("departed", sim, {"units": events[-1]["built"]}))
	return events


## Sends whatever is built as one squad and ends the wave; null when nothing is built.
func send(sim: FormationSimulation) -> SkirmishSquad:
	if _placements.is_empty():
		return null
	var squad := sim.spawn_squad(_formation.width, _placements, faction_id, at_player_end)
	_formation = null
	_placements = []
	_ticks = 0
	progress = 0.0
	_announced = false
	return squad


func is_full() -> bool:
	return _formation != null and _next_def() == null


func built() -> int:
	return _placements.size()


## The wave's slot count (the formation it is building into, else the next wave's share).
func wave_slots() -> int:
	return _formation.slots if _formation != null else _slots


## [[rank, column, depth, width], ...] of the units built so far, for the HUD preview.
func preview() -> Array:
	return _placements.map(
		func(p): return [p[1].x, p[1].y, p[0].footprint_depth, p[0].footprint_width]
	)


func _next_def() -> UnitDef:
	if _formation == null:
		return null
	var has_heavy := _placements.any(func(p): return p[0] == heavy_def)
	var wants_heavy := preset == Preset.HEAVY or (preset == Preset.HEAVY_FRONT and not has_heavy)
	if wants_heavy and heavy_def != null and _fits(heavy_def):
		return heavy_def
	if preset == Preset.HEAVY and not _placements.is_empty():
		return null  # brutes only: stop when no more brutes fit
	return light_def if _fits(light_def) else null


func _fits(unit_def: UnitDef) -> bool:
	return _formation.can_fit(unit_def.footprint_depth, unit_def.footprint_width)


func _build_ticks(unit_def: UnitDef, sim: FormationSimulation) -> int:
	var area := unit_def.footprint_depth * unit_def.footprint_width
	var seconds := build_seconds * (2.0 if area > 1 else 1.0)
	return maxi(1, roundi(seconds / sim.tick_seconds))


func _event(kind: String, sim: FormationSimulation, extra: Dictionary) -> Dictionary:
	var event := {"type": kind, "tick": sim.tick_number(), "faction": faction_id}
	event.merge(extra)
	return event
