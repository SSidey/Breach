class_name SkirmishUnit
extends RefCounted
## One unit in the real-time skirmish feel test (specs/21-realtime-skirmish-feel-test.md).
## Plain data; SkirmishSimulation owns every rule that changes it.

## The player's standing instruction. Applied by the simulation on the next tick.
enum Order { ADVANCE, HOLD, RETREAT }
## What the unit is doing right now (derived by the simulation each tick).
enum State { MOVING, HOLDING, FIGHTING, ARRIVED, DEAD }

var id: int = 0
var faction_id: String = ""
var hp: int = 0
var max_hp: int = 0
var dmg: int = 0
## Cells per second.
var speed: float = 0.0
## Cells along the route, from the player's end (0) to the kingdom's (route length).
var distance: float = 0.0
## Where this unit started: the end it retreats to.
var home_distance: float = 0.0
## +1 advances toward the kingdom's end, -1 toward the player's.
var advance_direction: int = 1
var order: Order = Order.ADVANCE
var state: State = State.MOVING
## The unit being fought; 0 = none.
var target_id: int = 0
var attack_cooldown: int = 0
## Ticks to stand still after spawning, so a wave leaves as a staggered group.
var wait_ticks: int = 0


func is_alive() -> bool:
	return state != State.DEAD


func is_hostile_to(other: SkirmishUnit) -> bool:
	return other.faction_id != faction_id
