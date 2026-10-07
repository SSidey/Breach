class_name PathTrials
extends RefCounted
## Paths over the feel test's field (spec 30 round 3, TerrainPaths): its grass, wood,
## stream with a 4-cell ford and hill (FormationField's), with a crag added - a
## 2-cell cliff across the south, open to the north - for a climber to climb. Four walkers
## go each trip: a grem, a militiaman loaded past the sinking load, a cart that sinks and a
## climbing grem. Each search is timed (the mean of `repeats`) and drawn as text:
## '.' grass, 'T' wood, '=' wading water, '~' deep water, '^' hill, '#' crag, '*' the way.

const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const TerrainPaths = preload("res://sim/skirmish/formation/terrain_paths.gd")
const PathSearch = preload("res://sim/skirmish/formation/path_search.gd")
const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const ItemDef = preload("res://content/definitions/item_def.gd")

const GREM := "res://content/units/grem.tres"
const CRAG := Rect2i(70, 26, 4, 31)
const CRAG_QUARTERS := 8
## Trip -> [from, to, leash (negative: the tuned one)].
const TRIPS := {
	"across": [Vector2(2.5, 40.5), Vector2(125.5, 40.5), -1.0],
	"across, no leash": [Vector2(2.5, 40.5), Vector2(125.5, 40.5), INF],
	"stream": [Vector2(20.5, 6.5), Vector2(40.5, 6.5), -1.0],
	"16 cells": [Vector2(40.5, 40.5), Vector2(56.5, 40.5), -1.0],
}
const WALKERS := ["grem", "loaded militiaman", "cart (sinks)", "climber"]
const FIELD_VIEW := Rect2i(0, 0, 128, 64)
const STREAM_VIEW := Rect2i(14, 0, 34, 26)
## What the militiaman carries on top of his spear: past the sinking load.
const PACK_WEIGHT := 14.0
## The budget a tick may spend on path searches (ms), for the report.
const BUDGET_MS := 5.0


## A row a trip and walker: "trip", "walker", "cells", "waypoints", "seconds" (along the
## way at its speed), "search_usec" (the mean of `repeats` searches), "find_usec" (a
## search and straightening) and "expanded" (cells searched).
static func run(repeats: int) -> Array:
	var terrain := ground()
	var rows := []
	for trip in TRIPS:
		var spec: Array = TRIPS[trip]
		var leash: float = BattleTuning.current().paths_leash if spec[2] < 0.0 else spec[2]
		for name in WALKERS:
			var unit_def := _unit(name)
			var walker := TerrainWalker.of(unit_def)
			var row := _timed(terrain, walker, spec[0], spec[1], leash, repeats)
			row.merge({"trip": trip, "walker": name})
			row["seconds"] = TerrainPaths.cost(terrain, walker, row["waypoints"]) / unit_def.speed
			rows.append(row)
	return rows


## The field's ground with the crag.
static func ground() -> FormationTerrain:
	var grem: UnitDef = load(GREM)
	var terrain: FormationTerrain = FormationField.new(0.1, grem, 0, grem).sim.terrain
	terrain.paint(CRAG, {"height": CRAG_QUARTERS})
	return terrain


## `view` of the ground drawn a character a `scale` x `scale` block, with `cells` on it.
static func drawing(cells: Array, view: Rect2i, scale: int) -> PackedStringArray:
	var terrain := ground()
	var on_way := {}
	for cell in cells:
		on_way[Vector2i(cell) / scale] = true
	var out := PackedStringArray()
	for row in range(view.position.y / scale, view.end.y / scale):
		var line := ""
		for column in range(view.position.x / scale, view.end.x / scale):
			var block := Vector2i(column, row)
			line += "*" if on_way.has(block) else _ground_mark(terrain, block * scale)
		out.append(line)
	return out


## The trial's lines: a table of the trips, the ways across and over the stream drawn, and
## how many searches fit the budget.
static func report(repeats: int) -> PackedStringArray:
	var rows := run(repeats)
	var out := PackedStringArray(
		[
			(
				"%-18s %-18s %6s %5s %8s %9s %9s %9s"
				% ["trip", "walker", "cells", "legs", "seconds", "searched", "search us", "find us"]
			)
		]
	)
	for row in rows:
		out.append(
			(
				"%-18s %-18s %6d %5d %8.1f %9d %9d %9d"
				% [
					row["trip"],
					row["walker"],
					row["cells"].size(),
					maxi(0, row["waypoints"].size() - 1),
					row["seconds"],
					row["expanded"],
					row["search_usec"],
					row["find_usec"]
				]
			)
		)
	for row in rows:
		var view: Variant = {"across": FIELD_VIEW, "stream": STREAM_VIEW}.get(row["trip"])
		if view != null:
			out.append("\n%s, %s:" % [row["trip"], row["walker"]])
			out.append_array(drawing(row["cells"], view, 2 if view == FIELD_VIEW else 1))
	out.append_array(_budget(rows))
	return out


static func _budget(rows: Array) -> PackedStringArray:
	var out := PackedStringArray(["\nsearches a %.0f ms budget holds (mean search):" % BUDGET_MS])
	for trip in TRIPS:
		var mean := 0.0
		var trip_rows := rows.filter(func(row): return row["trip"] == trip)
		for row in trip_rows:
			mean += float(row["search_usec"]) / trip_rows.size()
		out.append("  %-18s %7.0f us  %5.1f" % [trip, mean, BUDGET_MS * 1000.0 / maxf(mean, 1.0)])
	return out


static func _timed(
	terrain: FormationTerrain,
	walker: TerrainWalker,
	from: Vector2,
	to: Vector2,
	leash: float,
	repeats: int
) -> Dictionary:
	var start := Vector2i(floori(from.x), floori(from.y))
	var goal := Vector2i(floori(to.x), floori(to.y))
	var began := Time.get_ticks_usec()
	var search: PathSearch
	var cells: Array[Vector2i] = []
	for _repeat in range(repeats):
		search = PathSearch.new(terrain, walker, start, goal, leash)
		cells = search.run()
	var searched := (Time.get_ticks_usec() - began) / maxi(1, repeats)
	began = Time.get_ticks_usec()
	var waypoints := TerrainPaths.find(terrain, walker, from, to, leash)
	return {
		"cells": cells,
		"waypoints": waypoints,
		"expanded": search.expanded,
		"search_usec": searched,
		"find_usec": Time.get_ticks_usec() - began,
	}


static func _unit(name: String) -> UnitDef:
	var unit_def: UnitDef = load(GREM).duplicate()
	if name == "loaded militiaman":
		unit_def = load("res://content/units/kingdom_militia.tres").duplicate()
		var pack := ItemDef.new()
		pack.item_name = "pack"
		pack.weight = PACK_WEIGHT
		var items := unit_def.items.duplicate()
		items.append(pack)
		unit_def.items = items
	elif name == "cart (sinks)":
		unit_def.traits = {"sinks": 1}
	elif name == "climber":
		unit_def.traits = {"climber": 1}
	return unit_def


static func _ground_mark(terrain: FormationTerrain, cell: Vector2i) -> String:
	var centre := Vector2(cell) + Vector2(0.5, 0.5)
	if CRAG.has_point(cell):
		return "#"
	var pace := terrain.factor(1.0, centre, centre)
	if pace <= 0.0:
		return "~"
	if terrain.blocks_sight(centre):
		return "T" if pace >= 0.5 else "="
	if pace < 1.0:
		return "="
	return "^" if terrain.height_at(centre) > 0 else "."
