class_name TerrainLibraryDef
extends Resource
## The one shared terrain library (Decision 32, specs/19-map-layout-and-objectives.md):
## content/terrain/terrain_library.tres, generated from the designer's
## content/designer/terrain.json. Every map's MapLayoutDef references this resource
## rather than copying it, so a terrain edit reaches every map without re-saving them.

const TerrainDef = preload("res://content/definitions/terrain_def.gd")
const TerrainFeatureDef = preload("res://content/definitions/terrain_feature_def.gd")
const MaterialDef = preload("res://content/definitions/material_def.gd")
const LiquidDef = preload("res://content/definitions/liquid_def.gd")

@export var terrains: Array[TerrainDef] = []
@export var features: Array[TerrainFeatureDef] = []
## What strata (and later walls) are made of (Decisions 54, 57).
@export var materials: Array[MaterialDef] = []
## Water, lava (Decision 62).
@export var liquids: Array[LiquidDef] = []
## Multiplies a terrain's move_cost on a cell with a road.
@export var road_move_multiplier: float = 0.5
## sha256 of the terrain.json this was imported from; the designer's server compares it
## with the current file to know whether the library needs re-importing.
@export var source_hash: String = ""


func terrain(terrain_id: String) -> TerrainDef:
	for entry in terrains:
		if entry.id == terrain_id:
			return entry
	return null


func material(material_id: String) -> MaterialDef:
	for entry in materials:
		if entry.id == material_id:
			return entry
	return null


func liquid(liquid_id: String) -> LiquidDef:
	for entry in liquids:
		if entry.id == liquid_id:
			return entry
	return null


func feature(feature_id: String) -> TerrainFeatureDef:
	for entry in features:
		if entry.id == feature_id:
			return entry
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	errors.append_array(_validate_ids(terrains, "terrain"))
	errors.append_array(_validate_ids(features, "feature"))
	errors.append_array(_validate_ids(materials, "material"))
	errors.append_array(_validate_ids(liquids, "liquid"))
	for entry in _substances():
		errors.append_array(_validate_transitions(entry))
	if not terrains.any(func(t): return t.can_be_base):
		errors.append("at least one terrain must have can_be_base, so a map has a base terrain")
	for entry in terrains:
		if entry.move_cost < 0.0:
			errors.append(
				"terrain '%s': move_cost must be >= 0, got %f" % [entry.id, entry.move_cost]
			)
		errors.append_array(_validate_ground(entry))
	if road_move_multiplier < 0.0:
		errors.append("road_move_multiplier must be >= 0, got %f" % road_move_multiplier)
	return errors


func _validate_ground(entry: TerrainDef) -> PackedStringArray:
	var errors := PackedStringArray()
	var at := "terrain '%s': " % entry.id
	if entry.foundation_max < entry.bearing:
		errors.append(at + "foundation_max %d < bearing %d" % [entry.foundation_max, entry.bearing])
	for body in entry.liquids:
		if liquid(body.liquid_id) == null:
			errors.append(at + "body of unknown liquid '%s'" % body.liquid_id)
		if body.min_cells < 0 or body.min_cells > body.max_cells:
			errors.append(at + "liquid '%s': depth min > max" % body.liquid_id)
		if not (_is_chance(body.chance) and _is_chance(body.surface_chance)):
			errors.append(at + "liquid '%s': chance must be 0 to 1" % body.liquid_id)
	for stratum in entry.strata:
		if material(stratum.material_id) == null:
			errors.append(at + "stratum of unknown material '%s'" % stratum.material_id)
		if stratum.min_cells < 0 or stratum.min_cells > stratum.max_cells:
			errors.append(
				(
					at
					+ (
						"stratum '%s': min_cells %d > max_cells %d"
						% [stratum.material_id, stratum.min_cells, stratum.max_cells]
					)
				)
			)
	return errors


func _validate_transitions(entry) -> PackedStringArray:
	var errors := PackedStringArray()
	for transition in entry.heat_transitions:
		var at := "'%s' %s" % [entry.id, transition.describe()]
		if transition.becomes.is_empty() and transition.gains_trait.is_empty():
			errors.append(at + ": becomes nothing and gains no trait")
		elif (
			transition.becomes and not (material(transition.becomes) or liquid(transition.becomes))
		):
			errors.append(at + ": becomes unknown '%s'" % transition.becomes)
	return errors


## Materials and liquids together: what can change into what (Decision 63).
func _substances() -> Array:
	var out := []
	out.append_array(materials)
	out.append_array(liquids)
	return out


static func _is_chance(value: float) -> bool:
	return value >= 0.0 and value <= 1.0


static func _validate_ids(entries: Array, kind: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for entry in entries:
		if entry.id.is_empty():
			errors.append("%s id must not be empty" % kind)
		elif seen.has(entry.id):
			errors.append("duplicate %s id '%s'" % [kind, entry.id])
		seen[entry.id] = true
	return errors
