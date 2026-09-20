class_name MapDef
extends Resource
## Map topology and tuning definition (lane graph, tick timing, suspicion ladder). See
## specs/07-data-resource-schemas.md and specs/00-scope-and-map.md.

@export var nodes: Array[NodeDef] = []
@export var tick_duration_seconds: float = 0.0

## Ascending thresholds for Wary/Alarmed/Mobilized/Full Alert (Decision 5).
@export var suspicion_tier_thresholds: Array[int] = []
@export var suspicion_decay_per_tick: int = 0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if nodes.size() < 2:
		errors.append("nodes must contain at least 2 entries, got %d" % nodes.size())

	if tick_duration_seconds <= 0.0:
		errors.append("tick_duration_seconds must be > 0, got %f" % tick_duration_seconds)

	for i in range(1, suspicion_tier_thresholds.size()):
		if suspicion_tier_thresholds[i] <= suspicion_tier_thresholds[i - 1]:
			errors.append(
				(
					"suspicion_tier_thresholds must be strictly ascending, got %s"
					% [suspicion_tier_thresholds]
				)
			)
			break

	for node in nodes:
		for node_error in node.validate():
			errors.append(node_error)

	return errors
