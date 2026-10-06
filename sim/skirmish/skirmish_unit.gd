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
## Formation sim: its sheet as it stands now (Decision 117) - archetype tags, attributes
## (UnitDef.ATTRIBUTES, name -> value) and rated traits (name -> level) - copied from its
## definition, so tech, items and ranks can change one unit and not its type.
var tags: Array[String] = []
var attributes := {}
var traits := {}
## Formation sim: how quickly it acts, and how drilled it is (Decisions 88 and 92).
var initiative := 10
var discipline := 30
## Formation sim: the bearing it faces, in degrees clockwise from north (UnitMotion: 90
## east) - its squad's way, or its own in the scrum - and how it turns and backs away.
var bearing := 90.0
var turn_rate := 450.0
var backward_pace := 0.4
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
## Formation sim: its skills, defence and critical multiplier, and whether it can parry
## (Decision 118, UnitDef).
var melee_skill := 40
var ranged_skill := 40
var defence := 10
var critical := 1.5
var parries := false
## Formation sim: what its blows are made of and what stands against them (Decision 119,
## UnitArms): its melee and ranged weapons' parts [[damage, type, magical], ...], their
## floor shares, its weaknesses, resistances and immunities, and its armour and ward.
var melee_parts := []
var ranged_parts := []
var melee_floor := 1.0
var ranged_floor := 1.0
var weaknesses: Array[String] = []
var resistances: Array[String] = []
var immunities: Array[String] = []
var armour := 0
var ward := 0
## Seconds between its melee blows and its ranged shots (Decision 120): its weapons'
## intervals, scaled by its attack speed.
var melee_seconds := 1.0
var ranged_seconds := 1.0


func is_alive() -> bool:
	return state != State.DEAD


func is_hostile_to(other: SkirmishUnit) -> bool:
	return other.faction_id != faction_id
