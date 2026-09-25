class_name MapDef
extends Resource
## Map topology and tuning definition (lanes, tick timing, suspicion ladder). See
## specs/07-data-resource-schemas.md, specs/00-scope-and-map.md, and
## specs/09-node-graph-and-lanes.md.

## Phase 4 item 2: nodes: Array[NodeDef] (one implicit global lane) replaced by
## lanes: Array[LaneDef] (each an explicitly ordered node sequence) - see
## specs/09-node-graph-and-lanes.md for why.
@export var lanes: Array[LaneDef] = []

## Explicit extra connections beyond each lane's own implied path, per
## specs/11-graph-topology-edges.md. The map's full adjacency graph is the union of
## each LaneDef's own consecutive-node edges and these. Defaults empty - zero
## behavior change for any map that doesn't use branching.
@export var edges: Array[MapEdgeDef] = []

## Additive, per specs/12-node-schema-round-3.md. sim/'s existing ad-hoc String
## ownership is not migrated to FactionId here - that's separate, future work.
@export var faction_relations: Array[FactionRelationDef] = []

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

	errors.append_array(_validate_suspicion_thresholds())
	errors.append_array(_validate_lanes())

	var node_ids := _all_node_ids()
	errors.append_array(_validate_edges(node_ids))
	errors.append_array(_validate_node_references(node_ids))
	errors.append_array(_validate_faction_relations())

	return errors


func _validate_suspicion_thresholds() -> PackedStringArray:
	var errors := PackedStringArray()
	for i in range(1, suspicion_tier_thresholds.size()):
		if suspicion_tier_thresholds[i] <= suspicion_tier_thresholds[i - 1]:
			errors.append(
				(
					"suspicion_tier_thresholds must be strictly ascending, got %s"
					% [suspicion_tier_thresholds]
				)
			)
			break
	return errors


func _validate_lanes() -> PackedStringArray:
	var errors := PackedStringArray()
	for lane in lanes:
		for lane_error in lane.validate():
			errors.append(lane_error)
	return errors


func _validate_edges(node_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_pairs := {}
	for edge in edges:
		for edge_error in edge.validate():
			errors.append(edge_error)
		if not node_ids.has(edge.node_a_id):
			errors.append("edge references unknown node_a_id '%s'" % edge.node_a_id)
		if not node_ids.has(edge.node_b_id):
			errors.append("edge references unknown node_b_id '%s'" % edge.node_b_id)
		var pair_key := _canonical_pair_key(edge.node_a_id, edge.node_b_id)
		if seen_pairs.has(pair_key):
			errors.append("duplicate edge between '%s' and '%s'" % [edge.node_a_id, edge.node_b_id])
		seen_pairs[pair_key] = true
	return errors


func _validate_node_references(node_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for lane in lanes:
		for node in lane.nodes:
			for stop_id in node.patrol_route:
				if not node_ids.has(stop_id):
					errors.append(
						(
							"node '%s' patrol_route references unknown node id '%s'"
							% [node.id, stop_id]
						)
					)
			if not node.delivery_target_id.is_empty() and not node_ids.has(node.delivery_target_id):
				errors.append(
					(
						"node '%s' delivery_target_id references unknown node id '%s'"
						% [node.id, node.delivery_target_id]
					)
				)
	return errors


func _validate_faction_relations() -> PackedStringArray:
	var errors := PackedStringArray()
	for relation in faction_relations:
		for relation_error in relation.validate():
			errors.append(relation_error)
	return errors


func _all_node_ids() -> Dictionary:
	var ids := {}
	for lane in lanes:
		for node in lane.nodes:
			ids[node.id] = true
	return ids


func _canonical_pair_key(node_a_id: String, node_b_id: String) -> String:
	return (
		"%s|%s" % [node_a_id, node_b_id]
		if node_a_id <= node_b_id
		else "%s|%s" % [node_b_id, node_a_id]
	)
