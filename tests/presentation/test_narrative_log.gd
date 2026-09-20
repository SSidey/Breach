extends GdUnitTestSuite

const NarrativeLog = preload("res://presentation/narrative_log.gd")
const SuspicionSystem = preload("res://sim/suspicion_system.gd")


func _has_digit(text: String) -> bool:
	for character in text:
		if character.is_valid_int():
			return true
	return false


func test_calm_tier_produces_no_message() -> void:
	var message := NarrativeLog.message_for_tier(SuspicionSystem.Tier.CALM)

	assert_str(message).is_empty()


func test_mobilized_tier_warns_about_a_hero_party() -> void:
	var message := NarrativeLog.message_for_tier(SuspicionSystem.Tier.MOBILIZED)

	assert_str(message).contains("Hero Party")


func test_wary_and_alarmed_tiers_produce_a_non_empty_message() -> void:
	assert_str(NarrativeLog.message_for_tier(SuspicionSystem.Tier.WARY)).is_not_empty()
	assert_str(NarrativeLog.message_for_tier(SuspicionSystem.Tier.ALARMED)).is_not_empty()


func test_no_tier_message_contains_a_raw_number() -> void:
	# Decision 8: the exact suspicion meter stays hidden without a Scout - the log
	# gives narrative signal, never the number.
	var tiers := [
		SuspicionSystem.Tier.WARY,
		SuspicionSystem.Tier.ALARMED,
		SuspicionSystem.Tier.MOBILIZED,
		SuspicionSystem.Tier.FULL_ALERT,
	]
	for tier in tiers:
		var message: String = NarrativeLog.message_for_tier(tier)
		assert_bool(_has_digit(message)).is_false()
