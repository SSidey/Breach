class_name DesignerNodeBuilder
## Builds NodeDefs from a Lane Tile Designer export's "nodes" entries, per
## specs/16-designer-map-import.md. Split out of DesignerMapImporter (one concern per
## file). Also owns the export's JSON value helpers (text/strings), shared by the
## importer and DesignerLaneDeriver.

const NodeDef = preload("res://content/definitions/node_def.gd")
const GarrisonUnitDef = preload("res://content/definitions/garrison_unit_def.gd")

const DEFAULT_CELL_SIZE := 64.0
## NodeDef properties set by the builder itself; a designer "fields" key never overrides them.
const RESERVED_FIELDS := [
	"id",
	"node_type",
	"position",
	"garrison",
	"garrison_units",
	"owning_faction_id",
	"hidden_from_faction_ids",
]


## Keyed by node id, in export order (Dictionary preserves insertion order). Problems go
## into errors/warnings.
static func build_nodes(
	export_data: Dictionary, errors: PackedStringArray, warnings: PackedStringArray
) -> Dictionary:
	var cell := float(export_data.get("cell_size", DEFAULT_CELL_SIZE))
	var nodes := {}
	for entry in export_data.get("nodes", []):
		var node := _build_node(entry, cell, errors, warnings)
		nodes[node.id] = node
	return nodes


## JSON null -> "" (str(null) would give "<null>").
static func text(value) -> String:
	return "" if value == null else str(value)


static func strings(values) -> Array[String]:
	var out: Array[String] = []
	for value in values if values is Array else []:
		out.append(text(value))
	return out


static func _build_node(
	entry: Dictionary, cell: float, errors: PackedStringArray, warnings: PackedStringArray
) -> NodeDef:
	var node := NodeDef.new()
	node.id = text(entry.get("id"))
	var type_name := text(entry.get("node_type"))
	if NodeDef.NodeType.has(type_name):
		node.node_type = NodeDef.NodeType[type_name]
	else:
		errors.append("node '%s': unknown node_type '%s'" % [node.id, type_name])
	node.owning_faction_id = text(entry.get("owning_faction_id"))
	node.hidden_from_faction_ids = strings(entry.get("hidden_from_faction_ids", []))
	node.is_critical_asset = bool(entry.get("is_critical_asset", false))
	var cell_pos: Dictionary = entry.get("grid_position", {})
	node.position = Vector2(
		(float(cell_pos.get("col", 0)) + 0.5) * cell, (float(cell_pos.get("row", 0)) + 0.5) * cell
	)
	for field_name in entry.get("fields", {}).keys():
		_apply_field(node, field_name, entry["fields"][field_name], errors, warnings)
	_apply_garrison(node, entry.get("garrison_units", []), errors)
	return node


static func _apply_field(
	node: NodeDef, field_name: String, value, errors: PackedStringArray, warnings: PackedStringArray
) -> void:
	if field_name == "resource_type":
		if NodeDef.ResourceType.has(text(value)):
			node.resource_type = NodeDef.ResourceType[text(value)]
		else:
			errors.append("node '%s': unknown resource_type '%s'" % [node.id, value])
		return
	if field_name in RESERVED_FIELDS or not field_name in node:
		warnings.append(
			"node '%s': field '%s' is not a NodeDef property; skipped" % [node.id, field_name]
		)
		return
	match typeof(node.get(field_name)):
		TYPE_INT:
			node.set(field_name, int(value))
		TYPE_FLOAT:
			node.set(field_name, float(value))
		TYPE_BOOL:
			node.set(field_name, bool(value))
		TYPE_STRING:
			node.set(field_name, text(value))
		_:
			warnings.append(
				"node '%s': field '%s' has an unsupported type; skipped" % [node.id, field_name]
			)


static func _apply_garrison(node: NodeDef, units_data: Array, errors: PackedStringArray) -> void:
	var units: Array[GarrisonUnitDef] = []
	for entry in units_data:
		var unit := GarrisonUnitDef.new()
		unit.faction_id = text(entry.get("faction_id"))
		if unit.faction_id.is_empty():
			unit.faction_id = node.owning_faction_id  # a unit with no faction serves the owner
		if unit.faction_id.is_empty():
			errors.append(
				"node '%s': a garrison unit has no faction and the node has no owner" % node.id
			)
		unit.can_sortie = bool(entry.get("can_sortie", false))
		unit.patrol_route = strings(entry.get("patrol_route", []))
		unit.delivery_target_id = text(entry.get("delivery_target_id"))
		units.append(unit)
	node.garrison_units = units
	node.garrison = units.size()
