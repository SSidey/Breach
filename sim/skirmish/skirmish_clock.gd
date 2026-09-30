class_name SkirmishClock
extends RefCounted
## Fixed-step clock for the real-time skirmish feel test
## (specs/21-realtime-skirmish-feel-test.md). Unlike SimulationClock (the P-f-F-c slice,
## left unchanged), it carries leftover time between frames, so short ticks don't drift,
## and it can report several ticks due in one frame. Catch-up is capped so a long frame
## (a breakpoint, a window drag) doesn't flood the simulation.

const MAX_CATCH_UP_TICKS := 8

var tick_seconds: float = 0.25
var speed_multiplier: float = 1.0

var _accumulated := 0.0
var _paused := false
var _tick := 0


## Real seconds elapsed -> how many ticks the caller should step now.
func advance(delta: float) -> int:
	if _paused:
		return 0
	_accumulated += delta * speed_multiplier
	var due := int(floor((_accumulated + 0.000001) / tick_seconds))
	if due > MAX_CATCH_UP_TICKS:
		due = MAX_CATCH_UP_TICKS
		_accumulated = 0.0
	else:
		_accumulated = maxf(_accumulated - due * tick_seconds, 0.0)
	_tick += due
	return due


## How far into the next tick we are, 0..1 - for interpolating between tick states.
func fraction() -> float:
	return clampf(_accumulated / tick_seconds, 0.0, 1.0)


func tick_number() -> int:
	return _tick


func is_paused() -> bool:
	return _paused


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false
