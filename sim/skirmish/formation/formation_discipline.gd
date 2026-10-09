class_name FormationDiscipline
extends RefCounted
## A formation's discipline (Decision 92, spec 27 round 6): its units' mean discipline,
## bolstered by its best leader (Decision 81). It decides whether the formation re-forms as
## a whole to meet a flank closing in, how fast it re-forms - after a fight, to meet a
## threat, or to turn (a turn is a re-form) - and how far it, or a unit of it breaking
## ranks, pursues before coming back (Decisions 107 and 109). Its numbers are BattleTuning's
## (`discipline_*`). Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const BattleTuning = preload("res://content/definitions/battle_tuning.gd")


static func of(squad: SkirmishSquad) -> int:
	var living := squad.living()
	if living.is_empty():
		return 0
	var total := 0
	for unit in living:
		total += unit.discipline
	var mean := roundi(float(total) / living.size())
	return mean + _tuning().discipline_per_leadership * FormationMorale.leadership(squad)


static func meets_threats(squad: SkirmishSquad) -> bool:
	return of(squad) >= _tuning().discipline_meets_threats


## How fast its units walk to new places, as a share of the march pace.
static func reform_pace(squad: SkirmishSquad) -> float:
	var tuning := _tuning()
	return clampf(
		of(squad) / tuning.discipline_march_pace_at,
		tuning.discipline_slowest,
		tuning.discipline_fastest
	)


## How far (cells from the post it held) the formation pursues before it gives up: its
## discipline's step, moved by its leaders' tactics; INF for no leash.
static func pursuit_leash(squad: SkirmishSquad) -> float:
	var shift := 0
	for tactic in [["pursues", 1], ["cautious", -1]]:
		if squad.living().any(func(u): return u.tactics.has(tactic[0])):
			shift += tactic[1]
	return _leash(of(squad), shift)


## A unit's own discipline, bolstered as its formation's is by its best leader: what holds
## it in the ranks (Decisions 81 and 112).
static func unit_discipline(squad: SkirmishSquad, unit: SkirmishUnit) -> int:
	return unit.discipline + _tuning().discipline_per_leadership * FormationMorale.leadership(squad)


## How far (cells from where it broke ranks) a unit chases on its own: the step of its own
## discipline, bolstered by its leader (Decisions 109 and 112).
static func unit_leash(squad: SkirmishSquad, unit: SkirmishUnit) -> float:
	return _leash(unit_discipline(squad, unit), 0)


static func _leash(discipline: float, shift: int) -> float:
	var shares := _tuning().discipline_leash_shares
	var steps := _tuning().discipline_leash_steps
	var step := shares.size() + 1
	for index in range(shares.size()):
		if discipline / _tuning().discipline_expected_max >= shares[index]:
			step = index + 1
			break
	return steps[clampi(step + shift, 0, steps.size() - 1)]


static func _tuning() -> BattleTuning:
	return BattleTuning.current()
