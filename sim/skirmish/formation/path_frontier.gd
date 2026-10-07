class_name PathFrontier
extends RefCounted
## The open cells of a path search (PathSearch), the most promising first: a binary heap
## ordered by the estimated time of a way through the cell, then by how far the cell lies
## aside from the straight way, then by how near it is to the goal, then by its place on
## the grid (row, then column). Geometry decides every tie, never the order the cells were
## found in (Decision 97). Each measure is rounded to a thousandth, so float noise in sums
## taken in different orders can't pre-empt the geometry. Pure.

## A thousandth: what each measure is rounded to.
const GRAIN := 1000.0
## Room for the second measure (aside, in thousandths) under the first, and for the cell's
## index under the third.
const ASIDE_ROOM := 1 << 24
const CELL_ROOM := 1 << 24

var _cells := PackedInt32Array()
## Two keys a cell: the estimate and its distance aside; its nearness to the goal and its
## index.
var _first := PackedInt64Array()
var _second := PackedInt64Array()


func is_empty() -> bool:
	return _cells.is_empty()


## Adds `cell` (an index on the grid) with its estimated time `estimate` of a way through
## it, its distance `aside` from the straight way and `remaining` to the goal.
func push(cell: int, estimate: float, aside: float, remaining: float) -> void:
	_cells.append(cell)
	_first.append(
		roundi(estimate * GRAIN) * ASIDE_ROOM + mini(roundi(aside * GRAIN), ASIDE_ROOM - 1)
	)
	_second.append(roundi(remaining * GRAIN) * CELL_ROOM + cell)
	var at := _cells.size() - 1
	while at > 0:
		var up := (at - 1) >> 1
		if not _before(at, up):
			break
		_swap(at, up)
		at = up


## Takes the most promising cell off the heap.
func pop() -> int:
	var top := _cells[0]
	var last := _cells.size() - 1
	_swap(0, last)
	_cells.resize(last)
	_first.resize(last)
	_second.resize(last)
	var at := 0
	while true:
		var best := at
		for child in [2 * at + 1, 2 * at + 2]:
			if child < last and _before(child, best):
				best = child
		if best == at:
			break
		_swap(at, best)
		at = best
	return top


func _before(one: int, other: int) -> bool:
	if _first[one] != _first[other]:
		return _first[one] < _first[other]
	return _second[one] < _second[other]


func _swap(one: int, other: int) -> void:
	var cell := _cells[one]
	_cells[one] = _cells[other]
	_cells[other] = cell
	var key := _first[one]
	_first[one] = _first[other]
	_first[other] = key
	key = _second[one]
	_second[one] = _second[other]
	_second[other] = key
