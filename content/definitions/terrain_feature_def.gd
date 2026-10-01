class_name TerrainFeatureDef
extends Resource
## A natural feature a tile can carry (ore vein, arable land, ...), per
## specs/19-map-layout-and-objectives.md. Its gameplay effect isn't designed yet;
## effect_notes carries the designer's stub description.

@export var id: String = ""
@export var display_name: String = ""
@export var glyph: String = ""
@export_multiline var effect_notes: String = ""
