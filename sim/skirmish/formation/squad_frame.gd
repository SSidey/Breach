class_name SquadFrame
extends RefCounted
## A squad's frame in cells (Decision 74, specs/27-formations-in-2d.md): its position is
## the centre of its front edge, and it faces one of four ways. A unit's (rank, column) is
## turned to the facing, never mirrored, so the squad's left stays its left. Screen
## convention: x east, y south. Facings run clockwise. Pure.

const NORTH := 0
const EAST := 1
const SOUTH := 2
const WEST := 3

const _FORWARD := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]


static func forward(facing: int) -> Vector2:
	return _FORWARD[posmod(facing, 4)]


## The squad's right hand: the way its columns count.
static func right(facing: int) -> Vector2:
	return _FORWARD[posmod(facing + 1, 4)]


static func opposite(facing: int) -> int:
	return posmod(facing + 2, 4)


## The cells a unit covers: its columns from the squad's left (centred on the front centre,
## moved by centre_shift), its ranks back from the front.
static func unit_rect(
	anchor: Vector2, facing: int, width: int, centre_shift: float, unit: SkirmishUnit
) -> Rect2:
	var left := unit.column - width / 2.0 + centre_shift
	var back := -forward(facing)
	var near := anchor + right(facing) * left + back * unit.rank
	var far := (
		anchor
		+ right(facing) * (left + unit.footprint_width)
		+ back * (unit.rank + unit.footprint_depth)
	)
	return Rect2(near.min(far), (far - near).abs())


## A rect's extent across the facing, on the world axis the squad's columns run along.
static func lateral_interval(rect: Rect2, facing: int) -> Vector2:
	if absf(right(facing).y) > 0.5:
		return Vector2(rect.position.y, rect.end.y)
	return Vector2(rect.position.x, rect.end.x)


## How far `to` lies ahead of `from` along the facing (negative: behind).
static func gap_along(from: Vector2, to: Vector2, facing: int) -> float:
	return (to - from).dot(forward(facing))
