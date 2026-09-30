class_name SkirmishCamera
extends RefCounted
## Frames a skirmish map in the part of the window a left-hand HUD panel leaves free.


static func frame(camera: Camera2D, bounds: Rect2, viewport_size: Vector2, panel: float) -> void:
	var usable := Vector2(maxf(viewport_size.x - panel, 1.0), viewport_size.y)
	var fit := minf(usable.x / bounds.size.x, usable.y / bounds.size.y) * 0.92
	camera.zoom = Vector2(fit, fit)
	camera.position = bounds.get_center() - Vector2(panel * 0.5, 0.0) / fit
