extends GdUnitTestSuite

const WaveCommandPanel = preload("res://presentation/wave_command_panel.gd")


func test_constructs_without_error() -> void:
	var panel: WaveCommandPanel = auto_free(WaveCommandPanel.new())

	assert_object(panel).is_not_null()


func test_unfilled_command_shows_a_waiting_status() -> void:
	var panel: WaveCommandPanel = auto_free(WaveCommandPanel.new())

	assert_str(panel.status_text(false)).is_equal("Waiting for more units")


func test_filled_command_shows_a_ready_status() -> void:
	var panel: WaveCommandPanel = auto_free(WaveCommandPanel.new())

	assert_str(panel.status_text(true)).is_equal("Ready to commit")
