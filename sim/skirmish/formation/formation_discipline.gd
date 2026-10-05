class_name FormationDiscipline
extends RefCounted
## A formation's discipline (Decision 92, spec 27 round 6): its units' mean discipline,
## bolstered by its best leader (Decision 81). It decides whether the formation re-forms as
## a whole to meet a flank closing in, how fast it re-forms - after a fight, to meet a
## threat, or to turn (a turn is a re-form) - and how far it, or a unit of it breaking
## ranks, pursues before coming back (Decisions 107 and 109). All numbers are placeholders
## until spec 28. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")

## What each point of leadership adds.
const PER_LEADERSHIP := 10
## At or above this a formation re-forms as a whole to meet a flank; below it, unit by unit.
const MEETS_THREATS := 50
## The discipline at which it re-forms at the march pace; the pace scales with it, within
## SLOWEST to FASTEST of the march pace.
const MARCH_PACE_AT := 50.0
const SLOWEST := 0.4
const FASTEST := 1.5
## The discipline a formation is expected to have at most; more is allowed but buys no more.
const EXPECTED_MAX := 100.0
## How far (cells) a pursuer may go from where it set out, step by step: the steadier, the
## shorter its leash (Decision 107); the last is no leash, while it can see its enemy.
const LEASH_STEPS := [16.0, 32.0, 64.0, 128.0, INF]
## The share of EXPECTED_MAX at or above which a pursuer takes LEASH_STEPS[1], [2] and [3];
## under the last, [4]. A leader's "pursues" tactic steps it one out, "cautious" one in.
const LEASH_SHARES := [0.75, 0.5, 0.25]


static func of(squad: SkirmishSquad) -> int:
	var living := squad.living()
	if living.is_empty():
		return 0
	var total := 0
	for unit in living:
		total += unit.discipline
	var mean := roundi(float(total) / living.size())
	return mean + PER_LEADERSHIP * FormationMorale.leadership(squad)


static func meets_threats(squad: SkirmishSquad) -> bool:
	return of(squad) >= MEETS_THREATS


## How fast its units walk to new places, as a share of the march pace.
static func reform_pace(squad: SkirmishSquad) -> float:
	return clampf(of(squad) / MARCH_PACE_AT, SLOWEST, FASTEST)


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
	return unit.discipline + PER_LEADERSHIP * FormationMorale.leadership(squad)


## How far (cells from where it broke ranks) a unit chases on its own: the step of its own
## discipline, bolstered by its leader (Decisions 109 and 112).
static func unit_leash(squad: SkirmishSquad, unit: SkirmishUnit) -> float:
	return _leash(unit_discipline(squad, unit), 0)


static func _leash(discipline: float, shift: int) -> float:
	var step := LEASH_SHARES.size() + 1
	for index in range(LEASH_SHARES.size()):
		if discipline / EXPECTED_MAX >= LEASH_SHARES[index]:
			step = index + 1
			break
	return LEASH_STEPS[clampi(step + shift, 0, LEASH_STEPS.size() - 1)]
