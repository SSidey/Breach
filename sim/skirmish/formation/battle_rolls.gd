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
