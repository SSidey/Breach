class_name MapEdgeMarker
extends Node
## An explicit extra connection between two authored nodes, per
## specs/11-graph-topology-edges.md. Placed as a sibling of MapLaneRoot nodes directly
## under MapSceneRoot. node_a/node_b are picked via Godot's typed Node-reference
## export (a drag-and-drop scene-tree picker in the Inspector), converted to a
## MapEdgeDef by MapSceneConverter using the referenced markers' NodeDef ids.

@export var node_a: MapNodeMarker
@export var node_b: MapNodeMarker
