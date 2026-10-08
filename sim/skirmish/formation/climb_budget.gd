class_name ClimbBudget
extends RefCounted
## A path search's reckoning of climbing stamina (spec 30, ClimbStamina): for each cell
## reached, the stamina spent since the last cell the walker could stand on, along the way
## it was reached by. A step that would take a stretch past the walker's stamina is not
## planned; reaching a standable cell ends the stretch (stamina recovers there). Each cell
## keeps the spend of its quickest way - a slower way with less spend isn't kept - which is
## enough where climbs are short stretches between ledges. Pure.

const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const TerrainWalker = preload("res://sim/skirmish/formation/terrain_walker.gd")
const ClimbStamina = preload("res://sim/skirmish/formation/climb_stamina.gd")
const ModeStamina = preload("res://sim/skirmish/formation/mode_stamina.gd")

const NOT_YET := 0
const STANDS := 1
const FACE := 2

var _terrain: FormationTerrain
var _walker: TerrainWalker
var _width: int
var _spent := PackedFloat32Array()  # since the last standable cell, on arriving
var _stands := PackedByteArray()


## The stamina spent on the stretch after stepping from cell `from` into `to` (indexes),
## `seen` or taken as open ground; INF past the walker's stamina.
func after(from: int, to: int, seen: bool) -> float:
	var spent := 0.0 if _standable(from) else _spent[from]
	if seen:
		spent += ModeStamina.step_cost(_terrain, _walker, _centre(from), _centre(to), _walker.speed)
	return INF if spent > _walker.stamina else spent


## Keeps `spent` as the stretch's spend on reaching cell `index`.
func keep(index: int, spent: float) -> void:
	_spent[index] = spent


func _standable(index: int) -> bool:
	if _stands[index] == NOT_YET:
		var stands := ClimbStamina.standable(_terrain, _walker, _centre(index))
		_stands[index] = STANDS if stands else FACE
	return _stands[index] == STANDS


func _centre(index: int) -> Vector2:
	return Vector2(index % _width, index / _width) + Vector2(0.5, 0.5)


func _init(terrain: FormationTerrain, walker: TerrainWalker) -> void:
	_terrain = terrain
	_walker = walker
	_width = terrain.size.x
	_spent.resize(terrain.size.x * terrain.size.y)
	_stands.resize(terrain.size.x * terrain.size.y)
