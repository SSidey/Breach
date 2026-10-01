class_name WavePresets
extends RefCounted
## Player wave presets, per Decision 43: a lane's shape saved under a name, applied to any
## lane in one step - fitted to that lane's width and the free slots, front-first, with
## whatever no longer fits dropped. Presets are the player's own; the game ships none. The
## only shape built here is a lane's starting wave (a plain line), which isn't a preset.
## Pure: saving and loading the file is the scene's job.

const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

## Presets saved before units had kind names (Decision 43) used these.
const LEGACY_KINDS := {"light": "grem", "heavy": "brute"}


## A lane's starting wave: `count` units of one kind, as wide as allowed, then deeper.
static func line(unit_def: UnitDef, count: int, width: int) -> WaveTemplate:
	var template := WaveTemplate.new(width, count)
	for index in range(count):
		template.paint(unit_def, Vector2i(index / template.max_width, index % template.max_width))
	return template


## {"name", "units": [{"kind", "rank", "column"}]} - plain data, safe to store as JSON.
## kinds: {kind name: UnitDef}, e.g. {"grem": ..., "brute": ..., "spitter": ...}.
static func to_dict(template: WaveTemplate, preset_name: String, kinds: Dictionary) -> Dictionary:
	var units := []
	for placement in template.ordered():
		var kind = kinds.find_key(placement[0])
		if kind != null:
			units.append({"kind": kind, "rank": placement[1].x, "column": placement[1].y})
	return {"name": preset_name, "units": units}


## Builds the preset for a lane `width` wide with `allowance` slots, front-first. Kinds it
## doesn't know are skipped.
static func from_dict(
	preset: Dictionary, kinds: Dictionary, width: int, allowance: int
) -> WaveTemplate:
	var template := WaveTemplate.new(width, allowance)
	for unit in preset.get("units", []):
		var kind: String = LEGACY_KINDS.get(unit.get("kind"), unit.get("kind", ""))
		if kinds.has(kind):
			template.paint(
				kinds[kind], Vector2i(int(unit.get("rank", 0)), int(unit.get("column", 0)))
			)
	return template
