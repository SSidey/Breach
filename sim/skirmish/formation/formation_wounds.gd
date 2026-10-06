class_name FormationWounds
extends RefCounted
## What becomes of the downed and the caught (Decision 121, spec 28 part 6). Units don't
## leave the downed: once no friend of a downed unit stands near it (wounds_guard_reach)
## and a standing foe beside it (wounds_reach) has no foe of its own near, that foe takes
## it - captures it if it is a captor, else strikes it on its blows' interval, down into
## death's door, constitution deep (FormationDeaths.depth), till it dies. The one
## exception: a foe whose formation's leader can send a messenger (its "messenger" trait,
## one a level) lets it go, to carry word home - a morale blow to every standing formation
## of its side. A routing unit struck may surrender in place, by a seeded chance from its
## want of courage (none for one with "never_surrenders"). Decided from one snapshot,
## then applied (Decision 97). Pure over the squads it is given.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const BattleRolls = preload("res://sim/skirmish/formation/battle_rolls.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const FormationDeaths = preload("res://sim/skirmish/formation/formation_deaths.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")


## This tick's takings of the downed. `interval` is ticks a second (a taker strikes on its
## melee interval).
static func tend(squads: Array, tick: int, interval: int, fight_seed: int, events: Array) -> void:
	var standing := []  # [unit, squad]
	var downed := []
	for squad in squads:
		for unit in squad.units:
			if unit.is_alive():
				standing.append([unit, squad])
			elif unit.state == SkirmishUnit.State.DOWNED:
				downed.append([unit, squad])
	if downed.is_empty():
		return
	var taken := {}  # body id -> [body, its squad, [taker, its squad], ...]
	for taker in standing:
		var body := _within_reach(taker, standing, downed, fight_seed)
		if not body.is_empty():
			if not taken.has(body[0].id):
				taken[body[0].id] = [body[0], body[1]]
			taken[body[0].id].append(taker)
	for body_id in taken:
		_take(taken[body_id], squads, tick, interval, events)


## Routing units struck by this tick's `blows` ([striker, target, damage, ...]) that
## surrender.
static func surrender(
	blows: Array, squads: Array, fight_seed: int, tick: int, events: Array
) -> void:
	var routing := {}  # unit id -> its squad
	for squad in squads:
		if squad.state == SkirmishSquad.State.ROUTING:
			for unit in squad.living():
				routing[unit.id] = squad
	var chance := BattleTuning.current().wounds_surrender
	for blow in blows:
		var caught: SkirmishUnit = blow[1]
		if not routing.has(caught.id) or blow[2] <= 0 or caught.hp <= 0 or not caught.is_alive():
			continue
		if caught.traits.get("never_surrenders", 0) > 0:
			continue
		var want := chance * (1.0 - clampf(caught.courage / 100.0, 0.0, 1.0))
		if BattleRolls.uniform(fight_seed, [tick, caught.id, "surrender"]) < want:
			caught.state = SkirmishUnit.State.TAKEN
			events.append(
				FormationEvents.unit_event("surrendered", tick, routing[caught.id], caught)
			)
			_retire(routing[caught.id], squads, tick, events)


## The downed foe the taker would take, [body, its squad], or [] - none unguarded within
## reach, or a foe still near it.
static func _within_reach(taker: Array, standing: Array, downed: Array, fight_seed: int) -> Array:
	var tuning := BattleTuning.current()
	var unit: SkirmishUnit = taker[0]
	for other in standing:
		if other[0].faction_id != unit.faction_id:
			if other[0].position.distance_to(unit.position) <= tuning.wounds_guard_reach:
				return []  # still fighting
	var best := []
	var best_key := []
	for body in downed:
		if body[0].faction_id == unit.faction_id:
			continue
		var gap: float = body[0].position.distance_to(unit.position)
		if gap > tuning.wounds_reach or _guarded(body[0], standing):
			continue
		var key := [snappedf(gap, 0.000001), ScrumContest.draw(body[0], fight_seed)]
		if best.is_empty() or key < best_key:
			best = body
			best_key = key
	return best


static func _guarded(body: SkirmishUnit, standing: Array) -> bool:
	for other in standing:
		if other[0].faction_id == body.faction_id:
			if (
				other[0].position.distance_to(body.position)
				<= BattleTuning.current().wounds_guard_reach
			):
				return true
	return false


## One body's takers act: a captor captures it; else a leader's messenger sends it home;
## else each taker due strikes it.
static func _take(taking: Array, squads: Array, tick: int, interval: int, events: Array) -> void:
	var body: SkirmishUnit = taking[0]
	var takers := taking.slice(2)
	for taker in takers:
		if taker[0].traits.get("captor", 0) > 0:
			body.state = SkirmishUnit.State.TAKEN
			var extra := {"by": taker[0].id}
			events.append(FormationEvents.unit_event("captured", tick, taking[1], body, extra))
			return
	for taker in takers:
		var leader := _messenger(taker[1])
		if leader != null:
			leader.traits["messenger"] = leader.traits["messenger"] - 1
			body.state = SkirmishUnit.State.RELEASED
			events.append(FormationEvents.unit_event("sent_home", tick, taking[1], body))
			for squad in squads:
				if squad.faction_id == body.faction_id and not squad.is_destroyed():
					var shock := BattleTuning.current().wounds_messenger_shock
					FormationMorale.shock(squad, shock, tick, events)
			return
	for taker in takers:
		var striker: SkirmishUnit = taker[0]
		striker.target_id = body.id
		striker.attack_cooldown -= 1
		if striker.attack_cooldown > 0:
			continue
		striker.attack_cooldown = maxi(1, roundi(interval * striker.melee_seconds))
		body.hp -= striker.dmg
	if body.hp <= -FormationDeaths.depth(body):
		body.state = SkirmishUnit.State.DEAD
		events.append(FormationEvents.unit_event("finished", tick, taking[1], body))


## The squad's leader that can still send a messenger, or null.
static func _messenger(squad: SkirmishSquad) -> SkirmishUnit:
	for unit in squad.living():
		if unit.leadership > 0 and unit.traits.get("messenger", 0) > 0:
			return unit
	return null


## A squad left with no one standing is destroyed, freeing whoever fought it.
static func _retire(squad: SkirmishSquad, squads: Array, tick: int, events: Array) -> void:
	if squad.is_destroyed() and squad.state != SkirmishSquad.State.DESTROYED:
		squad.state = SkirmishSquad.State.DESTROYED
		FormationLocks.release(squad, squads)
		events.append(FormationEvents.squad_event("destroyed", tick, squad))
