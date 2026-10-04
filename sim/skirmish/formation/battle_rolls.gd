class_name BattleRolls
extends RefCounted
## A battle's random draws (Decision 93): every one comes from the battle seed and what it
## is for, so a battle with the same seed and the same orders replays exactly, and a new
## seed gives a different one. Pure.


## A number in [0, 1) for these keys under the battle seed.
static func uniform(battle_seed: int, keys: Array) -> float:
	var mixed := [battle_seed]
	mixed.append_array(keys)
	return float(posmod(hash(mixed), 1 << 24)) / float(1 << 24)


## A blow's damage rolled within `band` round `base` (0.25: 75% to 125%), at least 1.
static func damage(base: int, band: float, battle_seed: int, keys: Array) -> int:
	if band <= 0.0 or base <= 0:
		return base
	var spread := (uniform(battle_seed, keys) * 2.0 - 1.0) * band
	return maxi(1, roundi(base * (1.0 + spread)))
