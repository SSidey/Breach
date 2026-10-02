extends GdUnitTestSuite
## The formation sim's scale, per Decisions 48 and 68: lengths are in tiles, and a tile is
## 64 cells. A rank is one cell, melee reach a little over one cell, and a speed-1 unit
## covers 8 cells a second - the per-cell speed the user chose to keep when tiles grew.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationSimulation = preload("res://sim/skirmish/formation/formation_simulation.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const CELL := 1.0 / MapLayoutDef.CELLS_PER_TILE


func test_a_rank_is_one_cell() -> void:
	assert_float(SkirmishSquad.RANK_DEPTH).is_equal_approx(CELL, 0.000001)


func test_melee_reach_is_a_little_over_a_cell() -> void:
	assert_float(FormationSimulation.MELEE_REACH / CELL).is_between(1.0, 1.25)


func test_a_speed_one_unit_covers_eight_cells_a_second() -> void:
	assert_float(FormationSimulation.TRAVEL_SCALE / CELL).is_equal_approx(8.0, 0.000001)
