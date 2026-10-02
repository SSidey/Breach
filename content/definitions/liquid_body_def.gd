class_name LiquidBodyDef
extends Resource
## A body of liquid a terrain may hold (Decision 62): the liquid, its depth below the
## surface in cells (a range generation picks from the map's seed), the chance a tile of
## the terrain has one, and the chance it rises in a vent or pool to the surface.

@export var liquid_id: String = ""
@export var min_cells: int = 0
@export var max_cells: int = 0
@export var chance: float = 1.0
@export var surface_chance: float = 0.0
