class_name LiquidDef
extends Resource
## One liquid in the shared terrain library (Decisions 62, 63): water, lava. Static for
## now - a body fills cells to a level, and a breach floods connected dug cells below it.

const HeatTransitionDef = preload("res://content/definitions/heat_transition_def.gd")

@export var id: String = ""
@export var display_name: String = ""
@export var color: Color = Color.WHITE
## The heat it gives off, roughly °C (lava 1200).
@export var temperature: int = 15
## Trait id -> level, e.g. {"glows": 1}.
@export var traits: Dictionary = {}
@export var heat_transitions: Array[HeatTransitionDef] = []
