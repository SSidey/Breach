extends SceneTree
## The native spike's benchmark (native/README.md): a mid-fight tick of FormationBench's
## clash under each engine of UnitBodies' body-parting pass (NativeKernels), and the pass
## alone - for a native kernel split into gathering the packed arrays, the call (the
## boundary both ways plus the kernel), the kernel's own work (what it would cost were the
## data already native) and writing back. Each run times `fight` ticks after `settle`
## ticks of contact; a line per run, then min / median over the runs. Engines not built
## are skipped. ms a tick throughout.
##
##   godot --headless --path . --script res://tools/native_bench.gd -- \
##       [engines=gdscript,rust,cpp,rust_threads] [sizes=160:10,512:32,1024:32] [runs=3]
##       [settle=10] [fight=10] [seed=1]

const FormationBench = preload("res://sim/skirmish/formation/formation_bench.gd")
const NativeKernels = preload("res://sim/skirmish/formation/native_kernels.gd")
const UnitBodies = preload("res://sim/skirmish/formation/unit_bodies.gd")
const BodyParting = preload("res://sim/skirmish/formation/body_parting.gd")

const COLUMNS := ["tick", "pass", "gather", "call", "kernel", "write"]


func _init() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var engines := str(args.get("engines", "gdscript,rust,cpp,rust_threads")).split(",")
	var sizes := str(args.get("sizes", "160:10,512:32,1024:32")).split(",")
	var runs := int(args.get("runs", 3))
	var options := {
		"settle": int(args.get("settle", 10)),
		"fight": int(args.get("fight", 10)),
		"seed": int(args.get("seed", 1))
	}
	print("%-17s %5s %3s  %s" % ["engine", "side", "w", "  ".join(COLUMNS)])
	for size in sizes:
		var parts := size.split(":")
		for engine in engines:
			var kernel_engine := engine.trim_suffix("_threads")
			if not NativeKernels.available(kernel_engine):
				continue
			NativeKernels.use(kernel_engine)
			NativeKernels.threaded = engine.ends_with("_threads")
			var results := []
			for run in range(runs):
				results.append(_measure(int(parts[0]), int(parts[1]), options))
				print(_line("%s #%d" % [engine, run + 1], parts, results.back()))
			print(_line(engine + " min", parts, _pick(results, 0.0)))
			print(_line(engine + " med", parts, _pick(results, 0.5)))
	quit(0)


## Average ms a tick of each column over `fight` ticks mid-fight.
func _measure(per_side: int, width: int, options: Dictionary) -> Array:
	var sim := FormationBench.clash(per_side, width, options["seed"])
	var contact := false
	while not contact and sim.tick_number() < FormationBench.CONTACT_LIMIT:
		contact = sim.step().any(func(e): return e["type"] == "engaged")
	for _i in range(options["settle"]):
		sim.step()
	UnitBodies.clock_usec = 0
	BodyParting.spent = PackedInt64Array([0, 0, 0, 0])
	var began := Time.get_ticks_usec()
	for _i in range(options["fight"]):
		sim.step()
	var ticks := float(options["fight"]) * 1000.0
	var out := [(Time.get_ticks_usec() - began) / ticks, UnitBodies.clock_usec / ticks]
	for spent in BodyParting.spent:
		out.append(spent / ticks)
	return out


## Each column's value at quantile `at` (0: min, 0.5: median) across the runs.
func _pick(results: Array, at: float) -> Array:
	var out := []
	for column in range(COLUMNS.size()):
		var values := results.map(func(r): return r[column])
		values.sort()
		out.append(values[int(at * (values.size() - 1) + 0.5)])
	return out


func _line(label: String, size: PackedStringArray, values: Array) -> String:
	var cells := values.map(func(v): return "%6.2f" % v)
	return "%-17s %5s %3s  %s" % [label, size[0], size[1], "  ".join(cells)]
