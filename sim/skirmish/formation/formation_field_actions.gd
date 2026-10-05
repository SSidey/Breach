class_name FormationFieldActions
extends RefCounted
## The feel test's player actions as words, so a session can be logged and replayed tick
## for tick (Decision 93: the same seed and orders replay a battle). The scene's buttons
## apply them through here and log "<tick> <action>"; a log replays the same battle
## (tools/formation_replay.gd, or the scene's Replay log button). A log opens with
## "seed <n> captain <on|off>". Actions:
##   send A | send B | send A+B | retreat A | retreat B | auto A on | auto B off |
##   wait on | via_c on | pursues on   (on or off)
## Pure over the field it is given.

const FormationField = preload("res://sim/skirmish/formation/formation_field.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")

const BUILDERS := 4
const TICK_SECONDS := 0.1


## The feel test's field under `battle_seed`, its line led by a captain or not.
static func field(battle_seed: int, captained: bool) -> FormationField:
	var captain: UnitDef = load("res://content/units/kingdom_captain.tres") if captained else null
	return FormationField.new(
		TICK_SECONDS,
		load("res://content/units/grem.tres"),
		BUILDERS,
		load("res://content/units/kingdom_militia.tres"),
		load("res://content/units/grem_chieftain.tres"),
		captain,
		battle_seed
	)


## Applies one action (as the log words it) to the field; false if it isn't one.
static func apply(field: FormationField, action: String) -> bool:
	var words := action.strip_edges().split(" ", false)
	if words.size() < 2:
		return false
	var on := words.size() > 2 and words[2] == "on"
	match words[0]:
		"send":
			if words[1] == "A+B":
				field.send_together(["A", "B"])
			else:
				field.send(words[1])
		"retreat":
			for squad in field.sim.squads():
				if squad.faction_id == "player" and squad.route == field.waves[words[1]].route:
					field.sim.order(squad.id, SkirmishUnit.Order.RETREAT)
		"auto":
			field.set_auto(words[1], on)
		"wait":
			field.set_wait(words[1] == "on")
		"via_c":
			field.waves["A"].route = field.routes["C" if words[1] == "on" else "A"]
		"pursues":
			field.kingdom_line.pursues = words[1] == "on"
			field.kingdom_reserve.pursues = words[1] == "on"
		_:
			return false
	return true


## A log read back: {"seed", "captained", "actions": [[tick, action], ...]} in order.
static func parse(log: String) -> Dictionary:
	var lines := log.strip_edges().split("\n", false)
	var head := lines[0].split(" ", false) if lines.size() > 0 else PackedStringArray()
	var read := {"seed": 0, "captained": false, "actions": []}
	if head.size() < 2 or head[0] != "seed" or not head[1].is_valid_int():
		return {}
	read["seed"] = int(head[1])
	read["captained"] = head.size() > 3 and head[3] == "on"
	for line in lines.slice(1):
		var parts := line.strip_edges().split(" ", false, 1)
		if parts.size() == 2 and parts[0].is_valid_int():
			read["actions"].append([int(parts[0]), parts[1]])
	return read


## The field a log leaves after its last action and `extra` more ticks; after every tick
## `on_events` (the field, the tick's events) is called, if given.
static func replay(log: String, extra: int, on_events: Callable = Callable()) -> FormationField:
	var read := parse(log)
	var played := field(read["seed"], read["captained"])
	var tick := 0
	for queued in read["actions"]:
		while tick < queued[0]:
			_step(played, on_events)
			tick += 1
		apply(played, queued[1])
	for _i in range(extra):
		_step(played, on_events)
	return played


static func _step(played: FormationField, on_events: Callable) -> void:
	var events := played.step()
	if on_events.is_valid():
		on_events.call(played, events)
