class_name ScrumPursuit
extends RefCounted
## Retreat and pursuit (Decision 95, spec 27 round 8). When a formation is ordered to
## retreat out of a fight:
## - **The retreat:** its locks end at once (it turns for home as a re-form, ScrumTurn). A
##   drilled formation (Decision 92) makes a fighting withdrawal - it steps its formation
##   back WITHDRAW_CELLS, its units backing away facing the enemy they touch and striking
##   back, then turns. A ragged one turns and runs, and pays a
##   scaled rout: a morale shock in proportion to how far short of drilled it is.
## - **Its enemies:** any of their units still touching it strike it as it goes
##   (ScrumBlows). A formation ordered to pursue, or led by a leader with the "pursues"
##   tactic (Decision 81), follows it as a whole, then returns to its post
##   (FormationPursuit). Otherwise it returns to formation, though each of its units may
##   break ranks to chase a little way first: decided per unit, by its discipline and a
##   seeded roll, for CHASE_SECONDS.
## Squads keep `pursues` and `chasers` (unit id -> {"foe", "until"}). Pure over the squads.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const BattleRolls = preload("res://sim/skirmish/formation/battle_rolls.gd")
const FormationDiscipline = preload("res://sim/skirmish/formation/formation_discipline.gd")
const FormationLocks = preload("res://sim/skirmish/formation/formation_locks.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const FormationEvents = preload("res://sim/skirmish/formation/formation_events.gd")
const MapLayoutDef = preload("res://content/definitions/map_layout_def.gd")
const ScrumTurn = preload("res://sim/skirmish/formation/scrum_turn.gd")
const FormationPursuit = preload("res://sim/skirmish/formation/formation_pursuit.gd")

## How far (cells) a drilled withdrawal steps its formation back before turning.
const WITHDRAW_CELLS := 3.0
## The scaled rout of a ragged retreat: up to this much shock, for a formation with no
## discipline at all (placeholder).
const RAGGED_SHOCK := 20
## A unit breaks ranks to chase with a chance of (DRILLED - its discipline) / 100, chasing
## for this long (placeholders).
const CHASE_SECONDS := 2.0
## How near (cells) a unit must stand to a retreating enemy to be tempted to chase.
const TEMPTED_WITHIN := 2.0


## Applies a retreat order to `squad`: ends its fight, costs a ragged one its scaled rout,
## and sets its enemies pursuing or chasing. Returns events.
static func retreat(
	squad: SkirmishSquad, squads: Array, tick: int, battle_seed: int, seconds: float
) -> Array:
	var events := []
	var enemies := squads.filter(func(s): return _fights(s, squad))
	FormationLocks.release(squad, squads)
	events.append(FormationEvents.squad_event("disengaged", tick, squad))
	var discipline := FormationDiscipline.of(squad)
	if discipline >= FormationDiscipline.MEETS_THREATS:
		_pull_back(squad)
	else:
		var short := 1.0 - float(discipline) / FormationDiscipline.MEETS_THREATS
		FormationMorale.shock(squad, roundi(RAGGED_SHOCK * short), tick, events)
		ScrumTurn.begin(squad, -squad.direction, tick, events)  # it turns and runs at once
	for enemy in enemies:
		if pursues(enemy):
			FormationPursuit.begin(enemy, squad, tick, events)
		else:
			_tempt(enemy, squad, tick, battle_seed, roundi(CHASE_SECONDS / seconds))
	return events


## A drilled withdrawal first steps its formation back out of reach, its units backing to
## their places facing the enemy, before it turns for home.
static func _pull_back(squad: SkirmishSquad) -> void:
	var back := WITHDRAW_CELLS / MapLayoutDef.CELLS_PER_TILE
	var home: float = squad.home_distance
	var stepped: float = squad.front_distance - squad.direction * back
	var lowest := minf(home, squad.front_distance)
	var highest := maxf(home, squad.front_distance)
	squad.front_distance = clampf(stepped, lowest, highest)


## True if the squad pursues a retreating enemy: ordered to, or led by a pursuer.
static func pursues(squad: SkirmishSquad) -> bool:
	return squad.pursues or squad.living().any(func(u): return u.tactics.has("pursues"))


## One tick of chasing: each chaser walks at the march pace after the nearest unit of the
## enemy it chases; when its time is up, or that enemy is gone, it returns to its place.
static func step(squads: Array, tick: int, cells_per_second: float, seconds: float) -> void:
	var by_id := {}
	for entry in squads:
		by_id[entry.id] = entry
	for squad in squads:
		for unit_id in squad.chasers.keys():
			var chase: Dictionary = squad.chasers[unit_id]
			var foe: SkirmishSquad = by_id.get(chase["foe"])
			var unit: SkirmishUnit = chase["unit"]
			if tick > chase["until"] or foe == null or foe.is_destroyed() or not unit.is_alive():
				squad.chasers.erase(unit_id)
				continue
			var entry: Dictionary = squad.loose[unit_id]
			var target := _nearest(entry["at"], foe)
			var full := unit.speed * cells_per_second * seconds
			entry["at"] = UnitMotion.walk(unit, entry["at"], target, full, seconds)
			entry["next"] = entry["at"]


## True if the squad's unit is out chasing (its squad leaves it out of regrouping).
static func chasing(squad: SkirmishSquad, unit_id: int) -> bool:
	return squad.chasers.has(unit_id)


static func _fights(other: SkirmishSquad, squad: SkirmishSquad) -> bool:
	if other.faction_id == squad.faction_id:
		return false
	var flanking: bool = other.flank_contacts.values().any(func(c): return c["foe"] == squad.id)
	return other.engaged_with == squad.id or squad.engaged_with == other.id or flanking


## Each of the enemy's units near the retreating squad may break ranks to chase it.
static func _tempt(
	enemy: SkirmishSquad, squad: SkirmishSquad, tick: int, battle_seed: int, ticks: int
) -> void:
	for unit in enemy.living():
		var at := ScrumReach.at(enemy, unit)
		if _nearest(at, squad).distance_to(at) > TEMPTED_WITHIN:
			continue
		var chance := float(FormationDiscipline.MEETS_THREATS - unit.discipline) / 100.0
		if BattleRolls.uniform(battle_seed, [tick, unit.id, "chase"]) >= chance:
			continue
		if not enemy.loose.has(unit.id):
			enemy.loose[unit.id] = {"unit": unit, "at": at, "goal": null, "next": at}
		enemy.chasers[unit.id] = {"unit": unit, "foe": squad.id, "until": tick + ticks}


static func _nearest(at: Vector2, squad: SkirmishSquad) -> Vector2:
	var best := at
	var gap := INF
	for unit in squad.living():
		var there := ScrumReach.at(squad, unit)
		if there.distance_to(at) < gap:
			gap = there.distance_to(at)
			best = there
	return best
