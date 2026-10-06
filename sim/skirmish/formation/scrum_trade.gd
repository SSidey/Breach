class_name ScrumTrade
extends RefCounted
## Trading places while regrouping (Decision 110): a unit walking back to its place that has
## come no nearer than its closest for scrum_trade_seconds - its own ranks in the way - trades
## places with the friend whose place is nearest it, if that place is nearer it than its
## own and the two are interchangeable (one kind, one band); the friend walks to the place
## it left. With no such friend, its own place is the nearest: it takes it. Places stay one
## unit each. Stalled units trade in the order of their seeded draws, never the list's
## (Decision 97). Pure over the squad it is given.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumStance = preload("res://sim/skirmish/formation/scrum_stance.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")

## Cells nearer than its closest yet that count as getting nearer.
const PROGRESS := 0.001


## Notes how near the loose unit's `entry` stands to its place, `gap` cells off.
static func track(entry: Dictionary, gap: float, seconds: float) -> void:
	if gap < entry.get("closest", INF) - PROGRESS:
		entry["closest"] = gap
		entry["stuck"] = 0.0
	else:
		entry["stuck"] = entry.get("stuck", 0.0) + seconds


## Each stalled unit of the squad trades places, if a friend's place is nearer it; one that
## can't is as near its place as the press allows, and takes it there and then.
static func trade(squad: SkirmishSquad, fight_seed: int) -> void:
	var stalled := []
	for unit_id in squad.loose:
		if (
			squad.loose[unit_id].get("stuck", 0.0)
			>= BattleTuning.current().scrum_trade_seconds - 0.000001
		):
			stalled.append(squad.loose[unit_id]["unit"])
	stalled.sort_custom(
		func(a, b): return ScrumContest.draw(a, fight_seed) < ScrumContest.draw(b, fight_seed)
	)
	for unit in stalled:
		if not squad.loose.has(unit.id):
			continue
		var at: Vector2 = squad.loose[unit.id]["at"]
		var friend := _nearest_place(squad, unit, at, fight_seed)
		if friend != null:
			_swap(squad, unit, friend)
		elif squad.stance.is_empty():
			squad.loose.erase(unit.id)
			unit.position = ScrumStance.anchor(squad, unit)  # its body stands there from now


## The interchangeable friend whose place is nearest `at`, and nearer than the unit's own;
## null if none. Ties by the friends' draws.
static func _nearest_place(
	squad: SkirmishSquad, unit: SkirmishUnit, at: Vector2, fight_seed: int
) -> SkirmishUnit:
	var own := ScrumStance.anchor(squad, unit).distance_to(at)
	var best: SkirmishUnit = null
	var best_key := []
	for friend in squad.living():
		var same: bool = (  # interchangeable: the painted layout keeps its meaning
			friend.definition == unit.definition
			and friend.preferred_position == unit.preferred_position
			and friend.footprint_width == unit.footprint_width
			and friend.footprint_depth == unit.footprint_depth
		)
		if friend == unit or not same or squad.chasers.has(friend.id):
			continue
		var there := ScrumStance.anchor(squad, friend).distance_to(at)
		if there >= own - PROGRESS:
			continue
		var key := [snappedf(there, 0.000001), ScrumContest.draw(friend, fight_seed)]
		if best_key.is_empty() or key < best_key:
			best = friend
			best_key = key
	return best


## The two swap places; the friend, loose if it wasn't, walks to its new one.
static func _swap(squad: SkirmishSquad, unit: SkirmishUnit, friend: SkirmishUnit) -> void:
	var place := Vector2i(unit.rank, unit.column)
	unit.rank = friend.rank
	unit.column = friend.column
	friend.rank = place.x
	friend.column = place.y
	if not squad.loose.has(friend.id):
		var at := friend.position
		squad.loose[friend.id] = {"unit": friend, "at": at, "goal": null, "next": at}
	for moved in [unit, friend]:
		squad.loose[moved.id].erase("closest")
		squad.loose[moved.id].erase("stuck")
