class_name MapNodeMarker
extends Marker2D
## One map node's authoring placement, per specs/10-map-scene-authoring.md. Wraps the
## real NodeDef resource rather than duplicating its schema - node_def's own fields
## stay the single source of truth, edited inline via the Inspector's expandable
## resource sub-editor. This marker's draggable position becomes node_def.position at
## conversion time (MapSceneConverter).

## The real domain resource this marker places. Its own position field is
## authoring-only until MapSceneConverter stamps this marker's Marker2D.position onto
## it during conversion.
@export var node_def: NodeDef

## Authoring-only topology flag: which node in the parent MapLaneRoot is the player's
## home. Not a NodeDef field - "which node is home" is a lane-level fact, not a
## property of the node itself (mirrors LaneDef.player_home_index's own reasoning).
@export var player_home: bool = false
