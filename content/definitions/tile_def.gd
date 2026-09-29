class_name TileDef
extends Resource
## One explicitly authored grid cell, per specs/19-map-layout-and-objectives.md. Cells
## with no TileDef are plain default terrain. Terrain and feature are ids into the
## map's shared TerrainLibraryDef.

const BridgeDef = preload("res://content/definitions/bridge_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")

## Capacity override meaning "use the terrain's default".
const DEFAULT := -1
const CAPACITY_FIELDS := ["stability", "max_height", "max_width", "max_depth"]

## (col, row) in the designer grid.
@export var cell: Vector2i = Vector2i.ZERO
## "" = the map's default terrain.
@export var terrain_id: String = ""
@export var feature_id: String = ""
@export var bridge: BridgeDef
@export var stability: int = DEFAULT
@export var max_height: int = DEFAULT
@export var max_width: int = DEFAULT
@export var max_depth: int = DEFAULT
@export var upgrade_slots: int = 0
## Upgrade ids (no upgrade library schema yet).
@export var upgrade_ids: Array[String] = []


## {stability, max_height, max_width, max_length, max_depth}: overrides where set,
## otherwise the terrain's defaults (max_length has no override and follows the terrain).
func effective_capacity(library: TerrainLibraryDef, default_terrain_id: String) -> Dictionary:
	var terrain = library.terrain(terrain_id if terrain_id else default_terrain_id)
	var capacity := {
		"stability": terrain.default_stability if terrain else 0,
		"max_height": terrain.default_max_height if terrain else 0,
		"max_width": terrain.default_max_width if terrain else 0,
		"max_length": terrain.default_max_length if terrain else 0,
		"max_depth": terrain.default_max_depth if terrain else 0,
	}
	for field in CAPACITY_FIELDS:
		if get(field) != DEFAULT:
			capacity[field] = get(field)
	return capacity


## Checks that don't need the rest of the layout (MapLayoutDef checks the grid and library).
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for field in CAPACITY_FIELDS:
		if get(field) < DEFAULT:
			errors.append(
				(
					"tile %s: %s must be -1 (terrain default) or >= 0, got %d"
					% [cell, field, get(field)]
				)
			)
	if upgrade_ids.size() > upgrade_slots:
		errors.append(
			(
				"tile %s: %d upgrades exceed %d slot%s"
				% [cell, upgrade_ids.size(), upgrade_slots, "" if upgrade_slots == 1 else "s"]
			)
		)
	return errors
