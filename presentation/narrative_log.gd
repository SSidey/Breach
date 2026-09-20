class_name NarrativeLog
extends RefCounted
## Pure mapping from a suspicion tier to a log line, per
## specs/05-presentation-and-hud.md and Decision 8: narrative signal only, never the
## raw meter (no Scout exists yet to justify showing it). Calm produces no message -
## the caller skips appending an empty string rather than logging "nothing happened."


static func message_for_tier(tier: int) -> String:
	match tier:
		SuspicionSystem.Tier.WARY:
			return "Something feels off nearby."
		SuspicionSystem.Tier.ALARMED:
			return "The defenders are on alert."
		SuspicionSystem.Tier.MOBILIZED:
			return "A Hero Party is marching toward the fighting."
		SuspicionSystem.Tier.FULL_ALERT:
			return "The defenders are fully mobilized."
		_:
			return ""
