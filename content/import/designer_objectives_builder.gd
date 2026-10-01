class_name DesignerObjectivesBuilder
extends RefCounted
## Builds LossGroupDefs from a designer export's loss_criteria, per
## specs/19-map-layout-and-objectives.md. (Critical assets are a node flag, copied by
## DesignerNodeBuilder.)

const LossGroupDef = preload("res://content/definitions/loss_group_def.gd")


static func build_loss_groups(
	export_data: Dictionary, errors: PackedStringArray
) -> Array[LossGroupDef]:
	var groups: Array[LossGroupDef] = []
	for entry in export_data.get("loss_criteria", []):
		var group := LossGroupDef.new()
		group.faction_id = str(entry.get("faction_id", ""))
		group.display_name = str(entry.get("name", ""))
		var rule := str(entry.get("rule", "ANY"))
		if LossGroupDef.Rule.has(rule):
			group.rule = LossGroupDef.Rule[rule]
		else:
			errors.append(
				(
					"loss group '%s' (%s): unknown rule '%s'"
					% [group.display_name, group.faction_id, rule]
				)
			)
		var node_ids: Array[String] = []
		for node_id in entry.get("node_ids", []):
			node_ids.append(str(node_id))
		group.node_ids = node_ids
		groups.append(group)
	return groups
