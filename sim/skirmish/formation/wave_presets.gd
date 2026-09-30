class_name WavePresets
extends RefCounted
## Player wave presets, per Decision 43: a lane's shape saved under a name, applied to any
## lane in one step - fitted to that lane's width and the free slots, front-first, with
## whatever no longer fits dropped. Presets are the player's own; the game ships none. The
## only shape built here is a lane's starting wave (a plain line), which isn't a preset.
## Pure: saving and loading the file is the scene's job.

const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")


## A lane's starting wave: `count` units of one kind, as wide as allowed, then deeper.
static func line(unit_def: UnitDef, count: int, width: int) -> WaveTemplate:
	var template := WaveTemplate.new(width, count)
	for index in range(count):
		template.paint(unit_def, Vector2i(index / template.max_width, index % template.max_width))
	return template


## {"name", "units": [{"kind", "rank", "column"}]} - plain data, safe to store as JSON.
## Units other than `light` are stored as heavy.
static func to_dict(template: WaveTemplate, preset_name: String, light: UnitDef) -> Dictionary:
	var units := []
	for placement in template.ordered():
		var kind := "light" if placement[0] == light else "heavy"
		units.append({"kind": kind, "rank": placement[1].x, "column": placement[1].y})
	return {"name": preset_name, "units": units}


## Builds the preset for a lane `width` wide with `allowance` slots, front-first.
static func from_dict(
	preset: Dictionary, light: UnitDef, heavy: UnitDef, width: int, allowance: int
) -> WaveTemplate:
	var template := WaveTemplate.new(width, allowance)
	for unit in preset.get("units", []):
		var unit_def := heavy if unit.get("kind") == "heavy" else light
		template.paint(unit_def, Vector2i(int(unit.get("rank", 0)), int(unit.get("column", 0))))
	return template
