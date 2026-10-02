class_name HeatTransitionDef
extends Resource
## How a material or liquid reacts to heat (Decision 63): above (rising) or below a
## temperature it becomes another material or liquid, or gains a trait. Timber gains
## "burning" above 300; rock becomes lava above 1100; lava becomes rock below 700.

## Roughly °C, placeholders to tune.
@export var threshold: int = 0
## True = once hotter than threshold; false = once cooler.
@export var rising: bool = true
## A material or liquid id; "" = stays what it is.
@export var becomes: String = ""
## A trait it gains; "" = none.
@export var gains_trait: String = ""


## The rule in words: "above 300: gains burning".
func describe() -> String:
	var outcome := "becomes %s" % becomes if becomes else "gains %s" % gains_trait
	return "%s %d: %s" % ["above" if rising else "below", threshold, outcome]
