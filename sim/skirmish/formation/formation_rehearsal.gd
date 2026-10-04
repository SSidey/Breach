class_name FormationRehearsal
extends RefCounted
## Planned rendezvous by rehearsal (Decision 87, spec 27 round 8): a wave's march is timed
## by marching its own units down its route in a private simulation with nothing else on
## the field - every pace, turn, narrowing and re-form exactly as the battle will run it,
## until something interferes (a fight, a queue). Pure.

const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const FormationRoute = preload("res://sim/skirmish/formation/formation_route.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const LIMIT_TICKS := 20000


## Ticks for a squad of `placements` ([[UnitDef, Vector2i(rank, column)], ...]) `width`
## wide to bring its front `cells` along `route`.
static func ticks_to(
	placements: Array,
	width: int,
	route: FormationRoute,
	cells: float,
	tick_seconds: float,
	terrain: FormationTerrain = null
) -> int:
	if placements.is_empty():
		return 0
	var cells_per_tile := float(MapLayoutDef.CELLS_PER_TILE)
	var sim := FormationSimulation.new(route.length_cells() / cells_per_tile, tick_seconds)
	sim.seek_contact = true
	sim.terrain = terrain
	var squad := sim.spawn_squad(width, placements, "player", true, 0, route)
	for tick in range(LIMIT_TICKS):
		if squad.front_distance * cells_per_tile >= cells - 0.000001:
			return tick
		sim.step()
	return LIMIT_TICKS


## The filled places of a wave's preview (FormationProduction.preview) as placements.
static func placements_of(preview: Array) -> Array:
	var out := []
	for place in preview:
		if place[4]:
			out.append([place[5], Vector2i(place[0], place[1])])
	return out
