class_name FormationDiscipline
extends RefCounted
## A formation's discipline (Decision 92, spec 27 round 6): its units' mean discipline,
## bolstered by its best leader (Decision 81). It decides whether the formation re-forms as
## a whole to meet a flank closing in, how fast it re-forms - after a fight, to meet a
## threat, or to turn (a turn is a re-form) - and how far it pursues before it comes back
## to the post it held (Decision 107). All numbers are placeholders until spec 28. Pure.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const FormationMorale = preload("res://sim/skirmish/formation/formation_morale.gd")

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
## [share of EXPECTED_MAX at or above which, cells from its post it pursues]: the steadier,
## the shorter its leash; under the last it pursues as long as it can see its enemy.
const LEASHES := [[0.75, 32.0], [0.5, 64.0], [0.25, 128.0]]


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


## How far (cells from the post it held) it pursues before it gives up: INF for one too
## undisciplined to leash at all.
static func pursuit_leash(squad: SkirmishSquad) -> float:
	var share := of(squad) / EXPECTED_MAX
	for tier in LEASHES:
		if share >= tier[0]:
			return tier[1]
	return INF
