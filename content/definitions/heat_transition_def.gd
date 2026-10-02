class_name HeatTransitionDef
extends Resource
## How a material reacts to heat (Decisions 63, 66): above (rising) or below a heat level
## (0-10) it becomes another material, or gains a trait. Timber gains "burning" above
## heat 3; rock becomes lava above 7; lava becomes rock below 6.

## A heat level 0-10, placeholders to tune.
@export var threshold: int = 0
## True = once hotter than threshold; false = once cooler.
@export var rising: bool = true
## A material or liquid id; "" = stays what it is.
@export var becomes: String = ""
## A trait it gains; "" = none.
@export var gains_trait: String = ""


## The rule in words: "above heat 3: gains burning".
func describe() -> String:
	var outcome := "becomes %s" % becomes if becomes else "gains %s" % gains_trait
	return "%s heat %d: %s" % ["above" if rising else "below", threshold, outcome]
