class_name SkirmishCameraRig
extends Camera2D
## The skirmish camera (Decision 48): units are small, so the mouse wheel zooms toward the
## cursor and a middle-button drag pans, to inspect a fight up close.

const MIN_ZOOM := 0.2
const MAX_ZOOM := 40.0
const WHEEL_STEP := 1.15


## Multiplies the zoom by `factor` (clamped), keeping the world point under `screen_point`
## where it is on screen.
func zoom_by(factor: float, screen_point: Vector2) -> void:
	var before := _to_world(screen_point)
	var level := clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2(level, level)
	position += before - _to_world(screen_point)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(WHEEL_STEP, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / WHEEL_STEP, event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		position -= event.relative / zoom.x


func _to_world(screen_point: Vector2) -> Vector2:
	var centre := get_viewport_rect().size * 0.5 if is_inside_tree() else Vector2.ZERO
	return position + (screen_point - centre) / zoom.x
