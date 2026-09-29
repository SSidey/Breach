class_name DesignerLaneDeriver
## Derives MapDef topology from a Lane Tile Designer export's links, per
## specs/16-designer-map-import.md. The user's rule: links already define the routes
## (and so a fort's approach directions), so lanes come from them.
##
## Home = the first player-owned critical asset (else player-owned ORIGIN). Each other
## faction's critical asset or origin gets one lane: the fewest-link path from home
## (breadth-first, ties to the earlier link). Every link that isn't a consecutive pair in
## some lane becomes a MapEdgeDef; nodes on no lane go to MapDef.off_lane_nodes.

const NodeDef = preload("res://content/definitions/node_def.gd")
const LaneDef = preload("res://content/definitions/lane_def.gd")
const MapDef = preload("res://content/definitions/map_def.gd")
const MapEdgeDef = preload("res://content/definitions/map_edge_def.gd")
const DesignerNodeBuilder = preload("res://content/import/designer_node_builder.gd")

const PLAYER_FACTION := "player"


static func derive(
	export_data: Dictionary, nodes: Dictionary, map_def: MapDef, errors: PackedStringArray
) -> void:
	var links: Array = export_data.get("links", [])
	var nodes_data: Array = export_data.get("nodes", [])
	var home_id := _find_home(nodes_data)
	var lanes: Array[LaneDef] = []
	var lane_pairs := {}
	if home_id.is_empty():
		errors.append("no player home: mark a player-owned node as a critical asset (or an ORIGIN)")
	else:
		var parents := _breadth_first(_adjacency(links), home_id)
		for target_id in _targets(nodes_data, home_id):
			if not parents.has(target_id):
				errors.append(
					"no link path from the player home '%s' to target '%s'" % [home_id, target_id]
				)
				continue
			lanes.append(_lane(_path_to(parents, target_id), nodes, lane_pairs))
		if lanes.is_empty():
			errors.append("no lane could be derived: link the player home to an enemy target")
	map_def.lanes = lanes
	map_def.edges = _edges(links, lane_pairs)
	map_def.off_lane_nodes = _off_lane(nodes, lanes)


static func _find_home(nodes_data: Array) -> String:
	for entry in nodes_data:
		if _owner(entry) == PLAYER_FACTION and bool(entry.get("is_critical_asset", false)):
			return DesignerNodeBuilder.text(entry.get("id"))
	for entry in nodes_data:
		if _owner(entry) == PLAYER_FACTION and _type(entry) == "ORIGIN":
			return DesignerNodeBuilder.text(entry.get("id"))
	return ""


## Every other node that is a critical asset or an origin and isn't the player's.
static func _targets(nodes_data: Array, home_id: String) -> Array[String]:
	var targets: Array[String] = []
	for entry in nodes_data:
		var node_id := DesignerNodeBuilder.text(entry.get("id"))
		if node_id == home_id or _owner(entry) == PLAYER_FACTION:
			continue
		if bool(entry.get("is_critical_asset", false)) or _type(entry) == "ORIGIN":
			targets.append(node_id)
	return targets


static func _adjacency(links: Array) -> Dictionary:
	var adjacency := {}
	for link in links:
		var a := DesignerNodeBuilder.text(link.get("a"))
		var b := DesignerNodeBuilder.text(link.get("b"))
		adjacency[a] = adjacency.get(a, []) + [b]
		adjacency[b] = adjacency.get(b, []) + [a]
	return adjacency


## Fewest-link parents from home; ties go to the earlier link (export order).
static func _breadth_first(adjacency: Dictionary, home_id: String) -> Dictionary:
	var parents := {home_id: ""}
	var queue: Array[String] = [home_id]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for neighbour in adjacency.get(current, []):
			if not parents.has(neighbour):
				parents[neighbour] = current
				queue.append(neighbour)
	return parents


static func _path_to(parents: Dictionary, target_id: String) -> Array[String]:
	var path: Array[String] = [target_id]
	while not parents[path[0]].is_empty():
		path.push_front(parents[path[0]])
	return path


## Builds the lane and records its consecutive pairs in lane_pairs. A node shared by
## several lanes (the home) is the same NodeDef instance in each.
static func _lane(path: Array[String], nodes: Dictionary, lane_pairs: Dictionary) -> LaneDef:
	var lane := LaneDef.new()
	lane.id = "to_" + path[path.size() - 1]
	var lane_nodes: Array[NodeDef] = []
	for i in range(path.size()):
		lane_nodes.append(nodes[path[i]])
		if i > 0:
			lane_pairs[_pair_key(path[i - 1], path[i])] = true
	lane.nodes = lane_nodes
	lane.player_home_index = 0
	return lane


static func _edges(links: Array, lane_pairs: Dictionary) -> Array[MapEdgeDef]:
	var edges: Array[MapEdgeDef] = []
	var seen := lane_pairs.duplicate()
	for link in links:
		var a := DesignerNodeBuilder.text(link.get("a"))
		var b := DesignerNodeBuilder.text(link.get("b"))
		if seen.has(_pair_key(a, b)):
			continue
		seen[_pair_key(a, b)] = true
		var edge := MapEdgeDef.new()
		edge.node_a_id = a
		edge.node_b_id = b
		edges.append(edge)
	return edges


static func _off_lane(nodes: Dictionary, lanes: Array[LaneDef]) -> Array[NodeDef]:
	var on_lane := {}
	for lane in lanes:
		for node in lane.nodes:
			on_lane[node.id] = true
	var off_lane: Array[NodeDef] = []
	for node_id in nodes.keys():
		if not on_lane.has(node_id):
			off_lane.append(nodes[node_id])
	return off_lane


static func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a <= b else b + "|" + a


static func _owner(entry: Dictionary) -> String:
	return DesignerNodeBuilder.text(entry.get("owning_faction_id"))


static func _type(entry: Dictionary) -> String:
	return DesignerNodeBuilder.text(entry.get("node_type"))
