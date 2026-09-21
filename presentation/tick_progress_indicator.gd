class_name TickProgressIndicator
extends Node2D
## Shows progress toward the next tick, per specs/05-presentation-and-hud.md. Reuses
## TickInterpolation.elapsed_fraction exactly as LaneView already does for unit
## position - the only pure logic involved is already tested there, so this file
## tracks elapsed time and draws, nothing more.
##
## Self-subscribes to SimEvents.tick_advanced in _ready(), same reasoning as LaneView
## (specs/05): a Node's scene-tree lifecycle handles disconnection automatically, so
## the sim/ RefCounted self-subscription concern doesn't apply here.

const TickInterpolation = preload("res://presentation/tick_interpolation.gd")

var tick_duration_seconds: float = 1.0
var bar_width: float = 100.0
var bar_height: float = 10.0

var _elapsed_since_last_tick: float = 0.0


func _ready() -> void:
	SimEvents.tick_advanced.connect(_on_tick_advanced)


func _process(delta: float) -> void:
	_elapsed_since_last_tick += delta
	queue_redraw()


func _draw() -> void:
	var fraction := TickInterpolation.elapsed_fraction(
		_elapsed_since_last_tick, tick_duration_seconds
	)
	draw_rect(Rect2(0.0, 0.0, bar_width, bar_height), Color.DIM_GRAY)
	draw_rect(Rect2(0.0, 0.0, bar_width * fraction, bar_height), Color.LIGHT_BLUE)


func _on_tick_advanced(_tick_number: int) -> void:
	_elapsed_since_last_tick = 0.0
	queue_redraw()
