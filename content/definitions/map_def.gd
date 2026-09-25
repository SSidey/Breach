class_name MapDef
extends Resource
## Map topology and tuning definition (lanes, tick timing, suspicion ladder). See
## specs/07-data-resource-schemas.md, specs/00-scope-and-map.md, and
## specs/09-node-graph-and-lanes.md.

## Phase 4 item 2: nodes: Array[NodeDef] (one implicit global lane) replaced by
## lanes: Array[LaneDef] (each an explicitly ordered node sequence) - see
## specs/09-node-graph-and-lanes.md for why.
@export var lanes: Array[LaneDef] = []
@export var tick_duration_seconds: float = 0.0

## Ascending thresholds for Wary/Alarmed/Mobilized/Full Alert (Decision 5).
@export var suspicion_tier_thresholds: Array[int] = []
@export var suspicion_decay_per_tick: int = 0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if lanes.is_empty():
		errors.append("lanes must contain at least 1 entry, got %d" % lanes.size())

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

	for lane in lanes:
		for lane_error in lane.validate():
			errors.append(lane_error)

	return errors
