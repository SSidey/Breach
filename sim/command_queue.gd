class_name CommandQueue
extends RefCounted
## Slot-filled/next-tick command latching (Decision 3). Owns *whether and when* a
## queued command takes effect; knows nothing about what a command does once
## committed, or how its slots get filled. See
## specs/01-simulation-clock-and-commands.md.
##
## Does not self-subscribe to SimEvents.tick_advanced - a RefCounted connected to a
## long-lived global signal never gets freed and would keep reacting to every future
## tick. on_tick_advanced() is called explicitly by whichever composition root owns
## both this and SimulationClock, so that root controls the connection's lifetime.

var _pending: Dictionary = {}
var _next_id: int = 0


func enqueue(command: Variant, is_filled_check: Callable) -> int:
	var id := _next_id
	_next_id += 1
	_pending[id] = {"command": command, "is_filled_check": is_filled_check}
	return id


func cancel(id: int) -> void:
	_pending.erase(id)


func is_filled(id: int) -> bool:
	if not _pending.has(id):
		return false
	return _pending[id]["is_filled_check"].call()


func pending_commands() -> Array:
	return _pending.keys()


func on_tick_advanced(_tick_number: int) -> void:
	var to_commit := []
	for id in _pending.keys():
		if is_filled(id):
			to_commit.append(id)
	for id in to_commit:
		var command = _pending[id]["command"]
		_pending.erase(id)
		SimEvents.command_committed.emit(command)
