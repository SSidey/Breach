class_name MapLaneRoot
extends Node2D
## One lane's authoring container, per specs/10-map-scene-authoring.md. Children (in
## child order) are MapNodeMarkers - child order is the lane's path order, mirroring
## LaneDef.nodes' own "array order is the path" convention.

@export var lane_id: String = ""
