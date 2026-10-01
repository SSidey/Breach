class_name DomainProduction
extends RefCounted
## A faction's unit production (Decision 45, specs/22-formation-feel-test.md): builders
## in the domain, a count per unit type, each building one unit at a time at the unit's
## build_seconds. Covers:
## - **claiming:** a build claims a lane (by lane and type, never a particular place)
##   when it starts, chosen by the distribution rule. With no lane wanting the type, it
##   builds for the reserve while there is room under the cap.
## - **delivering:** a finished unit fills its lane's front-most matching place; failing
##   that, the next lane by the rule; failing that, the reserve, even over the cap.
## - **the reserve:** every tick it first fills matching places in any lane, by the rule.
## Pure: the lanes' waves are FormationProduction, passed in each step.

enum Distribution { PRIORITY, ROUND_ROBIN }

const FormationProduction = preload("res://sim/skirmish/formation/formation_production.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

## A build bound for the reserve rather than a lane.
const RESERVE := ""

var faction_id: String
var distribution: Distribution = Distribution.PRIORITY
## Lane keys in the player's order: first served first under PRIORITY, the turn order
## under ROUND_ROBIN. Lanes it doesn't name follow in their own order.
var lane_order: Array = []
var reserve: Array[UnitDef] = []
var reserve_cap := 6

var _builders := {}  # UnitDef -> [{"ticks", "progress", "lane": null idle | RESERVE | key}]
var _turn := 0


func _init(faction: String) -> void:
	faction_id = faction


## Adds idle builders, or removes builders keeping those furthest along.
func set_builders(unit_def: UnitDef, count: int) -> void:
	var list: Array = _builders.get(unit_def, [])
	while list.size() < count:
		list.append({"ticks": 0, "progress": 0.0, "lane": null})
	if list.size() > count:
		list.sort_custom(func(a, b): return a["ticks"] > b["ticks"])
		list.resize(maxi(count, 0))
	_builders[unit_def] = list


func builder_count(unit_def: UnitDef) -> int:
	return _builders.get(unit_def, []).size()


## Builds under way: [[UnitDef, lane key or RESERVE, progress 0..1], ...].
func builds() -> Array:
	var out := []
	for unit_def in _builders:
		for builder in _builders[unit_def]:
			if builder["lane"] != null:
				out.append([unit_def, builder["lane"], builder["progress"]])
	return out


## The player's sharing rule: a lane key puts that lane first (PRIORITY, the rest in
## their own order); an empty key shares in turn (ROUND_ROBIN).
func prefer(lane_key: String) -> void:
	distribution = Distribution.ROUND_ROBIN if lane_key.is_empty() else Distribution.PRIORITY
	lane_order = [] if lane_key.is_empty() else [lane_key]


## Puts units in the reserve (from a reshape); the cap doesn't apply.
func bank(units: Array) -> void:
	for unit_def in units:
		reserve.append(unit_def)


## One tick: the reserve fills what it can, then every builder works.
## lanes: {lane key: FormationProduction}.
func step(lanes: Dictionary, tick_seconds: float, tick: int) -> Array:
	var events := []
	var index := 0
	while index < reserve.size():
		var lane = _pick(reserve[index], lanes, false)
		if lane == null:
			index += 1
			continue
		lanes[lane].fill(reserve[index])
		reserve.remove_at(index)
		events.append(_event("from_reserve", tick, lane))
	for unit_def in _builders:
		for builder in _builders[unit_def]:
			_advance(unit_def, builder, lanes, tick_seconds, tick, events)
	return events


func _advance(
	unit_def: UnitDef, builder: Dictionary, lanes: Dictionary, seconds: float, tick: int, out: Array
) -> void:
	if builder["lane"] == null:
		builder["lane"] = _claim(unit_def, lanes)
		if builder["lane"] == null:
			return
	builder["ticks"] += 1
	var needed := maxi(1, roundi(unit_def.build_seconds / seconds))
	builder["progress"] = float(builder["ticks"]) / float(needed)
	if builder["ticks"] < needed:
		return
	var claimed: String = builder["lane"]
	builder.merge({"ticks": 0, "progress": 0.0, "lane": null}, true)
	if claimed != RESERVE and lanes.has(claimed) and lanes[claimed].fill(unit_def):
		out.append(_event("built", tick, claimed))
		return
	var other = _pick(unit_def, lanes, false)
	if other != null:
		lanes[other].fill(unit_def)
		out.append(_event("built", tick, other))
	else:
		reserve.append(unit_def)
		out.append(_event("to_reserve", tick, RESERVE))


## The lane a new build should serve, or RESERVE if there is room, or null (idle).
func _claim(unit_def: UnitDef, lanes: Dictionary) -> Variant:
	var lane = _pick(unit_def, lanes, true)
	if lane != null:
		return lane
	if reserve.size() + _claims(RESERVE) < reserve_cap:
		return RESERVE
	return null


## The first lane, by the distribution rule, with an unfilled place of this type (not
## already claimed by a build, if respect_claims); null if none.
func _pick(unit_def: UnitDef, lanes: Dictionary, respect_claims: bool) -> Variant:
	var lanes_in_order := lane_order.filter(func(key): return lanes.has(key))
	lanes_in_order.append_array(lanes.keys().filter(func(key): return not lanes_in_order.has(key)))
	var order := lanes_in_order
	if distribution == Distribution.ROUND_ROBIN and not lanes_in_order.is_empty():
		var start := _turn % lanes_in_order.size()
		order = lanes_in_order.slice(start) + lanes_in_order.slice(0, start)
	for key in order:
		var open: int = lanes[key].wanted().get(unit_def, 0)
		if respect_claims:
			open -= _claims(key, unit_def)
		if open > 0:
			_turn = lanes_in_order.find(key) + 1
			return key
	return null


func _claims(lane: String, unit_def: UnitDef = null) -> int:
	var count := 0
	for each_def in _builders:
		if unit_def == null or each_def == unit_def:
			count += _builders[each_def].filter(func(b): return b["lane"] == lane).size()
	return count


func _event(kind: String, tick: int, lane: String) -> Dictionary:
	return {"type": kind, "tick": tick, "faction": faction_id, "lane": lane}
