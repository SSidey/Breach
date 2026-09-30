extends GdUnitTestSuite
## MapArtSet, per specs/18-map-viewer.md: the replaceable art behind the map viewer.

const MapArtSet = preload("res://presentation/map_art_set.gd")
const NodeDef = preload("res://content/definitions/node_def.gd")

const DEFAULT_ART_SET := "res://assets/placeholder/map/map_art_set.tres"


func test_a_fresh_art_set_has_no_textures_so_the_view_draws_shapes() -> void:
	var art := MapArtSet.new()

	for node_type in NodeDef.NodeType.values():
		assert_object(art.texture_for(node_type)).is_null()


func test_the_committed_placeholder_art_covers_every_node_type() -> void:
	var art: MapArtSet = load(DEFAULT_ART_SET)

	assert_object(art).is_not_null()
	for node_type in NodeDef.NodeType.values():
		assert_object(art.texture_for(node_type)).is_not_null()
	assert_object(art.hidden_badge).is_not_null()
	assert_object(art.critical_badge).is_not_null()
	assert_bool(art.faction_palette.is_empty()).is_false()
