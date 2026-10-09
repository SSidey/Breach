class_name PlaceOrder
extends RefCounted
## Units front first by their places in a squad's frame (rank, then column), as compact and
## a re-form (FormationShuffle) look through them: sorted on whole-number keys rather than
## by a comparison called for every pair. Two units on one place (which a frame never
## holds) are sorted as a comparison of ranks and columns would sort them, so the order is
## always the same as that sort's. Pure.

## Ranks and columns this far either side of 0 fit a key; any beyond are sorted as pairs.
const LIMIT := 1 << 20


## `units`, front rank first, each rank left to right.
static func front_first(units: Array) -> Array:
	var count := units.size()
	var keys := PackedInt64Array()
	keys.resize(count)
	for index in range(count):
		var unit = units[index]
		if absi(unit.rank) >= LIMIT or absi(unit.column) >= LIMIT:
			return _by_pairs(units)
		var place: int = (unit.rank + LIMIT) * (2 * LIMIT) + unit.column + LIMIT
		keys[index] = place * count + index
	keys.sort()
	var out := []
	out.resize(count)
	for index in range(count):
		out[index] = units[keys[index] % count]
		if index > 0 and keys[index] / count == keys[index - 1] / count:
			return _by_pairs(units)  # one place held twice: as the comparison sorts them
	return out


static func _by_pairs(units: Array) -> Array:
	var out := units.duplicate()
	out.sort_custom(
		func(a, b): return a.rank < b.rank or (a.rank == b.rank and a.column < b.column)
	)
	return out
