class_name EconomySystem
extends RefCounted
## Five resource pools and harvester yield decay, per
## specs/03-resource-nodes-and-workers.md and the parent spec's Economy section.
##
## Decay rate (-10% per interval) is a fixed rule of this system, per the parent
## spec's own prose ("e.g. -10% every N rounds") - not exposed as per-node/per-map
## config since nothing in this slice needs it tunable.

const DECAY_RATE_PER_INTERVAL := 0.9

var _pools: Dictionary = {"food": 0, "wood": 0, "stone": 0, "metal": 0, "crystal": 0}


func balance(resource: String) -> int:
	return _pools.get(resource, 0)


func add(resource: String, amount: int) -> void:
	_pools[resource] = balance(resource) + amount


func spend(resource: String, amount: int) -> bool:
	if balance(resource) < amount:
		return false
	_pools[resource] = balance(resource) - amount
	return true


func decayed_yield(
	base_yield: int, ticks_elapsed: int, decay_interval_ticks: int, floor: int
) -> int:
	var intervals := ticks_elapsed / decay_interval_ticks
	var decayed := base_yield * pow(DECAY_RATE_PER_INTERVAL, intervals)
	return max(floor, int(round(decayed)))
