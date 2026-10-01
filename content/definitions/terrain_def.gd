class_name TerrainDef
extends Resource
## One terrain type in the shared terrain library, per
## specs/19-map-layout-and-objectives.md (Decision 32). Imported from the designer's
## content/designer/terrain.json; maps reference terrains by id.

@export var id: String = ""
@export var display_name: String = ""
## Short symbol the designer draws on the cell.
@export var glyph: String = ""
@export var color: Color = Color.WHITE
## Can be a map's base (default) terrain.
@export var can_be_base: bool = true
## Impassable without a bridge (water, ravine).
@export var needs_bridge: bool = false
## Movement cost to enter a cell of this terrain (a road multiplies it).
@export var move_cost: float = 1.0
## Unit classes that cannot enter this terrain (no unit-class schema yet; ids only).
@export var blocks_unit_classes: Array[String] = []
## Building capacity defaults for a tile on this terrain (TileDef can override them).
@export var default_stability: int = 0
@export var default_max_height: int = 0
@export var default_max_width: int = 0
@export var default_max_length: int = 0
@export var default_max_depth: int = 0
