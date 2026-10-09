class_name DetPow
extends RefCounted
## pow, exp, log and ease that give the same bits on every machine, as DetMath does for the
## angles (Decision 93): only +, -, *, /, floor and comparisons, in a fixed order, with no
## fused multiply-add. exp and log follow fdlibm (its reductions by exact parts of ln 2
## and its minimax polynomials, its constants built from their exact bits). pow takes a
## whole power up to 64 by squaring, a half power by sqrt, and any other as exp(y log x),
## within about 1e-15 times (1 + |y log x|) of the true value. Pure.

const _LN2_HI := 0xB17217F7 / float(1 << 32)  # 6.93147180369123816490e-01
const _LN2_LO := 0xD1CF79ABC9E3B / float(1 << 62) / float(1 << 22)  # 1.90821492927058770002e-10
const _LG1 := 0x15555555555593 / float(1 << 53)  # 6.666666666666735130e-01
const _LG2 := 0x666666665FE81 / float(1 << 52)  # 3.999999999940941908e-01
const _LG3 := 0x12492494229359 / float(1 << 54)  # 2.857142874366239149e-01
const _LG4 := 0x1C71C51D8E78AF / float(1 << 55)  # 2.222219843214978396e-01
const _LG5 := 0xBA3324B6581EF / float(1 << 54)  # 1.818357216161805012e-01
const _LG6 := 0x139A09D078C69F / float(1 << 55)  # 1.531383769920937332e-01
const _LG7 := 0x4BC44B7CF9491 / float(1 << 53)  # 1.479819860511658591e-01
const _INVLN2 := 0xB8AA3B295C17F / float(1 << 51)  # 1.44269504088896338700e+00
const _P1 := 0xAAAAAAAAAAA9F / float(1 << 54)  # 1.66666666666666019037e-01
const _P2 := -0x16C16C16BEBD93 / float(1 << 61)  # -2.77777777770155933842e-03
const _P3 := 0x4559AABC9778B / float(1 << 62) / float(1 << 2)  # 6.61375632143793436117e-05
const _P4 := -0x1BBD41C5D26BF1 / float(1 << 62) / float(1 << 10)  # -1.65339022054652515390e-06
const _P5 := 0x16376972BEA4D / float(1 << 62) / float(1 << 11)  # 4.13813679705723846039e-08
const _OVER := 0x162E42FEFA39EF / float(1 << 43)  # 7.09782712893383973096e+02
const _UNDER := -0x174910D52D3051 / float(1 << 43)  # -7.45133219101941108420e+02
const _SQRT2 := 0x16A09E667F3BCD / float(1 << 52)  # 1.41421356237309514547e+00
const _TWO64 := float(1 << 62) * 4.0


## x to the power y, with C's special cases (0, 1, infinities, negative bases).
static func pow(x: float, y: float) -> float:
	return _pow(x, y)


## e to the x.
static func exp(x: float) -> float:
	return _exp(x)


## The natural log of x.
static func log(x: float) -> float:
	return _log(x)


# A GDScript call to `pow` inside this class is the engine's, not the static func, so the
# work is in these, which the class calls itself.
static func _pow(x: float, y: float) -> float:
	if y == 0.0 or x == 1.0:
		return 1.0
	if is_nan(x) or is_nan(y):
		return x + y
	if is_inf(y):
		if absf(x) == 1.0:
			return 1.0
		return INF if (absf(x) > 1.0) == (y > 0.0) else 0.0
	if x == 0.0 or x == INF:
		return INF if (x == 0.0) == (y < 0.0) else 0.0
	if y == 0.5 and x > 0.0:
		return sqrt(x)  # correctly rounded, as the C library's pow is here
	if floorf(y) == y and absf(y) <= 64.0:
		return _whole_power(x, y)
	if x < 0.0:
		if floorf(y) != y:
			return NAN
		var whole := _exp(y * _log(-x))
		return -whole if absf(y) < _TWO64 and y - 2.0 * floorf(y * 0.5) == 1.0 else whole
	return _exp(y * _log(x))


## e to the x (fdlibm exp): x less k ln 2, a rational fit of the rest, scaled by 2^k.
static func _exp(x: float) -> float:
	if is_nan(x):
		return x
	if x > _OVER:
		return INF
	if x < _UNDER:
		return 0.0
	var k := floorf(x * _INVLN2 + 0.5)
	var hi := x - k * _LN2_HI
	var lo := k * _LN2_LO
	var r := hi - lo
	var t := r * r
	var c := r - t * (_P1 + t * (_P2 + t * (_P3 + t * (_P4 + t * _P5))))
	var y := 1.0 - ((lo - (r * c) / (2.0 - c)) - hi)
	return _scaled(y, k)


## The natural log (fdlibm log): x as 2^k m, m within [sqrt(2)/2, sqrt(2)], and
## log(m) = 2 atanh(s) for s = f / (2 + f), f = m - 1, by a fit in s.
static func _log(x: float) -> float:
	if is_nan(x) or x == INF:
		return x
	if x < 0.0:
		return NAN
	if x == 0.0:
		return -INF
	var k := 0.0
	while x >= _TWO64:
		x /= _TWO64
		k += 64.0
	while x < 1.0 / _TWO64:
		x *= _TWO64
		k -= 64.0
	while x >= 2.0:
		x *= 0.5
		k += 1.0
	while x < 1.0:
		x *= 2.0
		k -= 1.0
	if x > _SQRT2:
		x *= 0.5
		k += 1.0
	var f := x - 1.0
	var s := f / (2.0 + f)
	var z := s * s
	var w := z * z
	var r := z * (_LG1 + w * (_LG3 + w * (_LG5 + w * _LG7))) + w * (_LG2 + w * (_LG4 + w * _LG6))
	var hfsq := 0.5 * f * f
	return k * _LN2_HI - ((hfsq - (s * (hfsq + r) + k * _LN2_LO)) - f)


## Godot's ease(x, curve) with this pow: x clamped to [0, 1]; a curve above 1 eases in,
## between 0 and 1 eases out, below 0 eases in and out; 0 is flat.
static func ease(x: float, curve: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if curve > 0.0:
		if curve < 1.0:
			return 1.0 - _pow(1.0 - x, 1.0 / curve)
		return _pow(x, curve)
	if curve < 0.0:
		if x < 0.5:
			return _pow(x * 2.0, -curve) * 0.5
		return (1.0 - _pow(1.0 - (x - 0.5) * 2.0, -curve)) * 0.5 + 0.5
	return 0.0


## x to a whole power y, |y| <= 64, by repeated squaring: exact while the products are.
static func _whole_power(x: float, y: float) -> float:
	var n := absf(y)
	var result := 1.0
	while n > 0.0:
		var half := floorf(n * 0.5)
		if n - 2.0 * half == 1.0:
			result *= x
		n = half
		if n > 0.0:
			x *= x
	return 1.0 / result if y < 0.0 else result


## y times 2^k, exactly (k whole) unless the result is subnormal.
static func _scaled(y: float, k: float) -> float:
	while k >= 64.0:
		y *= _TWO64
		k -= 64.0
	while k <= -64.0:
		y /= _TWO64
		k += 64.0
	while k >= 1.0:
		y *= 2.0
		k -= 1.0
	while k <= -1.0:
		y *= 0.5
		k += 1.0
	return y
