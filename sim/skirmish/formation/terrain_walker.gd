class_name TerrainWalker
extends RefCounted
## How a unit crosses terrain (spec 30 round 3, Decisions 64 and 85): its height, which
## sets the bands of liquid it wades; the share of its pace it swims at in water at least
## that deep (0: it can't swim); and its climber level, met against a cliff's demand by
## Decision 64's pair rule. FormationTerrain reads it for the pace of each step, so the
## march and paths can't disagree. Pure.

const BattleTuning = preload("res://content/definitions/battle_tuning.gd")
const UnitDef = preload("res://content/definitions/unit_def.gd")
const UnitArms = preload("res://content/definitions/unit_arms.gd")

## How tall it stands, in cells.
var height: float
## The share of its pace it swims at in water at least its height deep; 0 where it sinks.
var swim: float
## Its "climber" level: 0 can't climb.
var climber: int


func _init(unit_height: float, swim_share: float = 0.0, climber_level: int = 0) -> void:
	height = unit_height
	swim = swim_share
	climber = climber_level


## How a unit of `unit_def` crosses terrain: everyone swims, at the swim pace a "swimmer"
## raises - unless it "sinks", or carries more than the sinking load.
static func of(unit_def: UnitDef) -> TerrainWalker:
	var tuning := BattleTuning.current()
	var share := minf(
		1.0, tuning.ground_swim_pace + unit_def.trait_level("swimmer") * tuning.ground_swimmer_pace
	)
	if unit_def.trait_level("sinks") > 0 or _too_heavy_to_swim(unit_def):
		share = 0.0
	return TerrainWalker.new(unit_def.height, share, unit_def.trait_level("climber"))


## Decision 64's pair rule, an ability against a demand: the share of the pace it goes at
## - 1 meeting it, half one level short, 0 further short or without the ability at all.
static func meets(ability: int, demand: int) -> float:
	if ability <= 0 or ability < demand - 1:
		return 0.0
	return 1.0 if ability >= demand else 0.5


## Whether it carries more than ground_sink_share of the way through its first encumbrance
## band (from load_easy of its carry limit to the limit).
static func _too_heavy_to_swim(unit_def: UnitDef) -> bool:
	var tuning := BattleTuning.current()
	var limit := unit_def.strength * tuning.load_per_strength
	var easy := limit * tuning.load_easy
	return UnitArms.carried_weight(unit_def) > easy + (limit - easy) * tuning.ground_sink_share
