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

## Two keys an entry: the estimate and its distance aside; its nearness to the goal and its
## cell's index (which the entry gives back).
var _first := PackedInt64Array()
var _second := PackedInt64Array()


func is_empty() -> bool:
	return _first.is_empty()


## Adds `cell` (an index on the grid) with its estimated time `estimate` of a way through
## it, its distance `aside` from the straight way and `remaining` to the goal.
func push(cell: int, estimate: float, aside: float, remaining: float) -> void:
	var first := roundi(estimate * GRAIN) * ASIDE_ROOM + mini(roundi(aside * GRAIN), ASIDE_ROOM - 1)
	var second := roundi(remaining * GRAIN) * CELL_ROOM + cell
	var at := _first.size()
	_first.append(first)
	_second.append(second)
	while at > 0:  # sift the hole up past every entry after it
		var up := (at - 1) >> 1
		if _first[up] < first or (_first[up] == first and _second[up] < second):
			break
		_first[at] = _first[up]
		_second[at] = _second[up]
		at = up
	_first[at] = first
	_second[at] = second


## Takes the most promising cell off the heap.
func pop() -> int:
	var top := _second[0] % CELL_ROOM
	var last := _first.size() - 1
	var first := _first[last]
	var second := _second[last]
	_first.resize(last)
	_second.resize(last)
	if last == 0:
		return top
	var at := 0
	while true:  # sift the hole down past every entry before the last
		var child := 2 * at + 1
		if child >= last:
			break
		if child + 1 < last and _before(child + 1, child):
			child += 1
		if first < _first[child] or (first == _first[child] and second < _second[child]):
			break
		_first[at] = _first[child]
		_second[at] = _second[child]
		at = child
	_first[at] = first
	_second[at] = second
	return top


func _before(one: int, other: int) -> bool:
	if _first[one] != _first[other]:
		return _first[one] < _first[other]
	return _second[one] < _second[other]
