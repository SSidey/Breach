class_name FormationNarrowing
extends RefCounted
## Gaps narrower than a squad (Decision 85, spec 27 round 4). Looking a few cells ahead,
## a squad measures the passable run of ground across its facing, centred on its route.
## - **Narrowing:** if the run is narrower than its line, it narrows into a column that
##   fits: front band first and nearest the centre first, the extra columns folding into
##   the ranks behind (the fold of Decision 42). It keeps its painted places, and holds
##   while it re-forms (a thin front is what makes a chokepoint dangerous).
## - **Widening:** once the ground ahead is open to its painted width and its painted
##   places stand on open ground again, it widens back.
## - **Too wide:** a unit wider than the gap halts the squad with a "too_wide" alert; going
##   round within its leash comes with leash pathing.
## Squads keep `painted` (unit id -> [rank, column]), `painted_width`, `painted_shift` and
## `narrow_ticks`. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const SquadGeometry = preload("res://sim/skirmish/formation/squad_geometry.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")

## Cells ahead of its front a squad looks for a gap, and the widest run it measures.
const LOOK := 3
const REACH := 16
## Seconds a squad holds while narrowing or widening.
const REFORM_SECONDS := 1.0


## True if the squad holds this tick to narrow or widen (or can't fit through).
static func holds(
	squad: SkirmishSquad, terrain: FormationTerrain, tick: int, tick_seconds: float, events: Array
) -> bool:
	if terrain == null or squad.living().is_empty():
		return false
	if squad.narrow_ticks > 0:
		squad.narrow_ticks -= 1
		return true
	var gap := gap_ahead(squad, terrain)
	if squad.painted.is_empty():
		if gap.x < 1.0 or gap.x >= _line_width(squad) - 0.0001:
			return false  # open enough, or no way through at all (FormationMarch.pace halts it)
		return _narrow(squad, gap, tick, tick_seconds, events)
	if gap.x >= squad.painted_width - 0.0001 and _open_for_painted(squad, terrain):
		_widen(squad, tick, tick_seconds, events)
		return true
	return false


## [width, centre offset] of the passable run across the squad's facing, the narrowest
## within LOOK cells ahead of its front (cells; the offset along its right hand).
static func gap_ahead(squad: SkirmishSquad, terrain: FormationTerrain) -> Vector2:
	var ahead := SquadFrame.forward(squad.facing)
	var best := Vector2(INF, 0.0)
	for step in range(1, LOOK + 1):
		var centre := squad.position + ahead * (step - 0.5)
		var run := run_across(terrain, centre, squad.facing, _shortest(squad))
		if run.x < best.x:
			best = run
	return best


## [width, centre offset] of the passable run through `centre` across `facing` for units
## `height` tall (cells; the offset along the facing's right hand).
static func run_across(
	terrain: FormationTerrain, centre: Vector2, facing: int, height: float
) -> Vector2:
	var ahead := SquadFrame.forward(facing)
	var right := SquadFrame.right(facing)
	var sides := [0, 0]
	for side in [0, 1]:
		var sign := 1.0 if side == 0 else -1.0
		while sides[side] < REACH:
			var at: Vector2 = centre + right * sign * (sides[side] + 0.5)
			if terrain.factor(height, at - ahead, at) <= 0.0:
				break
			sides[side] += 1
	return Vector2(float(sides[0] + sides[1]), (sides[0] - sides[1]) / 2.0)


static func _narrow(
	squad: SkirmishSquad, gap: Vector2, tick: int, tick_seconds: float, events: Array
) -> bool:
	var columns := int(gap.x)
	var widest := 0
	for unit in squad.living():
		widest = maxi(widest, unit.footprint_width)
	if widest > columns:
		if not squad.blocked:
			events.append(FormationEvents.squad_event("too_wide", tick, squad, {"gap": columns}))
		squad.blocked = true
		return true
	for unit in squad.units:
		squad.painted[unit.id] = [unit.rank, unit.column]
	squad.painted_width = squad.width
	squad.painted_shift = squad.centre_shift
	_fold(squad, columns)
	squad.centre_shift = gap.y
	squad.swaps.clear()
	squad.narrow_ticks = roundi(REFORM_SECONDS / tick_seconds)
	events.append(FormationEvents.squad_event("narrowed", tick, squad, {"width": columns}))
	return true


## Lays the living units into rows `columns` wide: front band first, then nearest the
## centre, each row as deep as its deepest unit.
static func _fold(squad: SkirmishSquad, columns: int) -> void:
	var middle := squad.width / 2.0
	var order := squad.living()
	order.sort_custom(
		func(a, b):
			if a.preferred_position != b.preferred_position:
				return a.preferred_position < b.preferred_position
			var da := absf(a.column + a.footprint_width / 2.0 - middle)
			var db := absf(b.column + b.footprint_width / 2.0 - middle)
			return da < db or (is_equal_approx(da, db) and a.id < b.id)
	)
	var rank := 0
	var column := 0
	var depth := 1
	for unit in order:
		if column + unit.footprint_width > columns:
			rank += depth
			column = 0
			depth = 1
		unit.rank = rank
		unit.column = column
		column += unit.footprint_width
		depth = maxi(depth, unit.footprint_depth)
	squad.width = columns


static func _open_for_painted(squad: SkirmishSquad, terrain: FormationTerrain) -> bool:
	var back := -SquadFrame.forward(squad.facing)
	for unit in squad.living():
		if not squad.painted.has(unit.id):
			continue
		var place: Array = squad.painted[unit.id]
		var ghost := SkirmishUnit.new()
		ghost.rank = place[0]
		ghost.column = place[1]
		ghost.footprint_width = unit.footprint_width
		ghost.footprint_depth = unit.footprint_depth
		var rect := SquadFrame.unit_rect(
			squad.position, squad.facing, squad.painted_width, squad.painted_shift, ghost
		)
		var at := rect.get_center()
		if terrain.factor(unit.height, at + back, at) <= 0.0:
			return false
	return true


static func _widen(squad: SkirmishSquad, tick: int, tick_seconds: float, events: Array) -> void:
	for unit in squad.units:
		if squad.painted.has(unit.id):
			unit.rank = squad.painted[unit.id][0]
			unit.column = squad.painted[unit.id][1]
	squad.width = squad.painted_width
	squad.centre_shift = squad.painted_shift
	squad.painted.clear()
	squad.compact()
	squad.reforming = true
	squad.narrow_ticks = roundi(REFORM_SECONDS / tick_seconds)
	events.append(FormationEvents.squad_event("widened", tick, squad, {"width": squad.width}))


static func _line_width(squad: SkirmishSquad) -> float:
	var span := SquadGeometry.lateral(squad)
	return span.y - span.x


## The shortest living unit's height: the gap must pass all of them.
static func _shortest(squad: SkirmishSquad) -> float:
	var least := INF
	for unit in squad.living():
		least = minf(least, unit.height)
	return least
