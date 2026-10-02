class_name MaterialDef
extends Resource
## One material in the shared terrain library (Decisions 54 and 57): what strata are made
## of, and later what walls are built from. Placeholder values, to tune.

const HeatTransitionDef = preload("res://content/definitions/heat_transition_def.gd")

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
## Burrower level needed to dig it at full rate (Decision 54).
@export var dig_difficulty: int = 1
## Climber level needed to climb a face of it (Decision 54).
@export var climb_difficulty: int = 0
## Load one cell of it puts on what is beneath (Decision 53).
@export var weight: int = 1
## Cells it can bridge unsupported before it falls (Decision 57).
@export var span: int = 1
## Trait id -> level (Decision 63): "loose" falls into an open cell beneath and settles
## at its slope (sand, gravel, rubble).
@export var traits: Dictionary = {}
## How it reacts to heat: timber gains "burning" above 300, rock becomes lava above 1100.
@export var heat_transitions: Array[HeatTransitionDef] = []
