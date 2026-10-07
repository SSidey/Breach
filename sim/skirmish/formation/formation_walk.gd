class_name FormationWalk
extends RefCounted
## Units walk to their places (spec 30 round 3, part 2): a formation's frame is a set of
## places, not positions. Every unit in its place - not loose in a fight, nor fleeing -
## walks to it each tick at its own pace on the ground it crosses, as loose units do: a
## wheel's outer file walks the arc, a re-form walks, a unit pushed aside walks back. Far
## from its place it faces where it walks; near it, its formation's way, stepping sideways
## or back. The frame keeps within a slack of its units (share): it slows as a unit lags
## towards what its formation's discipline allows (walk_slack_drilled to walk_slack_loose)
## and waits beyond it, unless that unit has fallen behind (walk_lost) - then only "no man
## left behind" waits for it; under "fall behind, left behind" it never waits. Placing a
## squad sets its units on their places (FormationMarch.sync_units). Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")
const FormationDiscipline = preload("res://sim/skirmish/formation/formation_discipline.gd")
const FormationTerrain = preload("res://sim/skirmish/formation/formation_terrain.gd")
const FormationShuffle = preload("res://sim/skirmish/formation/formation_shuffle.gd")
const SquadFrame = preload("res://sim/skirmish/formation/squad_frame.gd")

const EPSILON := 0.000001


## Walks `unit` of `squad` a tick of `seconds` towards `place`, at `pace` cells a second
## for speed 1 on open ground, on `terrain` (null: open).
static func walk(
	squad: SkirmishSquad,
	unit: SkirmishUnit,
	place: Vector2,
	timing: Array,
	terrain: FormationTerrain = null
) -> void:
	var seconds: float = timing[0]
	var way := place - unit.position
	var full: float = unit.speed * timing[1] * seconds
	if terrain != null and way.length() > EPSILON:
		var ahead := unit.position + way.normalized()
		full *= terrain.factor(unit.height, unit.position, ahead)
	var facing := UnitMotion.vector(squad.heading)
	var look := place if way.length() > _tuning().walk_face_travel else place + facing
	unit.position = UnitMotion.walk(unit, unit.position, place, full, seconds, look)


## Where `unit` belongs in its squad's frame now, including any swap under way.
static func place_of(squad: SkirmishSquad, unit: SkirmishUnit) -> Vector2:
	var swapping := FormationShuffle.offset(squad, unit)
	var ahead := UnitMotion.vector(squad.heading)
	var shift := ahead * swapping.x - ahead.orthogonal() * swapping.y
	var at := SquadFrame.place(squad.position, squad.heading, squad.width, squad.centre_shift, unit)
	return at + shift


## The share (0 to 1) of its step the squad's frame takes this tick for its units lagging
## behind their places: all of it while every unit is within half its slack, easing to
## none as the furthest nears the slack itself, so a wheel slows to what its outer file
## can walk rather than halting; one fallen behind (walk_lost) is waited for only if no
## man is left behind.
static func share(squad: SkirmishSquad) -> float:
	var rule := rule_of(squad)
	if rule == "fall_behind_left_behind":
		return 1.0
	var slack := slack_of(squad)
	var furthest := 0.0
	for unit in squad.living():
		if squad.loose.has(unit.id) or squad.fleeing.has(unit.id):
			continue
		var lag := unit.position.distance_to(place_of(squad, unit))
		if lag <= _tuning().walk_lost or rule == "no_man_left_behind":
			furthest = maxf(furthest, lag)
	return clampf((slack - furthest) / (slack / 2.0), 0.0, 1.0)


## True if the squad's frame waits this tick for a unit lagging behind its place.
static func waits(squad: SkirmishSquad) -> bool:
	return share(squad) <= EPSILON


## How far (cells) a unit of the squad may lag behind its place before the frame waits.
static func slack_of(squad: SkirmishSquad) -> float:
	var tuning := _tuning()
	var drilled := clampf(FormationDiscipline.of(squad) / 100.0, 0.0, 1.0)
	return lerpf(tuning.walk_slack_loose, tuning.walk_slack_drilled, drilled)


## "fall_behind_left_behind", "no_man_left_behind" or "": a leader's trait, or one every
## unit has (the never-wait wins if both are found).
static func rule_of(squad: SkirmishSquad) -> String:
	var living := squad.living()
	for trait_id in ["fall_behind_left_behind", "no_man_left_behind"]:
		var led := living.any(func(u): return u.leadership > 0 and u.traits.has(trait_id))
		var all := not living.is_empty() and living.all(func(u): return u.traits.has(trait_id))
		if led or all:
			return trait_id
	return ""


static func _tuning() -> BattleTuning:
	return BattleTuning.current()
