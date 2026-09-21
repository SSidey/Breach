class_name PlayerRoster
extends RefCounted
## Tracks the player's total standing force for the loss condition, per specs/00
## ("roster + anything on the lane"). Plain data in, plain data out, same reasoning
## as CombatResolver - never reads LaneSimulation state directly.
##
## Found necessary via manual playtest (Phase 4 follow-up, not pre-planned): a
## composition root computing "player unit count" purely from LaneSimulation.waves()
## undercounts once a wave auto-extracts (specs/03, Decision 2) - those units are
## still alive (now harvesting), but LaneSimulation no longer tracks them in any wave.
## The caller marks a count as "harvesting" at the moment it despawns that wave; this
## class only ever adds, since nothing in this slice kills a harvesting worker yet.

var _harvesting_count: int = 0


func mark_harvesting(unit_count: int) -> void:
	_harvesting_count += unit_count


func total(marching_unit_count: int) -> int:
	return _harvesting_count + marching_unit_count
