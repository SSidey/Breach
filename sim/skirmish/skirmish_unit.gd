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
## Formation sim: the centre of the unit's cells on the map (spec 27).
var position := Vector2.ZERO
## Formation sim: how far it detects others, in cells (Decision 87).
var detection := 40.0
## Formation sim: its courage and leadership (Decisions 81 and 82).
var courage := 60
var leadership := 0
var tactics: Array[String] = []
var height := 1.0
## Formation sim: the definition it was made from (a router fleeing home rejoins the
## reserve as one of these).
var definition: Resource = null
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

# Formation fields (specs/22-formation-feel-test.md); unused by the spec 21 SkirmishSimulation.
## The squad (wave) this unit marches in; 0 = none.
var squad_id: int = 0
## Row in its squad's formation, 0 = the front rank.
var rank: int = 0
## Leftmost formation column it covers.
var column: int = 0
## Slots it occupies, depth (ranks) x width (columns) - Decision 40.
var footprint_depth: int = 1
var footprint_width: int = 1
## UnitDef.Position band and claim within it (Decision 46).
var preferred_position: int = 0
var position_priority: int = 0
## From its best ranged weapon (Decision 47): reach in ranks (0 = melee only), damage, type.
## `dmg` is the unit's melee strike - all its melee weapons together.
var attack_range: int = 0
var ranged_dmg: int = 0
var damage_type: String = ""


func is_alive() -> bool:
	return state != State.DEAD


func is_hostile_to(other: SkirmishUnit) -> bool:
	return other.faction_id != faction_id
