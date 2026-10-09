extends GdUnitTestSuite
## Units front first by place (PlaceOrder): the order a comparison of ranks then columns
## sorts them into, a place held twice included.

const PlaceOrder = preload("res://sim/skirmish/formation/place_order.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")


func _units(places: Array) -> Array:
	var out := []
	for index in range(places.size()):
		var unit := SkirmishUnit.new()
		unit.id = index + 1
		unit.rank = places[index].x
		unit.column = places[index].y
		out.append(unit)
	return out


func _compared(units: Array) -> Array:
	var out := units.duplicate()
	out.sort_custom(
		func(a, b): return a.rank < b.rank or (a.rank == b.rank and a.column < b.column)
	)
	return out


func test_front_rank_first_and_each_rank_left_to_right() -> void:
	var units := _units([Vector2i(2, 0), Vector2i(0, 3), Vector2i(1, -2), Vector2i(0, -1)])

	var ordered := PlaceOrder.front_first(units)

	assert_array(ordered.map(func(u): return u.id)).contains_exactly([4, 2, 3, 1])


func test_many_places_sort_as_the_comparison_does() -> void:
	var places := []
	for rank in range(40):
		for column in range(-8, 24):
			places.append(Vector2i(rank, column))
	seed(5)
	places.shuffle()
	var units := _units(places)

	assert_array(PlaceOrder.front_first(units)).is_equal(_compared(units))


func test_a_place_held_twice_sorts_as_the_comparison_does() -> void:
	var units := _units([Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 2)])

	assert_array(PlaceOrder.front_first(units)).is_equal(_compared(units))
