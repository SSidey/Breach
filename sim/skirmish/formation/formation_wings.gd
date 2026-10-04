class_name FormationWings
extends RefCounted
## Wings (Decision 81, spec 27 round 2): in a front-to-front fight, a squad's front units
## that overlap no enemy - they stand past the end of a narrower enemy line - walk round
## the end onto the enemy's side, instead of the abstract wrap. Each takes a place beside
## the enemy's side face, one per rank of the enemy's depth, nearest units first; units
## left over stay put. A wing walks at the in-fight pace (forward first, then in), strikes
## nothing on the way, and on arrival fights the enemy's units on that edge: its first
## interval of blows are flank blows, and edge units not held by their own front turn to
## it. A wing reaches the side only; going on to the rear waits for discipline. When the
## fight ends its wings walk back to their places. Squads keep `wings`: unit id ->
## {"unit", "at", "to", "foe", "edge", "slot", "since", "returning"}. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadEdges = preload("res://sim/skirmish/formation/squad_edges.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadGeometry = preload("res://sim/skirmish/formation/squad_geometry.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

## Walking within a fight is slowed by the crush (Decision 48; FormationShuffle.CROWDING).
const CROWDING := 0.2
const EPSILON := 0.0001


## One tick of walking: new wings set out, wings whose fight ended head back, and every
## wing moves. Returns "wing_arrived" and "wing_returned" events.
static func march(squads: Array, tick: int, cells_per_second: float, tick_seconds: float) -> Array:
	var by_id := {}
	for entry in squads:
		by_id[entry.id] = entry
	var events := []
	for squad in squads:
		var foe: SkirmishSquad = by_id.get(squad.engaged_with)
		if foe != null and _frontal(squad, foe):
			_set_out(squad, foe)
		for unit_id in squad.wings.keys():
			var wing: Dictionary = squad.wings[unit_id]
			if not wing["unit"].is_alive():
				squad.wings.erase(unit_id)
				continue
			if not wing["returning"] and (foe == null or foe.id != wing["foe"]):
				wing["returning"] = true
			if wing["returning"]:
				wing["to"] = _home(squad, wing["unit"])
			var pace: float = wing["unit"].speed * cells_per_second * tick_seconds
			if wing["returning"]:
				wing["at"] = wing["at"].move_toward(wing["to"], pace)
			else:
				wing["at"] = _step(wing, squad.facing, pace * CROWDING)
			if wing["at"].distance_to(wing["to"]) > EPSILON:
				continue
			if wing["returning"]:
				squad.wings.erase(unit_id)
				events.append(_event("wing_returned", tick, squad, wing))
			elif wing["since"] < 0:
				wing["since"] = tick
				events.append(_event("wing_arrived", tick, squad, wing))
				if foe != null:
					FormationMorale.shock(foe, FormationMorale.WING_IMPACT, tick, events)
	return events


## True if the unit is out on a wing: it strikes only through blows() here.
static func is_wing(squad: SkirmishSquad, unit: SkirmishUnit) -> bool:
	return squad.wings.has(unit.id)


## This tick's blows by arrived wings, and back at them: [[attacker, target, damage, flank]].
static func blows(squads: Array, interval: int, tick: int) -> Array:
	var by_id := {}
	for entry in squads:
		by_id[entry.id] = entry
	var out := []
	for squad in squads:
		for unit_id in squad.wings:
			var wing: Dictionary = squad.wings[unit_id]
			var foe: SkirmishSquad = by_id.get(wing["foe"])
			if foe == null or wing["since"] < 0 or wing["returning"]:
				continue
			var on_edge := SquadEdges.edge_units(foe, wing["edge"])
			var fresh: bool = tick - wing["since"] < interval
			_strike(wing["unit"], wing["at"], on_edge, foe, fresh, interval, out)
			for unit in on_edge:
				if foe.engaged_with != 0 and unit.rank == 0:
					continue  # held by its own front: a corner strikes back at one foe
				var rect := SquadFrame.unit_rect(
					foe.position, foe.facing, foe.width, foe.centre_shift, unit
				)
				_strike(unit, rect.get_center(), [wing["unit"]], squad, false, interval, out)
	return out


static func _frontal(squad: SkirmishSquad, foe: SkirmishSquad) -> bool:
	return (
		squad.state == SkirmishSquad.State.FIGHTING
		and SquadGeometry.facing_off(squad, foe)
		and not foe.is_destroyed()
	)


## Gives each front unit past the foe's line ends a free place beside the foe's side.
static func _set_out(squad: SkirmishSquad, foe: SkirmishSquad) -> void:
	if FormationMorale.band(squad) != FormationMorale.Band.STEADY:
		return  # a shaken squad sends no wings (Decision 82)
	var ahead := SquadFrame.forward(squad.facing)
	var across := SquadFrame.right(squad.facing)
	var area := SquadEdges.bounds(foe)
	var line := SquadFrame.lateral_interval(area, squad.facing)
	var front := _near(area, ahead)
	var depth := maxi(1, roundi(_near(area, -ahead) * -1.0 - front))
	var waiting := []
	for unit in squad.fighters():
		if squad.wings.has(unit.id):
			continue
		var span := squad.lateral_span(unit)
		if span.y <= line.x + EPSILON:
			waiting.append([line.x - span.y, unit, -1])
		elif span.x >= line.y - EPSILON:
			waiting.append([span.x - line.y, unit, 1])
	waiting.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1].id < b[1].id))
	for entry in waiting:
		var side: int = entry[2]
		var slot := _free_slot(squad, foe.id, side, depth)
		if slot < 0:
			continue
		var lateral := (line.y + 0.5) if side > 0 else (line.x - 0.5)
		var unit: SkirmishUnit = entry[1]
		var to := _origin_point(ahead, across, front + slot + 0.5, lateral)
		var facing_of_side := squad.facing + (1 if side > 0 else 3)
		squad.wings[unit.id] = {
			"unit": unit,
			"at": unit.position,
			"to": to,
			"foe": foe.id,
			"edge": SquadEdges.edge_hit(foe, SquadFrame.opposite(facing_of_side)),
			"slot": [side, slot],
			"since": -1,
			"returning": false,
		}


static func _free_slot(squad: SkirmishSquad, foe_id: int, side: int, depth: int) -> int:
	for slot in range(depth):
		var taken := squad.wings.values().any(
			func(w): return w["foe"] == foe_id and w["slot"] == [side, slot]
		)
		if not taken:
			return slot
	return -1


## A wing walks forward first (past the enemy's front), then in to its place.
static func _step(wing: Dictionary, facing: int, pace: float) -> Vector2:
	var ahead := SquadFrame.forward(facing)
	var at: Vector2 = wing["at"]
	var to: Vector2 = wing["to"]
	var forward_left: float = (to - at).dot(ahead)
	if absf(forward_left) > EPSILON:
		return at + ahead * clampf(forward_left, -pace, pace)
	return at.move_toward(to, pace)


static func _home(squad: SkirmishSquad, unit: SkirmishUnit) -> Vector2:
	var rect := SquadFrame.unit_rect(
		squad.position, squad.facing, squad.width, squad.centre_shift, unit
	)
	return rect.get_center()


static func _near(area: Rect2, direction: Vector2) -> float:
	var best := INF
	for corner in [
		area.position,
		area.end,
		Vector2(area.position.x, area.end.y),
		Vector2(area.end.x, area.position.y)
	]:
		best = minf(best, corner.dot(direction))
	return best


## The world point with these coordinates along `ahead` and `across` (unit axes).
static func _origin_point(ahead: Vector2, across: Vector2, along: float, lateral: float) -> Vector2:
	return ahead * along + across * lateral


static func _strike(
	unit: SkirmishUnit,
	at: Vector2,
	targets: Array,
	target_squad: SkirmishSquad,
	flank: bool,
	interval: int,
	out: Array
) -> void:
	var target: SkirmishUnit = null
	var best := INF
	for candidate in targets:
		var where := _where(target_squad, candidate)
		var gap := at.distance_to(where)
		if gap < best - EPSILON:
			best = gap
			target = candidate
	if target == null:
		return
	unit.target_id = target.id
	unit.attack_cooldown -= 1
	if unit.attack_cooldown > 0:
		return
	unit.attack_cooldown = interval
	out.append([unit, target, FormationCombat.damage(unit, flank), flank])


static func _where(squad: SkirmishSquad, unit: SkirmishUnit) -> Vector2:
	if squad.wings.has(unit.id):
		return squad.wings[unit.id]["at"]
	return _home(squad, unit)


static func _event(kind: String, tick: int, squad: SkirmishSquad, wing: Dictionary) -> Dictionary:
	var extra := {"unit": wing["unit"].id, "edge": wing["edge"]}
	return FormationEvents.squad_event(kind, tick, squad, extra)
