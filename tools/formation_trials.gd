extends SceneTree
## Monte Carlo trials of the formation fight (Decision 93, BattleTrials): each scenario
## fought once per battle seed, reporting how often each side wins and the spread of its
## losses (mean ± sd, min to max) - for judging a rule or a tuning value.
##
##   godot --headless --path . --script res://tools/formation_trials.gd -- \
##       [scenario=all|<name>] [runs=50] [rolls=off] [captain] \
##       [first_seed=1] [swap]
##
## Scenarios: mirror_headon, mirror_flank, field_a, field_b, field_b_waits, field_together.

const BattleTrials = preload("res://sim/skirmish/formation/battle_trials.gd")


func _init() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var options := {
		"captain": args.has("captain"),
		"swap": args.has("swap"),
		"first_seed": int(args.get("first_seed", 1)),
		"rolls": args.get("rolls", "on") != "off",
	}
	var scenario: String = args.get("scenario", "all")
	var names: Array = BattleTrials.SCENARIOS if scenario == "all" else [scenario]
	print("runs %s, options %s" % [args.get("runs", "50"), options])
	print(
		(
			"%-16s %-22s %-24s %-24s %s"
			% ["scenario", "wins (player/kingdom)", "player lost", "kingdom lost", "ticks"]
		)
	)
	for name in names:
		var results := BattleTrials.run(name, int(args.get("runs", 50)), options)
		print(_row(name, BattleTrials.summary(results)))
	quit(0)


func _row(name: String, summary: Dictionary) -> String:
	var wins: Dictionary = summary["wins"]
	return (
		"%-16s %-22s %-24s %-24s %.0f"
		% [
			name,
			"%d / %d (%d none)" % [wins["player"], wins["the_kingdom"], wins[""]],
			_spread(summary["lost"]["player"]),
			_spread(summary["lost"]["the_kingdom"]),
			summary["ticks"],
		]
	)


func _spread(values: Array) -> String:
	return "%.1f ± %.1f (%d-%d)" % [values[0], values[1], values[2], values[3]]
