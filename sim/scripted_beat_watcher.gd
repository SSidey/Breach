class_name ScriptedBeatWatcher
extends RefCounted
## This map's win/loss triggers (Decision 9): defeating the Hero Party doesn't win by
## itself; reaching the Core afterward does. Losing the entire force loses regardless
## of whether the Hero Party has already been defeated. See
## specs/06-map-content-p-f-F-c.md.
##
## Not a generic rule-matching engine, despite the spec's original "configured rules"
## framing - with exactly one map and three rules, a small explicit API is simpler
## and just as data-independent-per-map at this scale. Genericity is worth building
## once a second map's ruleset exists to prove the abstraction against, not before.
##
## Does not self-subscribe to SimEvents (same reasoning as every other sim/
## component this slice): a composition root (Phase 3 item 11) calls these methods
## explicitly when it determines a raw SimEvents payload pertains to this map's
## specific Hero Party / Core - e.g. correlating a combat_resolved event against
## TaskForceDispatch's own dispatched-list bookkeeping before calling
## on_hero_party_defeated().

var _core_node_index: int
var _hero_party_defeated: bool = false


func _init(core_node_index: int) -> void:
	_core_node_index = core_node_index


func hero_party_defeated() -> bool:
	return _hero_party_defeated


func on_hero_party_defeated() -> void:
	_hero_party_defeated = true


func on_node_captured(node_index: int) -> void:
	if node_index == _core_node_index and _hero_party_defeated:
		SimEvents.victory.emit()


func on_player_unit_count_changed(total_units: int) -> void:
	if total_units <= 0:
		SimEvents.defeat.emit()
