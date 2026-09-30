extends GdUnitTestSuite
## WavePresets, per Decision 43: presets are the player's own - a lane's shape saved under
## a name and applied to any lane, fitted to its width and the free slots. The only shape
## built in is a lane's starting line, which isn't offered as a preset.

const WavePresets = preload("res://sim/skirmish/formation/wave_presets.gd")
const WaveTemplate = preload("res://sim/skirmish/formation/wave_template.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

var _grem: UnitDef
var _brute: UnitDef


func before_test() -> void:
	_grem = _def(1, 1)
	_brute = _def(2, 2)


func _def(depth: int, width: int) -> UnitDef:
	var unit_def := UnitDef.new()
	unit_def.hp = 10
	unit_def.footprint_depth = depth
	unit_def.footprint_width = width
	return unit_def


func _places(template: WaveTemplate) -> Array:
	return template.ordered().map(func(p): return [p[0] == _brute, p[1]])


func _hook() -> WaveTemplate:
	var template := WaveTemplate.new(5, 8)
	template.paint(_brute, Vector2i(0, 1))
	template.paint(_grem, Vector2i(2, 1))
	template.paint(_grem, Vector2i(2, 4))
	return template


func test_the_starting_line_is_as_wide_as_allowed_then_deeper() -> void:
	assert_int(WavePresets.line(_grem, 7, 5).ordered().size()).is_equal(7)


func test_a_saved_preset_keeps_its_name_and_shape() -> void:
	var saved := WavePresets.to_dict(_hook(), "Hook", _grem)
	var applied := WavePresets.from_dict(saved, _grem, _brute, 5, 8)

	assert_str(saved["name"]).is_equal("Hook")
	assert_array(_places(applied)).is_equal(_places(_hook()))


func test_a_preset_survives_json() -> void:
	var saved := WavePresets.to_dict(_hook(), "Hook", _grem)
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(saved))

	assert_array(_places(WavePresets.from_dict(reloaded, _grem, _brute, 5, 8))).is_equal(
		_places(_hook())
	)


func test_applying_to_a_narrower_lane_drops_what_no_longer_fits() -> void:
	var saved := WavePresets.to_dict(_hook(), "Hook", _grem)

	var narrow := WavePresets.from_dict(saved, _grem, _brute, 3, 8)

	assert_int(narrow.ordered().size()).is_equal(2)  # the grem at column 4 is dropped


func test_applying_with_fewer_free_slots_keeps_the_front_first() -> void:
	var saved := WavePresets.to_dict(_hook(), "Hook", _grem)

	var tight := WavePresets.from_dict(saved, _grem, _brute, 5, 5)

	assert_array(_places(tight)).is_equal([[true, Vector2i(0, 1)], [false, Vector2i(2, 1)]])
