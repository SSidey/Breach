class_name TickInterpolation
extends RefCounted
## Pure interpolation math for rendering between two tick boundaries (Decision 1),
## per specs/05-presentation-and-hud.md. No engine/scene-tree dependency at all - the
## one part of presentation/ that's fully headless-testable; LaneView (a real Node2D)
## calls into this rather than duplicating the math.


static func elapsed_fraction(elapsed_seconds: float, tick_duration_seconds: float) -> float:
	if tick_duration_seconds <= 0.0:
		return 0.0
	return clamp(elapsed_seconds / tick_duration_seconds, 0.0, 1.0)


static func interpolate_position(
	previous_position: float, current_position: float, fraction: float
) -> float:
	var clamped_fraction: float = clamp(fraction, 0.0, 1.0)
	return lerp(previous_position, current_position, clamped_fraction)
