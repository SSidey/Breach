class_name StratumDef
extends Resource
## One band of a terrain's strata (Decision 54): a material and how thick it is, in
## cells. Bands run down from the surface in order; strata generation picks a thickness
## per band from the map's seed, and the last band continues down to the dig depth.

@export var material_id: String = ""
@export var min_cells: int = 1
@export var max_cells: int = 1
