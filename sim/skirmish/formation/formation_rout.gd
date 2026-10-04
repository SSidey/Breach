class_name FormationRout
extends RefCounted
## Rout (Decision 82, spec 27 round 3): a panicked flight, not an orderly about-face.
## - **Breaking:** at 0 morale a formation routs. Every lock on it ends, and friends that
##   see it break take a little shock.
## - **Flight:** its units flee one by one back along its route towards home at full
##   speed, keeping their spread across it. They strike nothing; a hostile unit in contact
##   strikes them from behind (RoutBlows, flank blows).
## - **Crush:** a router running through a friend's cell hurts both (blunt, by its size),
##   and that friend's formation takes panic shock.
## - **Rally:** a router that reaches a friendly formation with a leader joins its rear
##   ranks. One that runs into any standing friendly formation (Decisions 89 and 98) is
##   caught there: it stops (with contact-seeking, in the nearest free cell: RoutSettle),
##   and after STEADY_RALLY_SECONDS with that formation steady joins its rear, walking to
##   its place. A shaken formation holds its routers until it steadies.
##   A routing formation whose own leader lives, with no enemy near for a few seconds,
##   re-forms where its leader stands and holds there.
## - **Home:** routers that reach home leave the field ("fled_home"; the player's routers
##   go back to the reserve).
## Nothing hangs on list order (Decision 97): who breaks is decided before any breaks, so
## one break's shock can't cascade within the tick for squads listed later; every router
## flees, then every rally is decided, then they join; a router crushes or is caught by the
## nearest friend; ties go to the units' seeded draws (ScrumContest).
## A routing squad's `fleeing`: unit id -> {"along": cells along its route, "offset":
## its spread from the route}. Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const FormationSight = preload("res://sim/skirmish/formation/formation_sight.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const RoutCatch = preload("res://sim/skirmish/formation/rout_catch.gd")
const RoutSettle = preload("res://sim/skirmish/formation/rout_settle.gd")
const ScrumContest = preload("res://sim/skirmish/formation/scrum_contest.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const CELLS := float(MapLayoutDef.CELLS_PER_TILE)
## Crush damage per cell of the router's footprint (placeholder).
const CRUSH := 2
const PANIC := 5
const SEEN_ROUT := 5
## How near (cells) a router must come to a led formation to rally to it.
const RALLY_REACH := 2.0
## A router running into a standing friendly formation (within this many cells) is caught
## there, and rallies to it after a while steady (Decisions 89 and 98).
const CAUGHT_REACH := 1.0
const STEADY_RALLY_SECONDS := 3.0
## Seconds with no enemy within ENEMY_NEAR cells before a led rout re-forms.
const RALLY_SECONDS := 5.0
const ENEMY_NEAR := 6.0
const REFORMED_MORALE := 30
## How near (cells, centre to centre) a pursuer must be to strike a router.
const STRIKE_REACH := 1.5


## One tick of routs: formations at 0 morale break, routers flee (crushing friends in the
## way), rally, re-form or reach home. `cells_per_second` is the pace at speed 1.
static func step(
	squads: Array,
	tick: int,
	cells_per_second: float,
	tick_seconds: float,
	terrain: FormationTerrain = null,
	one_per_cell := false,
	fight_seed := 0
) -> Array:
	var events := []
	var breaking := squads.filter(
		func(s): return s.state != SkirmishSquad.State.ROUTING and _breaks(s)
	)
	var routing := squads.filter(func(s): return s.state == SkirmishSquad.State.ROUTING)
	var pace := cells_per_second * tick_seconds
	for squad in routing:
		_flee(squad, squads, tick, pace, events, fight_seed)
	var joins := []
	for squad in routing:
		joins.append_array(_rallies(squad, squads, tick_seconds, fight_seed))
	joins.sort_custom(func(a, b): return a[0] < b[0])
	for entry in joins:
		_join(entry[1], entry[2], entry[3], tick, events)
	for squad in routing:
		_regroup(squad, squads, tick, tick_seconds, events, fight_seed)
	if one_per_cell:
		RoutSettle.settle(routing, squads, pace, where, fight_seed)
	for squad in breaking:
		_break(squad, squads, tick, events, terrain)
	return events


## The world point a router stands at.
static func where(squad: SkirmishSquad, unit_id: int) -> Vector2:
	var entry: Dictionary = squad.fleeing[unit_id]
	return _route_point(squad, entry["along"]) + entry["offset"]


static func _breaks(squad: SkirmishSquad) -> bool:
	return (
		squad.state != SkirmishSquad.State.DESTROYED
		and squad.state != SkirmishSquad.State.ARRIVED
		and not squad.living().is_empty()
		and squad.morale == 0
	)


static func _break(
	squad: SkirmishSquad, squads: Array, tick: int, events: Array, terrain: FormationTerrain
) -> void:
	FormationLocks.release(squad, squads)
	squad.flank_contacts.clear()
	squad.wings.clear()
	squad.staging = {}
	squad.swaps.clear()
	squad.state = SkirmishSquad.State.ROUTING
	squad.rally_ticks = 0
	var along := squad.front_distance * CELLS
	for unit in squad.living():
		var offset: Vector2 = unit.position - _route_point(squad, along)
		squad.fleeing[unit.id] = {"along": along, "offset": offset}
	events.append(FormationEvents.squad_event("routed", tick, squad))
	for friend in squads:
		if friend != squad and friend.faction_id == squad.faction_id and not friend.is_destroyed():
			if FormationSight.detects(friend, squad, terrain):
				FormationMorale.shock(friend, SEEN_ROUT, tick, events)


static func _flee(
	squad: SkirmishSquad, squads: Array, tick: int, pace: float, events: Array, fight_seed: int
) -> void:
	var home := squad.home_distance * CELLS
	var panicked := {}
	for unit in squad.living():
		var entry: Dictionary = squad.fleeing[unit.id]
		if entry.get("caught", 0) > 0:
			continue  # held by a steady friend it ran into
		entry["along"] = move_toward(entry["along"], home, unit.speed * pace)
		_crush([squad, unit, fight_seed], squads, tick, panicked, events)
		if is_equal_approx(entry["along"], home):
			squad.units.erase(unit)
			squad.fleeing.erase(unit.id)
			var extra := {"unit": unit.id, "definition": unit.definition}
			events.append(FormationEvents.squad_event("fled_home", tick, squad, extra))
	if squad.living().is_empty():
		squad.state = SkirmishSquad.State.DESTROYED
		events.append(FormationEvents.squad_event("scattered", tick, squad))


## A router (`who` = [its squad, the unit, the battle seed]) crushes the nearest friend's
## unit it runs into (ties by their draws).
static func _crush(
	who: Array, squads: Array, tick: int, panicked: Dictionary, events: Array
) -> void:
	var squad: SkirmishSquad = who[0]
	var router: SkirmishUnit = who[1]
	var at := where(squad, router.id)
	var hit := []  # [key, friend, unit]
	for friend in squads:
		if friend == squad or friend.faction_id != squad.faction_id:
			continue
		if friend.state == SkirmishSquad.State.ROUTING:
			continue
		for unit in friend.living():
			var gap: float = unit.position.distance_to(at)
			var key := [snappedf(gap, 0.000001), ScrumContest.draw(unit, who[2])]
			if gap < 1.0 and (hit.is_empty() or key < hit[0]):
				hit = [key, friend, unit]
	if hit.is_empty():
		return
	var damage := CRUSH * router.footprint_width * router.footprint_depth
	router.hp -= damage
	hit[2].hp -= damage
	var extra := {"unit": router.id, "target": hit[2].id, "dmg": damage}
	events.append(FormationEvents.squad_event("crushed", tick, hit[1], extra))
	if not panicked.has(hit[1].id):
		panicked[hit[1].id] = true
		FormationMorale.shock(hit[1], PANIC, tick, events)


## [[key, squad, unit, friend], ...]: the squad's routers that join a friend this tick,
## decided before any joins - one with a leader near, or one held long enough by a steady
## friend - keyed nearest first. Counts each held router's time caught.
static func _rallies(
	squad: SkirmishSquad, squads: Array, tick_seconds: float, fight_seed: int
) -> Array:
	var out := []
	for unit in squad.living():
		var at := where(squad, unit.id)
		var leader := RoutCatch.friend_near(squad, at, squads, RALLY_REACH, true, fight_seed)
		if leader != null:
			out.append([_key(leader, unit, at, fight_seed), squad, unit, leader])
			continue
		var entry: Dictionary = squad.fleeing[unit.id]
		var friend := RoutCatch.holder(squad, entry, at, squads, CAUGHT_REACH, fight_seed)
		var calm := friend != null and FormationMorale.band(friend) == FormationMorale.Band.STEADY
		var held: int = entry.get("caught", 0)
		entry["caught"] = 0 if friend == null else (held + 1 if calm else maxi(held, 1))
		entry["held_by"] = null if friend == null else friend.id
		if calm and entry["caught"] * tick_seconds >= STEADY_RALLY_SECONDS:
			out.append([_key(friend, unit, at, fight_seed), squad, unit, friend])
	return out


## Routers joining a friend line up behind it nearest first, ties by their draws.
static func _key(friend: SkirmishSquad, unit: SkirmishUnit, at: Vector2, fight_seed: int) -> Array:
	return [snappedf(RoutCatch.gap(friend, at), 0.000001), ScrumContest.draw(unit, fight_seed)]


## A routing formation whose own leader lives re-forms after a while with no enemy near.
static func _regroup(
	squad: SkirmishSquad,
	squads: Array,
	tick: int,
	tick_seconds: float,
	events: Array,
	fight_seed: int
) -> void:
	if squad.living().is_empty() or FormationMorale.leadership(squad) == 0:
		return
	squad.rally_ticks = 0 if _enemy_near(squad, squads) else squad.rally_ticks + 1
	if squad.rally_ticks * tick_seconds >= RALLY_SECONDS:
		_reform(squad, tick, events, fight_seed)


static func _join(
	squad: SkirmishSquad, unit: SkirmishUnit, leader: SkirmishSquad, tick: int, events: Array
) -> void:
	var settled = squad.fleeing.get(unit.id, {}).get("settled_at")
	squad.units.erase(unit)
	squad.fleeing.erase(unit.id)
	unit.rank = 0
	unit.column = 0
	var members: Array[SkirmishUnit] = [unit]
	var single := SkirmishSquad.new(-1, squad.faction_id, leader.direction, 0.0, 1, members)
	FormationContact.reinforce(leader, single)
	leader.reforming = true
	if settled != null:
		RoutSettle.walk_in(leader, unit, settled)  # it walks to its place in the ranks
	events.append(FormationEvents.unit_event("rallied", tick, squad, unit, {"into": leader.id}))
	if squad.living().is_empty():
		squad.state = SkirmishSquad.State.DESTROYED


static func _enemy_near(squad: SkirmishSquad, squads: Array) -> bool:
	for other in squads:
		if other.faction_id == squad.faction_id or other.is_destroyed():
			continue
		for enemy in other.living():
			for unit in squad.living():
				if enemy.position.distance_to(where(squad, unit.id)) <= ENEMY_NEAR:
					return true
	return false


## Re-forms where its leader stands (the best, ties by draw), facing the enemy's end again,
## and holds.
static func _reform(squad: SkirmishSquad, tick: int, events: Array, fight_seed: int) -> void:
	var leader: SkirmishUnit = null
	var best := []
	for unit in squad.living():
		var key := [-unit.leadership, ScrumContest.draw(unit, fight_seed)]
		if leader == null or key < best:
			leader = unit
			best = key
	squad.front_distance = squad.fleeing[leader.id]["along"] / CELLS
	squad.fleeing.clear()
	squad.direction = 1 if is_zero_approx(squad.home_distance) else -1
	if squad.route != null:
		var cells := squad.front_distance * CELLS
		squad.facing = squad.route.facing_at(cells, squad.direction, squad.facing)
	else:
		squad.facing = SquadFrame.EAST if squad.direction > 0 else SquadFrame.WEST
	squad.order = SkirmishUnit.Order.HOLD
	squad.state = SkirmishSquad.State.HOLDING
	squad.morale = REFORMED_MORALE
	squad.reforming = true
	events.append(FormationEvents.squad_event("reformed", tick, squad))


static func _route_point(squad: SkirmishSquad, along: float) -> Vector2:
	if squad.route == null:
		return Vector2(along, 0.0)
	return squad.route.point_at(along)
