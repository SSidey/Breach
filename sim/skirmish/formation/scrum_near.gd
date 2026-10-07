class_name ScrumNear
extends RefCounted
## The foes near a unit, found through a grid (BodyGrid) rather than by looking at every
## foe on the field (spec 30 round 3). An index is taken of [[unit, squad], ...] where they
## stand at that moment (ScrumReach); a search gives back the foes it could concern in the
## list's own order - every one that qualifies, and only some that don't - so whatever
## looks through them picks exactly as it would through the whole list (Decision 97).
## Pure; cells.

const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const BodyGrid = preload("res://sim/skirmish/formation/body_grid.gd")

## Cells added to every search's reach: far above float rounding, so none is missed.
const MARGIN := 0.01


## {"foes", "points": where each stands, "grid", "widest": the largest body's radius}.
static func index(foes: Array) -> Dictionary:
	var points := []
	var widest := 0.0
	for entry in foes:
		points.append(ScrumReach.at(entry[1], entry[0]))
		widest = maxf(widest, ScrumReach.radius(entry[0]))
	return {"foes": foes, "points": points, "grid": BodyGrid.build(points), "widest": widest}


## The foes whose bodies' edges may come within `reach` of `point`, in the list's order.
static func around(near: Dictionary, point: Vector2, reach: float) -> Array:
	var foes: Array = near["foes"]
	var out := []
	for found in BodyGrid.near(near["grid"], point, reach + near["widest"] + MARGIN):
		out.append(foes[found])
	return out


## As ScrumSlots.gap_to: cells from `at` to the nearest foe body's edge, less `radius` (0
## if it touches one); INF with no foes. Looks ring by ring outwards, stopping once no
## nearer foe can lie further out.
static func gap_to(near: Dictionary, at: Vector2, radius: float) -> float:
	var foes: Array = near["foes"]
	var points: Array = near["points"]
	var grid: Dictionary = near["grid"]
	var centre := BodyGrid.cell_of(at)
	var least := INF
	for ring_number in range(BodyGrid.last_ring(grid, centre) + 1):
		var nearest_edge: float = BodyGrid.floor_of(ring_number) - near["widest"] - radius
		if nearest_edge - MARGIN > least:
			break
		for found in BodyGrid.ring(grid, centre, ring_number):
			var edge: float = points[found].distance_to(at)
			least = minf(least, edge - ScrumReach.radius(foes[found][0]) - radius)
	return maxf(least, 0.0)
