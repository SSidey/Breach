class_name ScrumRegroup
extends RefCounted
## Regrouping after a fight (Decisions 88 and 92, spec 27 rounds 5 and 6): units of squads
## out of the fight walk back to their places - in the squad's stance, if it holds one - at
## its re-form pace (FormationDiscipline), and rejoin its frame once in place - or as near
## as the press lets it get - and facing its way. A drilled retreat's units back away
## facing the foe they touch (a fighting withdrawal, Decision 95). Every squad's units
## face the foes they touched as the phase began, so no squad listed earlier moves first
## and changes what a later one sees (Decision 97). Chasers and withdrawing units are
## left to ScrumPursuit and FormationWithdraw. Pure over the squads it is given.

const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumBlows = preload("res://sim/skirmish/formation/scrum_blows.gd")
const ScrumPursuit = preload("res://sim/skirmish/formation/scrum_pursuit.gd")
const ScrumStance = preload("res://sim/skirmish/formation/scrum_stance.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const UnitShuffle = preload("res://sim/skirmish/formation/unit_shuffle.gd")
const FormationDiscipline = preload("res://sim/skirmish/formation/formation_discipline.gd")

## Cells a unit must close on its place in a tick to keep walking: one that gets no nearer
## (others' bodies hold it off) is as close as the press allows, and takes its place.
const PROGRESS := 0.001


## Units of squads out of the fight walk to their places (in the stance, if any) at the
## march pace; back in place they rejoin the squad's frame unless it holds a stance. A
## drilled retreat's units back away facing the foe each touched as the phase began.
static func step(squads: Array, pace: float, seconds: float, fight_seed: int) -> void:
	var regrouping := []
	for squad in squads:
		if squad.state in [SkirmishSquad.State.FIGHTING, SkirmishSquad.State.ROUTING]:
			continue
		if squad.state == SkirmishSquad.State.MOVING and not squad.loose.is_empty():
			squad.state = SkirmishSquad.State.HOLDING  # it stands while its units regroup
		regrouping.append([squad, _foes_faced(squad, squads, fight_seed)])
	for entry in regrouping:
		_walk_back(entry[0], entry[1], pace, seconds)


## unit id -> where the foe it touches stands, for a drilled retreat's units ({} for any
## other squad).
static func _foes_faced(squad: SkirmishSquad, squads: Array, fight_seed: int) -> Dictionary:
	var out := {}
	if squad.order != SkirmishUnit.Order.RETREAT or not FormationDiscipline.meets_threats(squad):
		return out
	var hostiles := ScrumBlows.hostile_units(squad, squads)
	for unit_id in squad.loose:
		var unit: SkirmishUnit = squad.loose[unit_id]["unit"]
		out[unit_id] = ScrumBlows.nearest_touching(squad, unit, hostiles, fight_seed)
	return out


static func _walk_back(squad: SkirmishSquad, foes: Dictionary, pace: float, seconds: float) -> void:
	for unit_id in squad.loose.keys():
		if ScrumPursuit.away(squad, unit_id):
			continue
		var entry: Dictionary = squad.loose[unit_id]
		var unit: SkirmishUnit = entry["unit"]
		var place := ScrumStance.anchor(squad, unit)
		var step := unit.speed * pace * FormationDiscipline.reform_pace(squad)
		var facing: int = squad.facing if squad.stance.is_empty() else squad.stance["facing"]
		var foe_at = foes.get(unit_id)
		if foe_at == null:  # it takes its place the quicker way, arriving facing its squad's
			foe_at = UnitShuffle.look(
				unit, entry["at"], place, UnitMotion.of_facing(facing), step / seconds
			)
		var gap: float = entry["at"].distance_to(place)
		var arrived: bool = gap < 0.000001 or gap > entry.get("gap", INF) - PROGRESS
		entry["gap"] = gap
		if gap >= 0.000001:  # a drilled retreat backs away facing the foe it touches
			entry["at"] = UnitMotion.walk(unit, entry["at"], place, step, seconds, foe_at)
		entry["next"] = entry["at"]
		entry["goal"] = null
		var faced := arrived and UnitMotion.turn(unit, UnitMotion.of_facing(facing), seconds)
		if squad.stance.is_empty() and faced:
			squad.loose.erase(unit_id)  # in its place and facing the squad's way
