extends SceneTree
## Replays a feel-test session from its action log (FormationFieldActions), printing what
## happened, so a reported battle can be seen tick for tick:
##   godot --headless --path . --script res://tools/formation_replay.gd -- \
##       log=<path to the log> [extra=600] [every=100]
## It prints the notable events as they happen and every squad's state every `every`
## ticks.

const FormationFieldActions = preload("res://sim/skirmish/formation/formation_field_actions.gd")
const FormationScrum = preload("res://sim/skirmish/formation/formation_scrum.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

const NOTABLE := [
	"order_applied",
	"engaged",
	"routed",
	"rallied",
	"reformed",
	"destroyed",
	"scattered",
	"arrived",
	"returned",
	"withdrawing",
	"regrouping",
	"disengaged",
	"narrowed",
	"widened",
	"blocked",
	"flanked",
	"faced",
	"fled_home",
	"joined",
]


func _init() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var log := FileAccess.get_file_as_string(args.get("log", ""))
	var every := int(args.get("every", 100))
	var report := func(field, events: Array) -> void:
		for event in events:
			if NOTABLE.has(event["type"]):
				print(event)
		if field.sim.tick_number() % every == 0:
			_squads(field)
	FormationFieldActions.replay(log, int(args.get("extra", 600)), report)
	quit(0)


func _squads(field) -> void:
	print("-- tick %d" % field.sim.tick_number())
	for squad in field.sim.squads():
		print(
			(
				"   squad %d %s %s %s front %.3f at %s living %d morale %d%s"
				% [
					squad.id,
					squad.faction_id,
					SkirmishSquad.State.keys()[squad.state],
					SkirmishUnit.Order.keys()[squad.order],
					squad.front_distance,
					squad.position.snapped(Vector2(0.1, 0.1)),
					squad.living().size(),
					squad.morale,
					" regrouping" if FormationScrum.regrouping(squad) else "",
				]
			)
		)
