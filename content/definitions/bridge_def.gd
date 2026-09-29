class_name BridgeDef
extends Resource
## A bridge over a needs_bridge tile (water, ravine), per
## specs/19-map-layout-and-objectives.md. A drawbridge is controlled by an adjacent node
## and, while raised, blocks routes over it (the designer's route cost treats it as
## no bridge).

@export var owning_faction_id: String = ""
@export var hp: int = 40
@export var demolishable_by_owner: bool = false
## The node that raises and lowers it; "" for a plain bridge.
@export var drawbridge_node_id: String = ""
@export var raised: bool = false
