class_name FormationIntent
extends RefCounted
## Tactical over strategic (Decision 94, spec 27 round 7). A formation's own decisions come
## before the player's order: 0 combat (seek contact, Decision 88), 1 its route, 2
## re-forming (Decision 92), 3 the order (retreat, halt, march, hold-until). This keeps the
## one case the other rules miss, checked every tick: a formation ordered to march that
## stood still this tick for no order of the player's (not holding, staged, waiting,
## fighting, skirmishing at range, blocked or done) and isn't in the middle of a manoeuvre
## of its own (re-forming after a turn, narrowing at a gap, or receiving an enemy still
## closing in) moves to combat if it detects an enemy within ENGAGE_REACH, and otherwise
## lets go of any re-formed line so it returns to its route, re-forms and marches on.
## Squads keep `last_front`. Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadEdges = preload("res://sim/skirmish/formation/squad_edges.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationSight = preload("res://sim/skirmish/formation/formation_sight.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const ScrumStance = preload("res://sim/skirmish/formation/scrum_stance.gd")

## How near (cells, between their extents) an enemy must be to count as a fight to join.
const ENGAGE_REACH := 12.0


## One tick: sends formations halted without an order to a fight nearby, or back to their
## march. Returns "engaged" events.
static func step(squads: Array, tick: int, terrain: FormationTerrain = null) -> Array:
	var events := []
	for squad in squads:
		if not _uncommanded_halt(squad) or _manoeuvring(squad, squads, terrain):
			continue
		var foe := _nearest_foe(squad, squads, terrain)
		if foe != null:
			FormationLocks.lock(squad, foe)
			if foe.engaged_with == 0 and foe.state != SkirmishSquad.State.FIGHTING:
				FormationLocks.lock(foe, squad)  # both join the fight together
			events.append(FormationEvents.squad_event("engaged", tick, squad, {"with": foe.id}))
		else:
			squad.stance = {}  # back to its route and its places, then on
	return events


## True if it stands still for a manoeuvre of its own, about to move on or to fight:
## skirmishing at range, re-forming after a turn, narrowing at a gap, or receiving an
## enemy still closing in.
static func _manoeuvring(squad: SkirmishSquad, squads: Array, terrain: FormationTerrain) -> bool:
	var turning: bool = squad.stance.is_empty() and not squad.loose.is_empty()
	return (
		turning
		or squad.narrow_ticks > 0
		or ScrumStance.receiving(squad, squads, terrain)
		or FormationContact.skirmishing(squad, squads)
	)


## True if the squad is ordered to march but stood still this tick for no order of the
## player's: not fighting, holding, routing, done, waiting or staged.
static func _uncommanded_halt(squad: SkirmishSquad) -> bool:
	var still := is_equal_approx(squad.front_distance, squad.last_front)
	squad.last_front = squad.front_distance
	return (
		still
		and squad.order == SkirmishUnit.Order.ADVANCE
		and squad.staging.is_empty()
		and squad.wait_ticks == 0
		and squad.engaged_with == 0
		and squad.flank_contacts.is_empty()
		and squad.state in [SkirmishSquad.State.MOVING, SkirmishSquad.State.HOLDING]
		and not squad.blocked
	)


## The nearest enemy it detects within ENGAGE_REACH that it can fight, or null.
static func _nearest_foe(
	squad: SkirmishSquad, squads: Array, terrain: FormationTerrain
) -> SkirmishSquad:
	var area := SquadEdges.bounds(squad)
	var best: SkirmishSquad = null
	var best_gap := ENGAGE_REACH + 0.000001
	for other in squads:
		if other.faction_id == squad.faction_id or not FormationContact.can_engage(other):
			continue
		if not FormationSight.detects(squad, other, terrain):
			continue
		var theirs := SquadEdges.bounds(other)
		var near := theirs.get_center().clamp(area.position, area.end)
		var gap := near.distance_to(near.clamp(theirs.position, theirs.end))
		if gap < best_gap:
			best = other
			best_gap = gap
	return best
