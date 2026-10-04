class_name FormationRout
extends RefCounted
## Rout (Decision 82, spec 27 round 3): a panicked flight, not an orderly about-face.
## - **Breaking:** at 0 morale a formation routs. Every lock on it ends, and friends that
##   see it break take a little shock.
## - **Flight:** its units flee one by one back along its route towards home at full
##   speed, keeping their spread across it. They strike nothing; a hostile unit in contact
##   strikes them from behind (FormationMelee, flank blows).
## - **Crush:** a router running through a friend's cell hurts both (blunt, by its size),
##   and that friend's formation takes panic shock.
## - **Rally:** a router that reaches a friendly formation with a leader joins its rear
##   ranks. One that runs into a steady friendly formation without a leader (Decision 89)
##   is caught there: it stops (with contact-seeking, in the nearest free cell: RoutSettle),
##   and after STEADY_RALLY_SECONDS joins that formation's rear, walking to its place.
##   A routing formation whose own leader lives, with no enemy near for a few seconds,
##   re-forms where its leader stands and holds there.
## - **Home:** routers that reach home leave the field ("fled_home"; the player's routers
##   go back to the reserve).
## A routing squad's `fleeing`: unit id -> {"along": cells along its route, "offset":
## its spread from the route}. Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const FormationSight = preload("res://sim/skirmish/formation/formation_sight.gd")
const FormationContact = preload("res://sim/skirmish/formation/formation_contact.gd")
const FormationCombat = preload("res://sim/skirmish/formation/formation_combat.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const RoutSettle = preload("res://sim/skirmish/formation/rout_settle.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")

const CELLS := float(MapLayoutDef.CELLS_PER_TILE)
## Crush damage per cell of the router's footprint (placeholder).
const CRUSH := 2
const PANIC := 5
const SEEN_ROUT := 5
## How near (cells) a router must come to a led formation to rally to it.
const RALLY_REACH := 2.0
## A router running into a steady formation (within this many cells) is caught there, and
## rallies to it after a while (Decision 89).
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
	one_per_cell := false
) -> Array:
	var events := []
	for squad in squads.duplicate():
		if squad.state == SkirmishSquad.State.ROUTING:
			_flee(squad, squads, tick, cells_per_second * tick_seconds, events)
			_rally(squad, squads, tick, tick_seconds, events)
			if one_per_cell:
				RoutSettle.settle(squad, squads, cells_per_second * tick_seconds, where)
		elif _breaks(squad):
			_break(squad, squads, tick, events, terrain)
	return events


## The world point a router stands at.
static func where(squad: SkirmishSquad, unit_id: int) -> Vector2:
	var entry: Dictionary = squad.fleeing[unit_id]
	return _route_point(squad, entry["along"]) + entry["offset"]


## Blows on routers this tick: any hostile front-rank unit within reach of a router strikes
## it from behind (a flank blow). [[attacker, target, damage, flank], ...]
static func blows(squads: Array, interval: int) -> Array:
	var out := []
	for routing in squads:
		if routing.state != SkirmishSquad.State.ROUTING:
			continue
		for hunter in squads:
			if hunter.faction_id == routing.faction_id or not FormationContact.can_engage(hunter):
				continue
			for fighter in hunter.fighters():
				var target := _router_in_reach(routing, fighter)
				if target == null:
					continue
				fighter.target_id = target.id
				fighter.attack_cooldown -= 1
				if fighter.attack_cooldown <= 0:
					fighter.attack_cooldown = interval
					out.append([fighter, target, FormationCombat.damage(fighter, true), true])
	return out


static func _router_in_reach(routing: SkirmishSquad, fighter: SkirmishUnit) -> SkirmishUnit:
	for unit in routing.living():
		if fighter.position.distance_to(where(routing, unit.id)) <= STRIKE_REACH:
			return unit
	return null


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
	squad: SkirmishSquad, squads: Array, tick: int, pace: float, events: Array
) -> void:
	var home := squad.home_distance * CELLS
	var panicked := {}
	for unit in squad.living():
		var entry: Dictionary = squad.fleeing[unit.id]
		if entry.get("caught", 0) > 0:
			continue  # held by a steady friend it ran into
		entry["along"] = move_toward(entry["along"], home, unit.speed * pace)
		_crush(squad, unit, squads, tick, panicked, events)
		if is_equal_approx(entry["along"], home):
			squad.units.erase(unit)
			squad.fleeing.erase(unit.id)
			var extra := {"unit": unit.id, "definition": unit.definition}
			events.append(FormationEvents.squad_event("fled_home", tick, squad, extra))
	if squad.living().is_empty():
		squad.state = SkirmishSquad.State.DESTROYED
		events.append(FormationEvents.squad_event("scattered", tick, squad))


static func _crush(
	squad: SkirmishSquad,
	router: SkirmishUnit,
	squads: Array,
	tick: int,
	panicked: Dictionary,
	events: Array
) -> void:
	var at := where(squad, router.id)
	for friend in squads:
		if friend == squad or friend.faction_id != squad.faction_id:
			continue
		if friend.state == SkirmishSquad.State.ROUTING:
			continue
		for unit in friend.living():
			if unit.position.distance_to(at) >= 1.0:
				continue
			var damage := CRUSH * router.footprint_width * router.footprint_depth
			router.hp -= damage
			unit.hp -= damage
			var extra := {"unit": router.id, "target": unit.id, "dmg": damage}
			events.append(FormationEvents.squad_event("crushed", tick, friend, extra))
			if not panicked.has(friend.id):
				panicked[friend.id] = true
				FormationMorale.shock(friend, PANIC, tick, events)
			return


static func _rally(
	squad: SkirmishSquad, squads: Array, tick: int, tick_seconds: float, events: Array
) -> void:
	for unit in squad.living():
		var at := where(squad, unit.id)
		var leader := _friend_near(squad, at, squads, true)
		if leader != null:
			_join(squad, unit, leader, tick, events)
			continue
		var entry: Dictionary = squad.fleeing[unit.id]
		var steady := _friend_near(squad, at, squads, false)
		entry["caught"] = 0 if steady == null else entry.get("caught", 0) + 1
		if steady != null and entry["caught"] * tick_seconds >= STEADY_RALLY_SECONDS:
			_join(squad, unit, steady, tick, events)
	if squad.living().is_empty() or FormationMorale.leadership(squad) == 0:
		return
	squad.rally_ticks = 0 if _enemy_near(squad, squads) else squad.rally_ticks + 1
	if squad.rally_ticks * tick_seconds >= RALLY_SECONDS:
		_reform(squad, tick, events)


## A friendly formation near `at`: one with a leader within RALLY_REACH (`led`), or a
## steady one within CAUGHT_REACH.
static func _friend_near(
	squad: SkirmishSquad, at: Vector2, squads: Array, led: bool
) -> SkirmishSquad:
	var reach := RALLY_REACH if led else CAUGHT_REACH
	for friend in squads:
		if friend == squad or friend.faction_id != squad.faction_id:
			continue
		if friend.state in [SkirmishSquad.State.ROUTING, SkirmishSquad.State.DESTROYED]:
			continue
		var fit := (
			FormationMorale.leadership(friend) >= 1
			if led
			else FormationMorale.band(friend) == FormationMorale.Band.STEADY
		)
		if not fit:
			continue
		for unit in friend.living():
			if unit.position.distance_to(at) <= reach:
				return friend
	return null


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


## Re-forms where its leader stands, facing the enemy's end again, and holds.
static func _reform(squad: SkirmishSquad, tick: int, events: Array) -> void:
	var leader: SkirmishUnit = null
	for unit in squad.living():
		if leader == null or unit.leadership > leader.leadership:
			leader = unit
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
