class_name FormationSweep
extends RefCounted
## A formation sweeps round its route's bends (Decision 105, spec 30 round 1): as it
## marches, its frame turns towards its route's heading where its front is, no faster than
## its outer file can march the arc - pivoting on its front centre, the file half its width
## out covers a quarter circle in the time a wheel took (SquadTurn). A 5 degree bend and a
## 90 degree bend follow the same rule, so it doesn't halt to turn; at a sharp bend it cuts
## the corner a little. Going back the way it faces is an about-face instead (ScrumTurn).
## Pure over the squad it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")


## Degrees a second the squad's frame may turn marching at `cells_per_second`.
static func rate(squad: SkirmishSquad, cells_per_second: float) -> float:
	var arm := maxf(squad.width / 2.0, 0.5)  # its outer file's distance from the pivot
	return rad_to_deg(cells_per_second / arm)


## Turns the squad's frame towards its route's heading at its front, by what its rate allows
## in `seconds`.
static func step(squad: SkirmishSquad, cells_per_second: float, seconds: float) -> void:
	if squad.route == null:
		return
	var cells := squad.front_distance * MapLayoutDef.CELLS_PER_TILE
	var way := squad.route.heading_at(cells) * squad.direction
	var wanted := UnitMotion.bearing_to(Vector2.ZERO, way, squad.heading)
	var left := fposmod(wanted - squad.heading + 180.0, 360.0) - 180.0  # the short way
	var reach := rate(squad, cells_per_second) * seconds
	squad.heading = fposmod(squad.heading + clampf(left, -reach, reach), 360.0)
