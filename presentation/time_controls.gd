class_name TimeControls
extends Control
## Play/pause and skip-to-marker, per specs/05-presentation-and-hud.md. Each method
## calls exactly one SimulationClock method and nothing else - the spec's "affect
## timing only, never simulation content" scenario. Button wiring itself
## (button.pressed.connect(...)) is untested engine glue, same honesty as LaneView's
## _ready/_process/_draw - these on_x_pressed() methods are what's actually verified.

var simulation_clock: SimulationClock
var lane_view: LaneView


func on_pause_pressed() -> void:
	if simulation_clock.is_paused():
		simulation_clock.resume()
	else:
		simulation_clock.pause()


func on_skip_pressed() -> void:
	simulation_clock.skip_to_next_marker()
	if lane_view != null:
		lane_view.snap_to_current_tick()
