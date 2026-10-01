class_name SkirmishSlotPool
extends RefCounted
## The player's unlocked formation slots, split across a map's lanes as they choose
## (specs/22-formation-feel-test.md, Decision 40): with 8 slots and two lanes, 8/0, 5/3,
## 0/8 and everything between are all valid - leaving a lane empty is a real choice. The
## total comes from long-term domain upgrades (Decision 40); here it's a test value.

var total: int

var _caps := {}  # lane key -> the most slots that lane can take (its width x MAX_RANKS)
var _assigned := {}  # lane key -> slots assigned


func _init(total_slots: int, lane_caps: Dictionary) -> void:
	total = total_slots
	_caps = lane_caps.duplicate()
	for lane in _caps:
		_assigned[lane] = 0


func assigned(lane: String) -> int:
	return _assigned.get(lane, 0)


func free_slots() -> int:
	var used := 0
	for lane in _assigned:
		used += _assigned[lane]
	return total - used


## Sets a lane's share, clamped to its cap and to what the other lanes leave free.
## Returns what it actually got.
func assign(lane: String, requested: int) -> int:
	var most := mini(_caps.get(lane, 0), assigned(lane) + free_slots())
	_assigned[lane] = clampi(requested, 0, most)
	return _assigned[lane]
