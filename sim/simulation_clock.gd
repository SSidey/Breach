class_name SimulationClock
extends RefCounted
## Tick-boundary timing (Decision 1). Owns *when* a tick happens; knows nothing about
## what a tick does. See specs/01-simulation-clock-and-commands.md.
##
## Deliberately a plain RefCounted, not a Godot autoload/Node - driven by real elapsed
## time via advance_time(delta), called once per frame by whichever presentation-layer
## node owns the game loop, so this class never needs a scene-tree dependency.
##
## speed_multiplier/auto_pause_each_tick (Phase 4 follow-up) are plain fields, not
## methods - ISP was already at the 7-method ceiling. Both default to their neutral/
## off value (1.0, false); a game that wants auto-pause on by default sets the field
## explicitly at the composition root, per specs/05's Notes.

@export var tick_duration_seconds: float = 1.0
@export var speed_multiplier: float = 1.0
@export var auto_pause_each_tick: bool = false

var _tick_number: int = 0
var _elapsed_since_last_tick: float = 0.0
var _paused: bool = false


func tick_number() -> int:
	return _tick_number


func is_paused() -> bool:
	return _paused


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func advance_time(delta: float) -> void:
	if _paused:
		return
	_elapsed_since_last_tick += delta * speed_multiplier
	if _elapsed_since_last_tick >= tick_duration_seconds:
		_elapsed_since_last_tick = 0.0
		advance_tick()


func skip_to_next_marker() -> void:
	_elapsed_since_last_tick = 0.0
	advance_tick()


func advance_tick() -> void:
	_tick_number += 1
	SimEvents.tick_advanced.emit(_tick_number)
	if auto_pause_each_tick:
		pause()
