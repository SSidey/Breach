extends SceneTree
## Monte Carlo trials of the formation fight (Decision 93, BattleTrials): each scenario
## fought once per battle seed, reporting how often each side wins and the spread of its
## losses (mean ± sd, min to max) - for judging a rule or a tuning value.
##
##   godot --headless --path . --script res://tools/formation_trials.gd -- \
##       [scenario=all|<name>] [runs=50] [rolls=off] [captain] \
##       [first_seed=1] [swap]
##
## Scenarios: mirror_headon, mirror_flank, field_a, field_b, field_b_waits, field_together;
## fatigue (FatigueTrials): how far a line pursues after 3, 30, 60 and 90 s of contact;
## and paths (PathTrials, spec 30 round 3): ways over the field for four walkers, drawn
## and timed, each search the mean of `repeats` (default 20).

const BattleTrials = preload("res://sim/skirmish/formation/battle_trials.gd")
const FatigueTrials = preload("res://sim/skirmish/formation/fatigue_trials.gd")
const PathTrials = preload("res://sim/skirmish/formation/path_trials.gd")


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
	if scenario == "paths":
		print("\n".join(PathTrials.report(int(args.get("repeats", 20)))))
		quit(0)
		return
	if scenario == "fatigue":
		_fatigue(int(args.get("runs", 50)), int(args.get("first_seed", 1)))
		quit(0)
		return
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


func _fatigue(runs: int, first_seed: int) -> void:
	print(
		"%-10s %-10s %-16s %-12s %s" % ["contact", "stamina", "pursued (cells)", "ticks", "tired"]
	)
	for seconds in [3.0, 30.0, 60.0, 90.0]:
		var result := FatigueTrials.run(seconds, runs, first_seed)
		print(
			(
				"%-10s %-10s %-16s %-12s %d / %d"
				% [
					"%d s" % seconds,
					"%d%%" % roundi(result["stamina"] * 100),
					"%.1f" % result["pursued"],
					"%.1f" % result["ticks"],
					result["tired"],
					runs
				]
			)
		)
