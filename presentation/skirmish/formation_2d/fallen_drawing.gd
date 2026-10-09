class_name FallenDrawing
extends RefCounted
## How the field draws those out of the fight (Decisions 121 and 126), where they lie: the
## downed as a faded body crossed in red, one borne by a friend as a small dark dot on its
## bearer, the dead as a small dark cross, the taken -
## captured or surrendered - as a ring in their side's colour with a bar across it.

const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

const DEAD := Color(0.12, 0.1, 0.1, 0.8)
const WOUND := Color(1, 0.2, 0.2)


## Draws `unit` on `canvas` if it is out of the fight; `centre` and `radius` in pixels,
## `colour` its side's.
static func draw(canvas: CanvasItem, unit, centre: Vector2, radius: float, colour: Color) -> void:
	var arm := Vector2(radius, radius) * 0.6
	match unit.state:
		SkirmishUnit.State.DOWNED:
			var faded := colour.darkened(0.4)
			faded.a = 0.6
			canvas.draw_circle(centre, radius, faded)
			_cross(canvas, centre, arm, WOUND)
		SkirmishUnit.State.DEAD:
			_cross(canvas, centre, arm * 0.8, DEAD)
		SkirmishUnit.State.CARRIED:
			canvas.draw_circle(centre, radius * 0.6, DEAD)  # a dark dot on its bearer
			canvas.draw_arc(centre, radius * 0.6, 0.0, TAU, 12, WOUND, 1.0)
		SkirmishUnit.State.TAKEN:
			canvas.draw_arc(centre, radius, 0.0, TAU, 16, colour, 1.0)
			canvas.draw_line(centre - Vector2(radius, 0), centre + Vector2(radius, 0), DEAD, 1.0)


static func _cross(canvas: CanvasItem, centre: Vector2, arm: Vector2, colour: Color) -> void:
	canvas.draw_line(centre - arm, centre + arm, colour, 1.0)
	canvas.draw_line(centre + Vector2(arm.x, -arm.y), centre - Vector2(arm.x, -arm.y), colour, 1.0)
