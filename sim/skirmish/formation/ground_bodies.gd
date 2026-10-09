class_name GroundBodies
extends RefCounted
## Bodies on the ground (Decision 121, spec 28 part 6): the downed and the dead lie where
## they fell, no longer bodies that push (UnitBodies) but obstacles a marching formation's
## front must step over - slowed by the weight of what it crosses against its own (a grem
## over a grem by half, bodies_ground_drag), and blocked by one at least
## bodies_ground_block times its mass. Every unit walking to its place, or loose in a
## fight, is slowed the same way (underfoot). Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const SkirmishSquad = preload("res://sim/skirmish/formation/skirmish_squad.gd")
const SkirmishUnit = preload("res://sim/skirmish/skirmish_unit.gd")
const ScrumReach = preload("res://sim/skirmish/formation/scrum_reach.gd")
const UnitMotion = preload("res://sim/skirmish/formation/unit_motion.gd")

const LYING := [SkirmishUnit.State.DOWNED, SkirmishUnit.State.DEAD]


## The share (0 to 1) of its pace the squad keeps this tick for the bodies its front rank
## is stepping over.
static func drag(squad: SkirmishSquad, squads: Array) -> float:
	var lying := lying_in(squads)
	if lying.is_empty():
		return 1.0
	var ahead := UnitMotion.vector(squad.heading) * 0.5
	var worst := 1.0
	for walker in squad.fighters():
		worst = minf(worst, underfoot(walker, walker.position + ahead, lying))
	return worst


## The bodies lying on the field: the downed and the dead.
static func lying_in(squads: Array) -> Array:
	var lying := []
	for other in squads:
		for unit in other.units:
			if LYING.has(unit.state):
				lying.append(unit)
	return lying


## The share (0 to 1) of its pace `walker` keeps stepping onto `step` over `lying` bodies
## (spec 30 round 3: every unit that walks, in its place or loose): slowed by the weight
## of what it crosses against its own, blocked by one bodies_ground_block times its mass.
static func underfoot(walker: SkirmishUnit, step: Vector2, lying: Array) -> float:
	var tuning := BattleTuning.current()
	var own := float(walker.footprint_width * walker.footprint_depth)
	var worst := 1.0
	for body in lying:
		var reach := ScrumReach.radius(walker) + ScrumReach.radius(body)
		if body == walker or body.position.distance_to(step) >= reach:
			continue
		var weight: float = body.footprint_width * body.footprint_depth / own
		if weight >= tuning.bodies_ground_block:
			return 0.0
		worst = minf(worst, 1.0 / (1.0 + weight * tuning.bodies_ground_drag))
	return worst
