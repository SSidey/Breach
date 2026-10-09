class_name ScrumSeekField
extends RefCounted
## ScrumSeek.plan on the native core (NativeKernels, Decision 129): the field brought to the
## scrum's snapshot (BodyFieldSync), then every fighting squad's units sent in one call -
## with what the rules say of each (may it seek, its speed, its place, the slot it made
## for), the foes each squad fights, and the ground asked back only where there is terrain
## - and the outcome written into their loose entries, exactly as ScrumSeek's own seeking
## would: who touches a foe and stands, who keeps to its place, who makes for a slot (and
## claims it), who presses in behind a taken one. Slots, keys, contest order and draws are
## the core's, bit for bit the GDScript's (native/README.md).

## What the core says each unit does (BodyField.plan).
enum Outcome { TOUCH, STAND, AIM, PRESS, IDLE }

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumStance = preload("res://sim/skirmish/formation/scrum_stance.gd")
const BodyFieldSync = preload("res://sim/skirmish/formation/body_field_sync.gd")

## Microseconds since last zeroed: [syncing the field, gathering the rules' say, the call,
## the core's own work, writing back]. The bench reads them; no outcome does.
static var spent := PackedInt64Array([0, 0, 0, 0, 0])


## One call's arrays: the fighting squads, their foes, and their units.
class Batch:
	var units: Array = []
	var owners: Array = []
	var squads := PackedInt64Array()
	var foe_ids := PackedInt64Array()
	var members := PackedInt32Array()
	var may_seek := PackedByteArray()
	var speeds := PackedFloat64Array()
	var anchors := PackedVector2Array()
	var goal_foes := PackedInt64Array()
	var goal_slots := PackedInt32Array()


## Plans every fighting squad's units on ctx["field"] (see ScrumSeek.plan).
static func plan(ctx: Dictionary) -> void:
	var field: Object = ctx["field"]
	var began := Time.get_ticks_usec()
	var synced := BodyFieldSync.scrum(field, ctx["squads"], ctx["seed"])
	var synced_at := Time.get_ticks_usec()
	spent[0] += synced_at - began
	var batch := _gather(synced[0], synced[1], ctx["squads"])
	ctx["seek_batch"] = batch  # the facing after the walk turns these units (ScrumFaceField)
	var called := Time.get_ticks_usec()
	var tuning := BattleTuning.current()
	var ints := PackedInt64Array([ctx["tick"], ctx["seed"], tuning.combat_contest_die])
	var floats := PackedFloat64Array([tuning.reach_contact, tuning.scrum_leash])
	var within := Callable()
	if ctx["terrain"] != null:
		var terrain: Object = ctx["terrain"]
		within = func(member: int, point: Vector2) -> bool:
			return terrain.factor(batch.units[member], point, point) > 0.0
	var out: Array = field.plan(
		ints,
		floats,
		batch.squads,
		batch.foe_ids,
		batch.members,
		batch.may_seek,
		batch.speeds,
		batch.anchors,
		batch.goal_foes,
		batch.goal_slots,
		within
	)
	var returned := Time.get_ticks_usec()
	_write_back(batch, out, ctx["active"])
	spent[1] += called - synced_at
	spent[2] += returned - called
	spent[3] += field.usec()
	spent[4] += Time.get_ticks_usec() - returned


## The fighting squads' units, in list order, chasers left to ScrumPursuit.
static func _gather(units: Array, owners: Array, squads: Array) -> Batch:
	var batch := Batch.new()
	var current: SkirmishSquad = null
	var front_left := false
	for index in range(units.size()):
		var squad: SkirmishSquad = owners[index]
		if squad.state != SkirmishSquad.State.FIGHTING:
			continue
		if squad != current:
			current = squad
			front_left = squad.living().any(func(u): return u.preferred_position == 0)
			var foes := ScrumSeek.foe_ids(squad, squads)
			batch.squads.append_array([squad.id, foes.size(), 0])
			batch.foe_ids.append_array(foes)
		var unit: SkirmishUnit = units[index]
		if squad.chasers.has(unit.id):
			continue
		var seeks := ScrumSeek._may_seek(squad, unit, front_left)
		var goal = squad.loose[unit.id]["goal"]
		batch.units.append(unit)
		batch.owners.append(squad)
		batch.members.append(index)
		batch.may_seek.append(1 if seeks else 0)
		batch.speeds.append(unit.speed)
		batch.anchors.append(ScrumStance.anchor(squad, unit) if seeks else Vector2.ZERO)
		batch.goal_foes.append(0 if goal == null else goal[0])
		batch.goal_slots.append(-1 if goal == null else goal[1])
		batch.squads[batch.squads.size() - 1] += 1
	return batch


## Writes the core's [codes, goal foes, goal slots, nexts, foe_ats] into the units' entries.
static func _write_back(batch: Batch, out: Array, active: Dictionary) -> void:
	var codes: PackedByteArray = out[0]
	for member in range(codes.size()):
		var squad: SkirmishSquad = batch.owners[member]
		var entry: Dictionary = squad.loose[batch.units[member].id]
		var code: int = codes[member]
		entry["touch"] = code == Outcome.TOUCH
		if code == Outcome.STAND:
			entry["goal"] = null
		elif code == Outcome.TOUCH or code == Outcome.IDLE:
			entry["goal"] = null
			entry["next"] = entry["at"]
		else:
			entry["goal"] = [out[1][member], out[2][member]]
			entry["next"] = out[3][member]
			entry["foe_at"] = out[4][member]
		if code == Outcome.TOUCH or code == Outcome.AIM or code == Outcome.PRESS:
			active[squad.id] = true
