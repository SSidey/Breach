class_name MapDetails
extends RefCounted
## The map viewer's info-panel text (BBCode), per specs/18-map-viewer.md. Pure and
## read-only over content/, so it's tested headlessly.

const NodeDef = preload("res://content/definitions/node_def.gd")
const LossGroupDef = preload("res://content/definitions/loss_group_def.gd")
const TileDef = preload("res://content/definitions/tile_def.gd")


static func summary(map_def: MapDef) -> String:
	var ids := {}
	for lane in map_def.lanes:
		for node in lane.nodes:
			ids[node.id] = true
	var on_lane := ids.size()
	for node in map_def.off_lane_nodes:
		ids[node.id] = true
	return (
		(
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
		+ _layout_line(map_def)
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
	if node.is_critical_asset:
		lines.append("critical asset")
	for group in map_def.loss_groups:
		if group.node_ids.has(node.id):
			lines.append(
				(
					"loss group: %s (%s, %s)"
					% [group.display_name, group.faction_id, LossGroupDef.Rule.keys()[group.rule]]
				)
			)
	var lanes := PackedStringArray()
	for lane in map_def.lanes:
		if lane.nodes.has(node):
			lanes.append(lane.id)
	lines.append("lanes: %s" % ", ".join(lanes) if not lanes.is_empty() else "off-lane")
	return "\n".join(lines)


## A grid cell's layers (specs/19): terrain, feature, effective capacity, upgrades, bridge.
static func tile_details(map_def: MapDef, cell: Vector2i) -> String:
	var layout = map_def.layout
	if layout == null or not layout.contains(cell):
		return "No tile at %s." % cell
	var library = layout.terrain_library
	var tile = layout.tile_at(cell)
	var terrain_id: String = layout.terrain_id_at(cell)
	var terrain = library.terrain(terrain_id)
	var is_base: bool = tile == null or tile.terrain_id == ""
	var lines := PackedStringArray()
	lines.append(
		(
			"[b]cell %d, %d[/b]  %s%s"
			% [
				cell.x,
				cell.y,
				terrain.display_name if terrain else terrain_id,
				" (base)" if is_base else ""
			]
		)
	)
	if tile == null:
		tile = TileDef.new()
		tile.cell = cell
	if tile.feature_id:
		var feature = library.feature(tile.feature_id)
		lines.append("feature: %s" % (feature.display_name if feature else tile.feature_id))
	var capacity: Dictionary = tile.effective_capacity(library, layout.default_terrain_id)
	lines.append(
		(
			"stability %d · height %d · width %d · dig %d"
			% [
				capacity["stability"],
				capacity["max_height"],
				capacity["max_width"],
				capacity["max_depth"]
			]
		)
	)
	if tile.upgrade_slots > 0 or not tile.upgrade_ids.is_empty():
		lines.append(
			(
				"upgrades %d/%d: %s"
				% [tile.upgrade_ids.size(), tile.upgrade_slots, ", ".join(tile.upgrade_ids)]
			)
		)
	if tile.bridge != null:
		var kind := (
			"drawbridge (%s)" % tile.bridge.drawbridge_node_id
			if tile.bridge.drawbridge_node_id
			else "bridge"
		)
		lines.append(
			"%s, hp %d%s" % [kind, tile.bridge.hp, ", raised" if tile.bridge.raised else ""]
		)
	return "\n".join(lines)


static func _layout_line(map_def: MapDef) -> String:
	var parts := PackedStringArray()
	if map_def.layout != null:
		parts.append("%d×%d grid" % [map_def.layout.cols, map_def.layout.rows])
	if not map_def.loss_groups.is_empty():
		parts.append(_count(map_def.loss_groups.size(), "loss group"))
	return "" if parts.is_empty() else "\n" + " · ".join(parts)


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
