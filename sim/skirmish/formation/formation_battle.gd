class_name FormationBattle
extends RefCounted
## The formation feel test's battle (specs/22-formation-feel-test.md, Decisions 40-45):
## its lanes (a FormationLane each), the player's and the kingdom's DomainProduction, and
## the shared SkirmishSlotPool, so the scene is only glue. The pool records what each lane
## has painted - a lane may paint into its own cells plus any free slot - and every
## reshape banks the displaced units in the player's domain reserve. Pure.

const FormationLane = preload("res://sim/skirmish/formation/formation_lane.gd")
const DomainProduction = preload("res://sim/skirmish/formation/domain_production.gd")
const SkirmishSlotPool = preload("res://sim/skirmish/formation/skirmish_slot_pool.gd")
const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

## Militia builders the kingdom starts with (two lines of three every 15 s, in turn).
const KINGDOM_BUILDERS := 2

var tick_seconds: float
var pool: SkirmishSlotPool
var player := DomainProduction.new("player")
var kingdom := DomainProduction.new("the_kingdom")

var _lanes := {}  # lane key -> FormationLane
var _widths := {}
var _kingdom_unit: UnitDef
var _kingdom_line: int
var _tick := 0


## lane_widths: {lane key: the lane's maximum frontline width}.
func _init(
	pool_total: int,
	lane_widths: Dictionary,
	seconds_per_tick: float,
	kingdom_unit: UnitDef,
	line: int
) -> void:
	tick_seconds = seconds_per_tick
	_widths = lane_widths.duplicate()
	var caps := {}
	for key in _widths:
		caps[key] = _widths[key] * WaveTemplate.MAX_RANKS
	pool = SkirmishSlotPool.new(pool_total, caps)
	_kingdom_unit = kingdom_unit
	_kingdom_line = line
	kingdom.set_builders(kingdom_unit, KINGDOM_BUILDERS)
	kingdom.distribution = DomainProduction.Distribution.ROUND_ROBIN
	kingdom.reserve_cap = 0


## Adds one of the lanes named in lane_widths, starting with `start` painted (its cells
## come from the pool).
func add_lane(key: String, route_length: float, start: WaveTemplate) -> void:
	var lane := FormationLane.new(
		key, _widths[key], route_length, tick_seconds, _kingdom_unit, _kingdom_line
	)
	_lanes[key] = lane
	lane.apply(start)
	pool.assign(key, lane.cells_used())


func lane_keys() -> Array:
	return _lanes.keys()


func lane(key: String) -> FormationLane:
	return _lanes[key]


## One tick of everything: {lane key: events}, plus the domains' own events under "".
func step(with_kingdom: bool) -> Dictionary:
	var waves := {}
	var militia := {}
	for key in _lanes:
		waves[key] = _lanes[key].production
		militia[key] = _lanes[key].kingdom
	var events := {"": player.step(waves, tick_seconds, _tick)}
	if with_kingdom:
		events[""].append_array(kingdom.step(militia, tick_seconds, _tick))
	for key in _lanes:
		events[key] = _lanes[key].step(with_kingdom)
	_tick += 1
	return events


## The cells a lane may paint: its own plus whatever the pool has free.
func allowance(key: String) -> int:
	return pool.assigned(key) + pool.free_slots()


## Paints (or erases) one cell of a lane's wave with its brush; returns the units banked.
func paint(key: String, cell: Vector2i, erase: bool = false) -> int:
	return _reshaped(key, _lanes[key].paint(cell, allowance(key), erase))


## Applies a whole template to a lane (a preset, already fitted); returns the units banked.
func apply(key: String, template: WaveTemplate) -> int:
	return _reshaped(key, _lanes[key].apply(template))


func _reshaped(key: String, leftovers: Array) -> int:
	pool.assign(key, _lanes[key].cells_used())
	player.bank(leftovers)
	return leftovers.size()
