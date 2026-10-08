class_name PathMemory
extends RefCounted
## What a pathfinder has seen of the ground (spec 30): the cells its plans have looked at
## within its sight, kept between plans, so a wall it has felt along stays known when it
## turns its back on it and it doesn't walk back to look again. A plan counts a known cell
## as seen (at its real cost, read live from the terrain). One per squad, forgotten once
## the squad is back on its route (a detour that worked is kept as a RoutePatch). Pure.

var _known := PackedByteArray()


## Whether it has seen the cell at `index` of a grid of `count` cells.
func knows(index: int, count: int) -> bool:
	if _known.size() != count:
		return false
	return _known[index] == 1


## Forgets all it has seen: its group is back on its route.
func forget() -> void:
	_known = PackedByteArray()


## Remembers seeing the cell at `index` of a grid of `count` cells.
func learn(index: int, count: int) -> void:
	if _known.size() != count:
		_known.resize(count)
		_known.fill(0)
	_known[index] = 1
