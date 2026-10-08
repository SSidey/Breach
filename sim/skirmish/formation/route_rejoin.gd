class_name RouteRejoin
extends RefCounted
## Where a group off its route rejoins it (spec 30): where the walk to the route plus the
## march along it to its end is quickest - so it doesn't double back to the nearest stretch
## when a point ahead is quicker overall, and doubles back when that is the only way.
## Among the ways within path_rejoin_slack of the quickest, it takes the one back on the
## route soonest (the user's choice, from a simulation of both rules). The march along the
## route is timed at the walker's own pace there (FormationTerrain.crossing): the route is
## the command's, and the ground along it is known to it. A PathSearch offers it each
## route cell as it settles; ties go to the order the search settles them in, which
## geometry decides (PathFrontier). Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")

## How finely (cells) the march along the route is timed.
const SAMPLE := 0.5
## Times within this (seconds) of each other are equal: float noise never decides.
const BETTER := 0.000001

## The route's end, which every way leads to.
var end: Vector2

var _route: FormationRoute
var _slack: float
var _march := PackedFloat64Array()  # the time from each sample along the route to its end
var _best := INF  # the quickest way's time to the end so far
var _offers := []  # [cell index, time to the route, time to the end], as settled


## Ready to choose where `walker` rejoins `route` on `terrain`, taking ways within `slack`
## (a share; negative: the tuning's path_rejoin_slack) of the quickest.
func _init(
	terrain: FormationTerrain, walker: TerrainWalker, route: FormationRoute, slack: float = -1.0
) -> void:
	_route = route
	_slack = BattleTuning.current().path_rejoin_slack if slack < 0.0 else slack
	var length := route.length_cells()
	end = route.point_at(length)
	var count := ceili(length / SAMPLE)
	_march.resize(count + 1)
	_march[count] = 0.0
	for index in range(count - 1, -1, -1):
		var from := route.point_at(index * SAMPLE)
		var to := route.point_at(minf((index + 1) * SAMPLE, length))
		var pace := terrain.crossing(walker, from, to)
		var leg := from.distance_to(to) / pace if pace > 0.0 else INF
		_march[index] = _march[index + 1] + leg


## The least time a way from `point` to the route's end can take: the straight distance
## at full pace, less how far off the route's line a route cell's centre may lie.
func estimate(point: Vector2, on_route: float) -> float:
	return maxf(0.0, point.distance_to(end) - on_route)


## Offers the route cell at `index`, whose centre is `centre`, reached in `reach` seconds.
func offer(index: int, centre: Vector2, reach: float) -> void:
	var total := reach + march(_route.distance_of(centre))
	if total == INF:
		return
	_offers.append([index, reach, total])
	_best = minf(_best, total)


## The time of the march from `along` the route to its end.
func march(along: float) -> float:
	var at := clampi(ceili(along / SAMPLE - BETTER), 0, _march.size() - 1)
	var short := at * SAMPLE - along  # from `along` to the sample
	if at == 0 or short <= 0.0:
		return _march[at]
	var step := _march[at - 1] - _march[at]
	return _march[at] + step * short / SAMPLE


## Whether no way still unsettled, its least time `least`, can be among the chosen.
func settled(least: float) -> bool:
	return least > _bound()


## The route cell chosen (its index), or -1: of the ways within the slack of the quickest,
## the one back on the route soonest, then the quickest, then the first settled.
func chosen() -> int:
	var pick: Array = []
	for offered in _offers:
		if offered[2] > _bound():
			continue
		if pick.is_empty() or offered[1] < pick[1] - BETTER:
			pick = offered
		elif absf(offered[1] - pick[1]) <= BETTER and offered[2] < pick[2] - BETTER:
			pick = offered
	return -1 if pick.is_empty() else pick[0]


func _bound() -> float:
	return _best * (1.0 + _slack) + BETTER
