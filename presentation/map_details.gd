class_name MapDetails
extends RefCounted
## The map viewer's info-panel text (BBCode), per specs/18-map-viewer.md. Pure and
## read-only over content/, so it's tested headlessly.

const NodeDef = preload("res://content/definitions/node_def.gd")


static func summary(map_def: MapDef) -> String:
	var ids := {}
	for lane in map_def.lanes:
		for node in lane.nodes:
			ids[node.id] = true
	var on_lane := ids.size()
	for node in map_def.off_lane_nodes:
		ids[node.id] = true
	return (
		"[b]%s[/b]\n%s · %s · %s · %d off-lane\n%s"
		% [
			map_def.resource_path.get_file().get_basename(),
			_count(ids.size(), "node"),
			_count(map_def.lanes.size(), "lane"),
			_count(map_def.edges.size(), "edge"),
			ids.size() - on_lane,
			"Factions: " + ", ".join(map_def.factions.map(func(f): return f.id)),
		]
	)


static func node_details(map_def: MapDef, node_id: String) -> String:
	var node := _find(map_def, node_id)
	if node == null:
		return "Node '%s' not found." % node_id
	var lines := PackedStringArray()
	lines.append("[b]%s[/b]  %s" % [node.id, NodeDef.NodeType.keys()[node.node_type]])
	lines.append("owner: %s" % (node.owning_faction_id if node.owning_faction_id else "none"))
	lines.append("garrison %d" % maxi(node.garrison, node.garrison_units.size()))
	for unit in node.garrison_units:
		lines.append("  · unit of %s" % (unit.faction_id if unit.faction_id else "?"))
	if node.node_type == NodeDef.NodeType.RESOURCE:
		lines.append(
			(
				"%s, %d/tick"
				% [NodeDef.ResourceType.keys()[node.resource_type], node.yield_food_per_tick]
			)
		)
	if not node.hidden_from_faction_ids.is_empty():
		lines.append("hidden from %s" % ", ".join(node.hidden_from_faction_ids))
	var lanes := PackedStringArray()
	for lane in map_def.lanes:
		if lane.nodes.has(node):
			lanes.append(lane.id)
	lines.append("lanes: %s" % ", ".join(lanes) if not lanes.is_empty() else "off-lane")
	return "\n".join(lines)


static func _find(map_def: MapDef, node_id: String) -> NodeDef:
	for lane in map_def.lanes:
		for node in lane.nodes:
			if node.id == node_id:
				return node
	for node in map_def.off_lane_nodes:
		if node.id == node_id:
			return node
	return null


static func _count(n: int, word: String) -> String:
	return "%d %s%s" % [n, word, "" if n == 1 else "s"]
