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


## The foes whose bodies' edges may come within `reach` of `point`, in the list's order;
## of those of the squads its "only" names ({squad: true}), if it has one (FoeIndex).
static func around(near: Dictionary, point: Vector2, reach: float) -> Array:
	var foes: Array = near["foes"]
	var only = near.get("only")
	var out := []
	for found in BodyGrid.near(near["grid"], point, reach + near["widest"] + MARGIN):
		if only == null or only.has(foes[found][1]):
			out.append(foes[found])
	return out


## As ScrumSlots.gap_to: cells from `at` to the nearest foe body's edge, less `radius` (0
## if it touches one); INF with no foes. Looks ring by ring outwards, stopping once no
## nearer foe can lie further out. The last answer bounds the next (the nearest edge moves
## no more than the point asked about): rings nearer than it could be are passed over, and
## those beyond it never looked at.
static func gap_to(near: Dictionary, at: Vector2, radius: float) -> float:
	var foes: Array = near["foes"]
	var points: Array = near["points"]
	var grid: Dictionary = near["grid"]
	var only = near.get("only")  # as around()
	var centre := BodyGrid.cell_of(at)
	var span := BodyGrid.ring_span(grid, centre)
	var least := INF
	var limit := INF  # the least it can come to: the last answer and how far from it this is
	var last: Array = near.get("last", [at, INF])
	if last[1] < INF:
		var shift: float = last[0].distance_to(at)
		limit = last[1] + shift - radius + MARGIN
		var nearest: float = last[1] - shift - MARGIN  # no foe's centre is nearer than this
		span.x = maxi(span.x, ceili(nearest / (BodyGrid.CELL * sqrt(2.0))) - 1)
	for ring_number in range(span.x, span.y + 1):
		var bound := minf(least, limit)
		var widest: float = near["widest"]
		if BodyGrid.floor_of(ring_number) - widest - radius - MARGIN > bound:
			break
		for found in BodyGrid.ring(grid, centre, ring_number, at, bound + widest + radius):
			if only != null and not only.has(foes[found][1]):
				continue
			var edge: float = points[found].distance_to(at)
			least = minf(least, edge - ScrumReach.radius(foes[found][0]) - radius)
	near["last"] = [at, least + radius]
	return maxf(least, 0.0)
