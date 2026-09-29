class_name LossGroupDef
extends Resource
## One of a faction's loss conditions, per specs/19-map-layout-and-objectives.md: a
## set of critical-asset nodes and a rule. ANY = the faction loses when any one of them
## is captured; ALL = only once every one is. A faction's groups are OR'd - it is
## knocked out when any one group triggers. Authored data; sim/ doesn't evaluate it yet.

enum Rule { ANY, ALL }

@export var faction_id: String = ""
@export var display_name: String = ""
@export var rule: Rule = Rule.ANY
@export var node_ids: Array[String] = []


func validate(
	node_ids_on_map: Dictionary, faction_ids: Dictionary, critical_ids: Dictionary
) -> PackedStringArray:
	var errors := PackedStringArray()
	var label := "loss group '%s' (%s)" % [display_name, faction_id]
	if not faction_ids.has(faction_id):
		errors.append("%s: unknown faction '%s'" % [label, faction_id])
	if node_ids.is_empty():
		errors.append("%s has no nodes" % label)
	for node_id in node_ids:
		if not node_ids_on_map.has(node_id):
			errors.append("%s: unknown node '%s'" % [label, node_id])
		elif not critical_ids.has(node_id):
			errors.append("%s: '%s' is not a critical asset" % [label, node_id])
	return errors
