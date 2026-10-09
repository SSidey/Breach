class_name SightTrials
extends RefCounted
## A grem feels along a wall (spec 30): no leash, it plans on what it sees. A wall stands
## across its way, its only gap far to the south, out of sight. It plans to the edge of
## its sight the best plan runs out at, walks there facing the way it went, remembers what
## it saw (PathMemory) and plans again - until the gap comes into view and the goal is in
## reach. Its sight is a short-sighted grem's: 24 cells ahead, 12 to the sides, 6 behind.

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const TerrainPaths = preload("res://sim/skirmish/formation/terrain_paths.gd")
const PathSight = preload("res://sim/skirmish/formation/path_sight.gd")
const PathMemory = preload("res://sim/skirmish/formation/path_memory.gd")
const PathTrials = preload("res://sim/skirmish/formation/path_trials.gd")

const SIZE := Vector2i(64, 40)
## The wall, too high to climb, and the gap south of it.
const WALL := Rect2i(30, 0, 2, 34)
const GAP := Rect2i(30, 34, 2, 6)
const START := Vector2(5.5, 8.5)
const GOAL := Vector2(58.5, 8.5)
const AHEAD := 24.0
const SIDE := 12.0
const BEHIND := 6.0
## Plans before it gives up.
const MOST_PLANS := 20


static func ground() -> FormationTerrain:
	var terrain := FormationTerrain.new(SIZE)
	terrain.paint(WALL, {"height": 8, "climb": 3})
	return terrain


## {"plans": how many it made, "reaches": whether the last reached the goal, "cells": every
## cell it walked, "stops": where it planned from, "usec": the mean time a plan took}.
static func feel_along() -> Dictionary:
	var terrain := ground()
	var grem := TerrainWalker.new(1.0)
	var memory := PathMemory.new()
	var at := START
	var way := Vector2.RIGHT
	var out := {"plans": 0, "reaches": false, "cells": [], "stops": [], "usec": 0}
	var spent := 0
	while out["plans"] < MOST_PLANS and not out["reaches"]:
		var began := Time.get_ticks_usec()
		var sight := PathSight.new(at, way, AHEAD, SIDE, BEHIND)
		var planned := TerrainPaths.plan(terrain, grem, at, GOAL, sight, memory)
		spent += Time.get_ticks_usec() - began
		var points: PackedVector2Array = planned["waypoints"]
		out["plans"] += 1
		out["stops"].append(at)
		out["cells"].append_array(planned["cells"])
		out["reaches"] = planned["reaches"]
		if points.size() < 2:
			break
		way = (points[-1] - points[-2]).normalized()
		at = points[-1]
	out["usec"] = spent / maxi(1, out["plans"])
	return out


## The trial's lines: what it did, and its walk drawn over the ground.
static func report() -> PackedStringArray:
	var walk := feel_along()
	var stops := ", ".join(walk["stops"].map(func(at): return "(%d, %d)" % [at.x, at.y]))
	var out := PackedStringArray(
		[
			"\nfeeling along a wall (sight %d ahead, %d aside, %d behind):" % [AHEAD, SIDE, BEHIND],
			(
				"  %d plans, %s, %d us a plan; planned from %s"
				% [
					walk["plans"],
					"reached the goal" if walk["reaches"] else "gave up",
					walk["usec"],
					stops
				]
			),
		]
	)
	out.append_array(
		PathTrials.drawing(walk["cells"], Rect2i(Vector2i.ZERO, SIZE), 1, ground(), [WALL])
	)
	return out
