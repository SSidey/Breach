class_name SimulationClock
extends RefCounted
## Tick-boundary timing (Decision 1). Owns *when* a tick happens; knows nothing about
## what a tick does. See specs/01-simulation-clock-and-commands.md.
##
## Deliberately a plain RefCounted, not a Godot autoload/Node - driven by real elapsed
## time via advance_time(delta), called once per frame by whichever presentation-layer
## node owns the game loop, so this class never needs a scene-tree dependency.

@export var tick_duration_seconds: float = 1.0

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
	_elapsed_since_last_tick += delta
	if _elapsed_since_last_tick >= tick_duration_seconds:
		_elapsed_since_last_tick = 0.0
		advance_tick()


func skip_to_next_marker() -> void:
	_elapsed_since_last_tick = 0.0
	advance_tick()


func advance_tick() -> void:
	_tick_number += 1
	SimEvents.tick_advanced.emit(_tick_number)
