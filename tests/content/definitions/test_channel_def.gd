extends GdUnitTestSuite
## ChannelDef, per Decision 59: a river, ditch, moat or bank along a path of tiles, with a
## width and depth in cells and, optionally, a flowing material held to a depth.

const ChannelDef = preload("res://content/definitions/channel_def.gd")
const MaterialDef = preload("res://content/definitions/material_def.gd")
const TerrainLibraryDef = preload("res://content/definitions/terrain_library_def.gd")


func _library() -> TerrainLibraryDef:
	var water := MaterialDef.new()
	water.id = "WATER"
	water.traits = {"flows": 3}
	var rock := MaterialDef.new()
	rock.id = "ROCK"
	var library := TerrainLibraryDef.new()
	library.materials = [water, rock]
	return library


func _river() -> ChannelDef:
	var channel := ChannelDef.new()
	channel.tiles = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1)]
	channel.width = 4
	channel.depth = 3
	channel.liquid_id = "WATER"
	channel.liquid_depth = 2
	return channel


func _any(errors: PackedStringArray, needle: String) -> bool:
	return Array(errors).any(func(m): return m.contains(needle))


func test_a_river_along_neighbouring_tiles_validates() -> void:
	assert_array(Array(_river().validate(3, 2, _library()))).is_empty()


func test_a_tile_off_the_grid_is_an_error() -> void:
	assert_bool(_any(_river().validate(2, 2, _library()), "off the grid")).is_true()


func test_tiles_that_dont_touch_are_an_error() -> void:
	var channel := _river()
	channel.tiles = [Vector2i(0, 0), Vector2i(2, 0)]

	assert_bool(_any(channel.validate(3, 2, _library()), "not neighbours")).is_true()


func test_a_liquid_that_doesnt_flow_is_an_error() -> void:
	var channel := _river()
	channel.liquid_id = "ROCK"

	assert_bool(_any(channel.validate(3, 2, _library()), "'ROCK' doesn't flow")).is_true()


func test_liquid_deeper_than_the_channel_is_an_error() -> void:
	var channel := _river()
	channel.liquid_depth = 4

	assert_bool(_any(channel.validate(3, 2, _library()), "deeper than the channel")).is_true()


func test_a_width_below_one_is_an_error() -> void:
	var channel := _river()
	channel.width = 0

	assert_bool(_any(channel.validate(3, 2, _library()), "width")).is_true()
