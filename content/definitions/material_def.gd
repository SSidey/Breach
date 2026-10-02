class_name MaterialDef
extends Resource
## One material in the shared terrain library (Decisions 54, 57, 63, 64): what strata and
## walls are made of, and liquids too - a material that flows is a liquid. Placeholder
## values, to tune.

const HeatTransitionDef = preload("res://content/definitions/heat_transition_def.gd")

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
## Load one cell of it puts on what is beneath (Decision 53).
@export var weight: int = 1
## Cells it can bridge unsupported before it falls (Decision 57).
@export var span: int = 1
## Load one eighth of a cell of it carries (Decision 65): an element carries strength x
## its eighths.
@export var strength: int = 0
## The heat it gives off, roughly °C: lava 1200, most things 15 (Decision 63).
@export var temperature: int = 15
## Trait id -> level (Decision 64), met in ability-and-demand pairs: dig_difficulty against
## a unit's burrower, climb_difficulty against climber; flows N makes it a liquid (N its
## rate); loose falls and settles; glows N lights its surroundings.
@export var traits: Dictionary = {}
## How it reacts to heat: timber gains "burning" above 300, rock becomes lava above 1100.
@export var heat_transitions: Array[HeatTransitionDef] = []


## A trait's level; 0 if it doesn't have it.
func trait_level(trait_id: String) -> int:
	return int(traits.get(trait_id, 0))


func is_liquid() -> bool:
	return trait_level("flows") > 0
