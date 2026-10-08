extends SceneTree
## Where a mid-fight tick's time goes, phase by phase (Decision 129: what to port next): a
## FormationBench clash stepped through FormationSimulation.step's phases in its order, the
## scrum's (FormationScrum.step) split out, each timed; ms a tick, largest first. It
## mirrors step(), so it checks itself: the battle it plays must end tick for tick where a
## plain step() leaves it, or it says so.
##
##   godot --headless --path . --script res://tools/tick_phases.gd -- \
##       [engine=gdscript|rust] [side=1024] [width=32] [settle=10] [fight=5] [seed=1]

const FormationBench = preload("res://sim/skirmish/formation/formation_bench.gd")
const NativeKernels = preload("res://sim/skirmish/formation/native_kernels.gd")
const Sim = preload("res://sim/skirmish/formation/formation_simulation.gd")
const Scrum = preload("res://sim/skirmish/formation/formation_scrum.gd")
const ScrumEngage = preload("res://sim/skirmish/formation/scrum_engage.gd")
const ScrumStance = preload("res://sim/skirmish/formation/scrum_stance.gd")
const ScrumSeek = preload("res://sim/skirmish/formation/scrum_seek.gd")
const ScrumRegroup = preload("res://sim/skirmish/formation/scrum_regroup.gd")
const ScrumPursuit = preload("res://sim/skirmish/formation/scrum_pursuit.gd")
const FormationManoeuvre = preload("res://sim/skirmish/formation/formation_manoeuvre.gd")
const FormationWithdraw = preload("res://sim/skirmish/formation/formation_withdraw.gd")
const FormationPursuit = preload("res://sim/skirmish/formation/formation_pursuit.gd")
const GroundBodies = preload("res://sim/skirmish/formation/ground_bodies.gd")
const BodyGrid = preload("res://sim/skirmish/formation/body_grid.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")

var _spent := {}
var _last := 0


func _init() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	NativeKernels.use(str(args.get("engine", "gdscript")))
	var side := int(args.get("side", 1024))
	var width := int(args.get("width", 32))
	var fight := int(args.get("fight", 5))
	var timed := _settled(side, width, args)
	var plain := _settled(side, width, args)
	for _i in range(fight):
		_step(timed)
		plain.step()
	var total: float = _spent.values().reduce(func(a, b): return a + b, 0)
	var heading := "%s, %d a side, %d wide: %.1f ms a tick"
	print(heading % [NativeKernels.engine(), side, width, total / fight / 1000.0])
	var names := _spent.keys()
	names.sort_custom(func(a, b): return _spent[a] > _spent[b])
	for phase in names:
		print("  %-32s %8.2f" % [phase, _spent[phase] / float(fight) / 1000.0])
	if _state(timed) != _state(plain):
		print("WARNING: tick_phases no longer mirrors FormationSimulation.step - fix it")
	quit(0)


func _settled(side: int, width: int, args: Dictionary) -> Sim:
	var sim := FormationBench.clash(side, width, int(args.get("seed", 1)))
	var contact := false
	while not contact and sim.tick_number() < FormationBench.CONTACT_LIMIT:
		contact = sim.step().any(func(e): return e["type"] == "engaged")
	for _i in range(int(args.get("settle", 10))):
		sim.step()
	return sim


func _state(sim: Sim) -> PackedByteArray:
	var out := []
	for squad in sim.squads():
		out.append([squad.id, squad.state, squad.loose.size(), squad.position])
		for unit in squad.units:
			out.append([unit.id, unit.hp, unit.position, unit.bearing])
	return var_to_bytes(out)


func _lap(phase: String) -> void:
	var now := Time.get_ticks_usec()
	_spent[phase] = _spent.get(phase, 0) + now - _last
	_last = now


## FormationSimulation.step, phase by phase.
func _step(sim: Sim) -> void:
	_last = Time.get_ticks_usec()
	sim._tick += 1
	var events := []
	var squads := sim.squads()
	var tick := sim.tick_number()
	sim._apply_orders(events)
	sim._engage(events)
	sim._move(events)
	_lap("orders, engage, march")
	_scrum(sim, events)
	sim._fight(events)
	_lap("fight (blows)")
	var interval := sim._attack_interval_ticks()
	Sim.FormationDeaths.bury(squads, tick, events)
	Sim.FormationTaking.step(squads, tick, sim.tick_seconds, sim.fight_seed, events)
	Sim.FormationWounds.tend(squads, tick, interval, sim.fight_seed, events)
	var strays := Sim.FormationRecovery.step(squads, sim.tick_seconds, tick, sim.fight_seed, events)
	sim._next_squad_id = Sim.FormationStrays.adopt(
		strays, squads, sim._next_squad_id, sim.fight_seed
	)
	Sim.FormationMorale.step(squads, tick, interval, events)
	_lap("deaths, wounds, morale")
	_after(sim, events)


func _after(sim: Sim, events: Array) -> void:
	var squads := sim.squads()
	var tick := sim.tick_number()
	var pace := Sim.TRAVEL_SCALE * Sim.MapLayoutDef.CELLS_PER_TILE
	events.append_array(
		Sim.FormationRout.step(squads, tick, pace, sim.tick_seconds, sim.terrain, sim.fight_seed)
	)
	var strays := Sim.FormationCarry.step(squads, tick, sim.fight_seed, events)
	sim._next_squad_id = Sim.FormationStrays.adopt(
		strays, squads, sim._next_squad_id, sim.fight_seed
	)
	sim._next_squad_id = Sim.FormationGroups.step(
		squads, tick, sim.fight_seed, events, sim._next_squad_id
	)
	Sim.FormationStamina.step(squads, sim.tick_seconds)
	_lap("rout, carry, groups, stamina")
	Sim.UnitBodies.step(squads, sim.fight_seed, sim._field)
	_lap("bodies (UnitBodies)")
	for entry in squads:
		events.append_array(
			Sim.FormationShuffle.step(entry, sim.tick_seconds, Sim.TRAVEL_SCALE, tick)
		)
	Sim.FormationMarch.sync_units(squads, [sim.tick_seconds, pace], sim.terrain)
	_lap("shuffle, units to places")


## FormationScrum.step, phase by phase.
func _scrum(sim: Sim, events: Array) -> void:
	var squads := sim.squads()
	var tick := sim.tick_number()
	events.append_array(_scrum_events(sim))
	var pace := Sim.TRAVEL_SCALE * Sim.MapLayoutDef.CELLS_PER_TILE
	var ctx := {
		"squads": squads,
		"tick": tick,
		"seconds": sim.tick_seconds,
		"pace": pace * sim.tick_seconds,
		"seed": sim.fight_seed,
		"terrain": sim.terrain,
		"bodies": ScrumSeek.bodies(squads),
		"lying": GroundBodies.lying_in(squads),
		"active": {},
		"field": sim._field,
	}
	ctx["crowd"] = BodyGrid.of_bodies(ctx["bodies"])
	_lap("scrum: bodies snapshot")
	ScrumSeek.plan(ctx)
	_lap("scrum: seek (slot search)")
	_walk_and_face(ctx)
	var scrum_events := []
	ScrumRegroup.step(squads, ctx["pace"], sim.tick_seconds, sim.fight_seed)
	ScrumPursuit.step(squads, tick, pace, sim.tick_seconds, sim.fight_seed)
	FormationWithdraw.step(
		squads, tick, ctx["pace"], sim.tick_seconds, sim.fight_seed, sim.terrain, scrum_events
	)
	FormationPursuit.step(squads, tick, pace, sim.tick_seconds, scrum_events)
	Scrum._stall(squads, ctx["active"], tick, sim.tick_seconds, scrum_events)
	events.append_array(scrum_events)
	_lap("scrum: regroup, pursuit, stall")


func _scrum_events(sim: Sim) -> Array:
	var squads := sim.squads()
	var events := ScrumEngage.step(squads, sim.tick_number(), sim.fight_seed)
	for squad in squads:
		Scrum._prepare(squad, sim.tick_number())
	for squad in squads:
		ScrumStance.anticipate(
			squad, squads, sim.tick_number(), events, sim.terrain, sim.fight_seed
		)
	FormationManoeuvre.step(squads)
	_lap("scrum: engage, prepare, stance")
	return events


func _walk_and_face(ctx: Dictionary) -> void:
	var fighting: Array = ctx["squads"].filter(
		func(s): return s.state == SkirmishSquad.State.FIGHTING
	)
	for squad in fighting:
		var crowding := BattleTuning.current().scrum_crowding if squad.pursuit.is_empty() else 1.0
		Scrum._walk(squad, ctx["pace"] * crowding, ctx)
	_lap("scrum: walk (steering)")
	var turns := []
	for squad in fighting:
		turns.append_array(Scrum._faces(squad, ctx))
	for turn in turns:
		UnitMotion.turn(turn[0], turn[1], ctx["seconds"])
	_lap("scrum: face foes")
