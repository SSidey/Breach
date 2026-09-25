class_name FactionRelationDef
extends Resource
## Declares how two factions relate, per specs/12-node-schema-round-3.md. Additive,
## inert data - sim/'s existing ad-hoc String ownership ("player"/"defender") is not
## migrated to FactionId here; that's separate, future work for whenever something
## actually consumes factions.

## Append-only, same convention as NodeDef.NodeType - .tres files store the raw
## ordinal, and inserting would silently reinterpret already-authored content.
enum FactionId { PLAYER, ENEMY }

enum Stance { HOSTILE, NEUTRAL, ALLIED }

@export var faction_a: FactionId = FactionId.PLAYER
@export var faction_b: FactionId = FactionId.ENEMY
@export var stance: Stance = Stance.HOSTILE


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if faction_a == faction_b:
		errors.append("faction_a and faction_b must not be the same faction (self-relation)")
	return errors
