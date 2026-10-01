class_name SkirmishUnitLayer
extends Node2D
## Draws the skirmish's units on top of the map, per
## specs/21-realtime-skirmish-feel-test.md: each at its distance interpolated between the
## last two ticks (TickInterpolation) and placed on the route polyline (SkirmishRoute),
## with faction colour, an HP bar, a mark while fighting and a selection ring. Rendering
## only - read-only over sim/.

const SkirmishSimulation = preload("res://sim/skirmish/skirmish_simulation.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SkirmishRoute = preload("res://presentation/skirmish/skirmish_route.gd")
const TickInterpolation = preload("res://presentation/tick_interpolation.gd")

const RADIUS := 12.0
## Player units sit a little above the route line and kingdom units below, so two units
## fighting at almost the same distance stay readable.
const LANE_OFFSET := 7.0
## Same-faction units closer than this (in cells) are fanned out sideways so a wave reads
## as a group instead of one stacked marker. Drawing only; the simulation is unchanged.
const CLUSTER_CELLS := 0.2
const FAN_STEP := 16.0

var simulation: SkirmishSimulation
var route_points := PackedVector2Array()
var cell_size := 64.0
var faction_colors := {"player": Color("#b3761d"), "the_kingdom": Color("#a3372a")}
## 0..1 into the next tick (from SkirmishClock.fraction()).
var fraction := 1.0
var selected_id := 0

var _previous := {}  # unit id -> distance at the previous tick
var _current := {}  # unit id -> distance at the latest tick


## Call after each simulation tick: the latest distances become the interpolation target.
func snapshot() -> void:
	_previous = _current.duplicate()
	_current = {}
	for entry in simulation.units():
		_current[entry.id] = entry.distance
		if not _previous.has(entry.id):
			_previous[entry.id] = entry.distance


func position_of(entry: SkirmishUnit) -> Vector2:
	return _positions().get(entry.id, Vector2.ZERO)


## id -> drawn position: interpolated along the route, each faction on its side of the
## line, and units of one faction at (almost) the same distance fanned out sideways.
func _positions() -> Dictionary:
	var placed := {}
	var clusters := {}  # "faction|bucket" -> how many already placed there
	for entry in simulation.units():
		if not entry.is_alive():
			continue
		var previous: float = _previous.get(entry.id, entry.distance)
		var current: float = _current.get(entry.id, entry.distance)
		var distance := TickInterpolation.interpolate_position(previous, current, fraction)
		var bucket := "%s|%d" % [entry.faction_id, roundi(distance / CLUSTER_CELLS)]
		var rank: int = clusters.get(bucket, 0)
		clusters[bucket] = rank + 1
		var side := -1.0 if entry.advance_direction > 0 else 1.0
		var offset := Vector2(0, side * (LANE_OFFSET + rank * FAN_STEP))
		placed[entry.id] = SkirmishRoute.point_at(route_points, distance, cell_size) + offset
	return placed


## The living unit under a point (in this node's space), nearest first; 0 if none.
func unit_at(point: Vector2) -> int:
	var best := 0
	var best_distance := RADIUS * 1.6
	var placed := _positions()
	for unit_id in placed:
		var gap: float = placed[unit_id].distance_to(point)
		if gap <= best_distance:
			best = unit_id
			best_distance = gap
	return best


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if simulation == null:
		return
	var placed := _positions()
	for entry in simulation.units():
		if entry.is_alive():
			_draw_unit(entry, placed[entry.id])


func _draw_unit(entry: SkirmishUnit, at: Vector2) -> void:
	var color: Color = faction_colors.get(entry.faction_id, Color.GRAY)
	if entry.state == SkirmishUnit.State.ARRIVED:
		color.a = 0.45
	if entry.id == selected_id:
		draw_arc(at, RADIUS + 5.0, 0.0, TAU, 32, Color.WHITE, 3.0, true)
	draw_circle(at, RADIUS, color)
	draw_arc(at, RADIUS, 0.0, TAU, 32, Color("#211d15"), 2.0, true)
	var bar := Rect2(at + Vector2(-RADIUS, -RADIUS - 9.0), Vector2(RADIUS * 2.0, 4.0))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var share := clampf(float(entry.hp) / float(maxi(entry.max_hp, 1)), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), Color("#7fbf88"))
	if entry.state == SkirmishUnit.State.FIGHTING:
		var mark := RADIUS * 0.55
		draw_line(at + Vector2(-mark, -mark), at + Vector2(mark, mark), Color.WHITE, 2.5)
		draw_line(at + Vector2(mark, -mark), at + Vector2(-mark, mark), Color.WHITE, 2.5)
	elif entry.state == SkirmishUnit.State.HOLDING:
		draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), Color.WHITE)
	elif entry.order == SkirmishUnit.Order.RETREAT:
		draw_line(at, at + Vector2(-entry.advance_direction * RADIUS, 0), Color.WHITE, 3.0)
