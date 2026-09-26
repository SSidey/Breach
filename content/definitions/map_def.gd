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

## Additive, per specs/13-faction-def-and-garrison-unit.md. sim/'s existing ad-hoc
## String ownership is not migrated to this - that's separate, future work.
@export var faction_relations: Array[FactionRelationDef] = []

## The map's faction roster, per specs/13-faction-def-and-garrison-unit.md -
## real author-definable content, not a closed enum. Includes the player's own
## entry; "player" is authoring convention (an id like any other), not a hardcoded
## special case.
@export var factions: Array[FactionDef] = []

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
	var faction_ids := _all_faction_ids()
	errors.append_array(_validate_edges(node_ids))
	errors.append_array(_validate_node_references(node_ids, faction_ids))
	errors.append_array(_validate_faction_relations(faction_ids))

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


func _validate_node_references(node_ids: Dictionary, faction_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for lane in lanes:
		for node in lane.nodes:
			if (
				not node.owning_faction_id.is_empty()
				and not faction_ids.has(node.owning_faction_id)
			):
				errors.append(
					(
						"node '%s' owning_faction_id references unknown faction id '%s'"
						% [node.id, node.owning_faction_id]
					)
				)
			errors.append_array(_validate_garrison_units(node, node_ids, faction_ids))
	return errors


func _validate_garrison_units(
	node: NodeDef, node_ids: Dictionary, faction_ids: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	for unit in node.garrison_units:
		if not unit.faction_id.is_empty() and not faction_ids.has(unit.faction_id):
			errors.append(
				(
					"node '%s' garrison unit references unknown faction id '%s'"
					% [node.id, unit.faction_id]
				)
			)
		for stop_id in unit.patrol_route:
			if not node_ids.has(stop_id):
				errors.append(
					(
						"node '%s' garrison unit patrol_route references unknown node id '%s'"
						% [node.id, stop_id]
					)
				)
		if not unit.delivery_target_id.is_empty() and not node_ids.has(unit.delivery_target_id):
			errors.append(
				(
					"node '%s' garrison unit delivery_target_id references unknown node id '%s'"
					% [node.id, unit.delivery_target_id]
				)
			)
	return errors


func _validate_faction_relations(faction_ids: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_pairs := {}
	for relation in faction_relations:
		for relation_error in relation.validate():
			errors.append(relation_error)
		if not faction_ids.has(relation.faction_a_id):
			errors.append("relation references unknown faction_a_id '%s'" % relation.faction_a_id)
		if not faction_ids.has(relation.faction_b_id):
			errors.append("relation references unknown faction_b_id '%s'" % relation.faction_b_id)
		var pair_key := _canonical_pair_key(relation.faction_a_id, relation.faction_b_id)
		if seen_pairs.has(pair_key):
			errors.append(
				(
					"duplicate faction relation between '%s' and '%s'"
					% [relation.faction_a_id, relation.faction_b_id]
				)
			)
		seen_pairs[pair_key] = true
	return errors


func _all_node_ids() -> Dictionary:
	var ids := {}
	for lane in lanes:
		for node in lane.nodes:
			ids[node.id] = true
	return ids


func _all_faction_ids() -> Dictionary:
	var ids := {}
	for faction in factions:
		ids[faction.id] = true
	return ids


func _canonical_pair_key(node_a_id: String, node_b_id: String) -> String:
	return (
		"%s|%s" % [node_a_id, node_b_id]
		if node_a_id <= node_b_id
		else "%s|%s" % [node_b_id, node_a_id]
	)
