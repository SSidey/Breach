class_name FormationRecord
extends RefCounted
## The record of play (Decision 115, spec 30 round 2): a header naming the format's version,
## the battle's seed and set-up and the build that played it (SimBuild, Decision 130), then
## one command a line - its tick, who gives it (a side), the order and its target, and a
## value where the order takes one:
##   record 2 seed 109563 captain off build 3f6800f43e11
##   0 kingdom pursue all off
##   88 player send B
##   304 player retreat B
## Orders so far: send <A|B|A+B>, retreat <A|B>, auto <wave> <on|off>, hurry <wave>
## <on|off>, tend <wave> <leave|recover|carry>, wait waves <on|off>, route <wave> <route>
## (player); pursue all <on|off> (kingdom). The feel test's words map onto them
## (from_words), and a version 0 log - "seed <n> captain <on|off>", then "<tick> <words>" -
## still reads, as does a version 1 record (no build). The vocabulary grows as real orders
## come (spec 31). Pure.

const VERSION := 2
const PLAYER := "player"
const KINGDOM := "kingdom"


## The record's first line; `build` is the build playing it ("" leaves it out).
static func header(battle_seed: int, captained: bool, build: String = "") -> String:
	var line := (
		"record %d seed %d captain %s" % [VERSION, battle_seed, "on" if captained else "off"]
	)
	return line + (" build " + build if build != "" else "")


## A command: {tick, who, order, target, value} ("" where it takes no value).
static func command(
	tick: int, who: String, order: String, target: String, value: String = ""
) -> Dictionary:
	return {"tick": tick, "who": who, "order": order, "target": target, "value": value}


## A command as its line.
static func line(given: Dictionary) -> String:
	var words := [str(given["tick"]), given["who"], given["order"], given["target"]]
	if given["value"] != "":
		words.append(given["value"])
	return " ".join(words)


## The feel test's words ("send A", "via_c on", "pursues off", ...) as a command at `tick`;
## {} if they aren't the feel test's.
static func from_words(tick: int, words: String) -> Dictionary:
	var parts := words.strip_edges().split(" ", false)
	if parts.size() < 2:
		return {}
	var on: String = parts[-1]
	match parts[0]:
		"send", "retreat":
			return command(tick, PLAYER, parts[0], parts[1])
		"auto", "hurry", "tend":
			return command(tick, PLAYER, parts[0], parts[1], on) if parts.size() == 3 else {}
		"wait":
			return command(tick, PLAYER, "wait", "waves", on)
		"via_c":
			return command(tick, PLAYER, "route", "A", "C" if on == "on" else "A")
		"pursues":
			return command(tick, KINGDOM, "pursue", "all", on)
	return {}


## A record read back: {"version", "seed", "captained", "build" ("" if not stamped),
## "commands": [command, ...]} in order; {} if it isn't a record. Lines that aren't
## commands are skipped.
static func parse(text: String) -> Dictionary:
	var lines := text.strip_edges().split("\n", false)
	var head: Array = Array(lines[0].strip_edges().split(" ", false)) if lines.size() > 0 else []
	var read := {"version": 0, "seed": 0, "captained": false, "build": "", "commands": []}
	if head.size() >= 6 and head[0] == "record" and head[1].is_valid_int():
		read["version"] = int(head[1])
		head = head.slice(2)
	if head.size() < 2 or head[0] != "seed" or not head[1].is_valid_int():
		return {}
	read["seed"] = int(head[1])
	read["captained"] = head.size() > 3 and head[3] == "on"
	if head.size() > 5 and head[4] == "build":
		read["build"] = head[5]
	for text_line in lines.slice(1):
		var given := _read(text_line, read["version"])
		if not given.is_empty():
			read["commands"].append(given)
	return read


## One line as a command, read as `version` wrote it; {} if it isn't one.
static func _read(text_line: String, version: int) -> Dictionary:
	var parts := text_line.strip_edges().split(" ", false, 1)
	if parts.size() < 2 or not parts[0].is_valid_int():
		return {}
	if version == 0:
		return from_words(int(parts[0]), parts[1])
	var words := parts[1].split(" ", false)
	if words.size() < 3 or words[0] not in [PLAYER, KINGDOM]:
		return {}
	var value: String = words[3] if words.size() > 3 else ""
	return command(int(parts[0]), words[0], words[1], words[2], value)
