class_name FormationDiscipline
extends RefCounted
## A formation's discipline (Decision 92, spec 27 round 6): its units' mean discipline,
## bolstered by its best leader (Decision 81). It decides whether the formation re-forms as
## a whole to meet a flank closing in, and how fast it re-forms - after a fight, to meet a
## threat, or to turn (a turn is a re-form). All numbers are placeholders until spec 28.
## Pure.

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
