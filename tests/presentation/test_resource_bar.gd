extends GdUnitTestSuite
## ResourceBar's actual rendering has no automated coverage - same honesty as
## LaneView (specs/05's Notes): it needs a real render context, deferred to manual
## playtest once a running scene exists (item 11). This is a construction smoke test
## only.

const ResourceBar = preload("res://presentation/resource_bar.gd")


func test_constructs_without_error() -> void:
	var bar: ResourceBar = auto_free(ResourceBar.new())

	assert_object(bar).is_not_null()
