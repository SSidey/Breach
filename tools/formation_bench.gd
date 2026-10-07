extends SceneTree
## How long a tick of the formation fight takes as battles grow (spec 30 round 3): grems
## against kingdom militia, head-on, `n` a side, `width` wide; for each size the ms a tick
## takes marching (before any contact) and mid-fight (after `settle` ticks of contact),
## average and worst. A tick has 100 ms at 10 ticks a second.
##
##   godot --headless --path . --script res://tools/formation_bench.gd -- \
##       [sizes=40,160,512,1024] [width=32] [march=10] [settle=10] [fight=10] [seed=1]

const FormationBench = preload("res://sim/skirmish/formation/formation_bench.gd")


func _init() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var options := {
		"width": int(args.get("width", 32)),
		"march": int(args.get("march", 10)),
		"settle": int(args.get("settle", 10)),
		"fight": int(args.get("fight", 10)),
		"seed": int(args.get("seed", 1)),
	}
	print("width %d, ms a tick (avg / worst)" % options["width"])
	print("%8s  %20s  %20s  %s" % ["a side", "marching", "mid-fight", "contact tick"])
	for size in str(args.get("sizes", "40,160,512,1024")).split(","):
		var result := FormationBench.measure(int(size), options)
		print(
			(
				"%8d  %9.1f / %8.1f  %9.1f / %8.1f  %d"
				% [
					int(size),
					result["march"][0],
					result["march"][1],
					result["fight"][0],
					result["fight"][1],
					result["contact"],
				]
			)
		)
	quit(0)
