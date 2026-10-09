class_name DetMath
extends RefCounted
## Transcendental maths that gives the same bits on every machine (Decision 93: a battle
## replays bit for bit everywhere). The platform's sin, cos, acos, asin, atan2 and pow are
## not correctly rounded, so glibc, the Windows CRT and Apple's libm differ in the last
## bit; these use only +, -, *, /, sqrt and floor, which IEEE 754 fixes exactly, in a fixed
## order with no fused multiply-add. They follow fdlibm (Sun's freely distributable libm):
## Cody-Waite range reduction by pi/2 in three exact parts, then its minimax polynomials.
## Its constants are built from their exact bits, as Godot's float literals can be an ulp
## off. f64 throughout, within about 1e-15 of the true value; deterministic, not correctly
## rounded. The Rust core's copy of sin and cos (native/rust/src/det_math.rs) does the
## same operations in the same order. Pow, exp, log and ease are in DetPow. Pure.

const DetPow = preload("res://sim/skirmish/formation/det_pow.gd")

const _S1 := -0x15555555555549 / float(1 << 55)  # -1.66666666666666324348e-01
const _S2 := 0x8888888887C53 / float(1 << 58)  # 8.33333333332248946124e-03
const _S3 := -0x1A01A019C161D5 / float(1 << 62) / float(1 << 3)  # -1.98412698298579493134e-04
const _S4 := 0x171DE357B1FE7D / float(1 << 62) / float(1 << 9)  # 2.75573137070700676789e-06
const _S5 := -0x1AE5E68A2B9CEB / float(1 << 62) / float(1 << 16)  # -2.50507602534068634195e-08
const _S6 := 0x5764E96B3F55F / float(1 << 62) / float(1 << 21)  # 1.58969099521155010221e-10
const _C1 := 0x5555555555553 / float(1 << 55)  # 4.16666666666666019037e-02
const _C2 := -0x16C16C16C15177 / float(1 << 62)  # -1.38888888888741095749e-03
const _C3 := 0x1A01A019CB159 / float(1 << 62) / float(1 << 2)  # 2.48015872894767294178e-05
const _C4 := -0x127E4F809C52AD / float(1 << 62) / float(1 << 12)  # -2.75573143513906633035e-07
const _C5 := 0x47BA7AF6D2C71 / float(1 << 62) / float(1 << 17)  # 2.08757232129817482790e-09
const _C6 := -0x63EBA6FA20E35 / float(1 << 62) / float(1 << 25)  # -1.13596475577881948265e-11
const _PIO2_1 := 0x6487ED51 / float(1 << 30)  # 1.57079632673412561417e+00
const _PIO2_2 := 0x85A308D3 / float(1 << 62) / float(1 << 3)  # 6.07710050630396597660e-11
const _PIO2_3 := 0x98CC517 / float(1 << 62) / float(1 << 34)  # 2.02226624871116645580e-21
const _INVPIO2 := 0x145F306DC9C883 / float(1 << 53)  # 6.36619772367581382433e-01

const _AH0 := 0x1DAC670561BB4F / float(1 << 54)  # 4.63647609000806093515e-01
const _AH1 := 0x3243F6A8885A3 / float(1 << 50)  # 7.85398163397448278999e-01
const _AH2 := 0x1F730BD281F69B / float(1 << 53)  # 9.82793723247329054082e-01
const _AL0 := 0xD15BF9117B2F1 / float(1 << 62) / float(1 << 45)  # 2.26987774529616870924e-17
const _AL1 := 0x11A62633145C07 / float(1 << 62) / float(1 << 45)  # 3.06161699786838301793e-17
const _AL2 := 0x1007887AF0CBBD / float(1 << 62) / float(1 << 46)  # 1.39033110312309984516e-17
const _AL3 := 0x11A62633145C07 / float(1 << 62) / float(1 << 44)  # 6.12323399573676603587e-17
const _T0 := 0x1555555555550D / float(1 << 54)  # 3.33333333333329318027e-01
const _T1 := -0x6666666663AF1 / float(1 << 53)  # -1.99999999998764832476e-01
const _T2 := 0x124924920083FF / float(1 << 55)  # 1.42857142725034663711e-01
const _T3 := -0x1C71C6FE231671 / float(1 << 56)  # -1.11111104054623557880e-01
const _T4 := 0xBA2E6E2A61037 / float(1 << 55)  # 9.09088713343650656196e-02
const _T5 := -0x13B0F2AF749A6D / float(1 << 56)  # -7.69187620504482999495e-02
const _T6 := 0x110D66A0D03D51 / float(1 << 56)  # 6.66107313738753120669e-02
const _T7 := -0xEEF16A96F7ECD / float(1 << 56)  # -5.83357013379057348645e-02
const _T8 := 0x197B4B24760DEB / float(1 << 57)  # 4.97687799461593236017e-02
const _T9 := -0x12B4442C6A6C2F / float(1 << 57)  # -3.65315727442169155270e-02
const _T10 := 0x10AD3AE322DA11 / float(1 << 58)  # 1.62858201153657823623e-02
const _PI_LO := 0x11A62633145C07 / float(1 << 62) / float(1 << 43)  # 1.2246467991473531772E-16
const _ATAN_HI := [_AH0, _AH1, _AH2, PI / 2.0]
const _ATAN_LO := [_AL0, _AL1, _AL2, _AL3]
const _TINY := 1.0 / float(1 << 27)
const _HUGE := float(1 << 62) * 16.0  # 2^66
const _WHOLE := float(1 << 52)


## sin(x), x in radians.
static func sin(x: float) -> float:
	return _sine(x, 0)


## cos(x), x in radians: sin a quarter turn on.
static func cos(x: float) -> float:
	return _sine(x, 1)


## asin(x) in [-pi/2, pi/2]; as Godot's, x beyond [-1, 1] counts as -1 or 1. As
## atan2(x, sqrt((1 - x)(1 + x))), the cases that can't arise left out.
static func asin(x: float) -> float:
	if x <= -1.0:
		return -PI / 2.0
	if x >= 1.0:
		return PI / 2.0
	if x == 0.0:
		return x
	var t := x / sqrt((1.0 - x) * (1.0 + x))
	return _atan(t) if t > 0.0 else -_atan(-t)


## acos(x) in [0, pi]; as Godot's, x beyond [-1, 1] counts as -1 or 1. As
## atan2(sqrt((1 - x)(1 + x)), x), the cases that can't arise left out.
static func acos(x: float) -> float:
	if x <= -1.0:
		return PI
	if x >= 1.0:
		return 0.0
	if x == 0.0:
		return PI / 2.0
	var s := sqrt((1.0 - x) * (1.0 + x))
	if x > 0.0:
		return _atan(s / x)
	return PI - (_atan(s / -x) - _PI_LO)


## atan2(y, x) in [-pi, pi], with C's quadrants, signed zeros and infinities.
static func atan2(y: float, x: float) -> float:
	if y == 0.0 or x == 0.0 or not (x - x == 0.0 and y - y == 0.0):
		return _atan2_edge(y, x)  # zeros, infinities and NaNs
	var z := _atan(y / x if (y > 0.0) == (x > 0.0) else -(y / x))
	if x < 0.0:
		z = PI - (z - _PI_LO)
	return -z if y < 0.0 else z


## x to the power y (DetPow.pow).
static func pow(x: float, y: float) -> float:
	return DetPow.pow(x, y)


## `v` turned by `angle` radians, as Vector2.rotated: worked in f64, then made a Vector2.
static func rotated(v: Vector2, angle: float) -> Vector2:
	var s := _sine(angle, 0)
	var c := _sine(angle, 1)
	return Vector2(v.x * c - v.y * s, v.x * s + v.y * c)


## sin(x) after `turns` quarter turns. x less the nearest multiple k of pi/2, the three
## parts of pi/2 taken off in turn (each product exact), and k mod 4 picks the kernel.
## (A GDScript call to `sin` inside this class is the engine's, so the class calls this.)
static func _sine(x: float, turns: int) -> float:
	if x < 0.78 and x > -0.78:  # k would be 0 and r x: the same bits, sooner
		return _sin_kernel(x) if turns == 0 else _cos_kernel(x)
	if not x - x == 0.0:
		return x - x  # NaN for infinities and NaNs
	var k := floorf(x * _INVPIO2 + 0.5)
	var r := ((x - k * _PIO2_1) - k * _PIO2_2) - k * _PIO2_3
	var quarter := turns
	if k < _WHOLE and k > -_WHOLE:
		quarter += int(k)
	else:
		quarter += int(k - 4.0 * floorf(k * 0.25))
	quarter &= 3
	if quarter == 0:
		return _sin_kernel(r)
	if quarter == 1:
		return _cos_kernel(r)
	if quarter == 2:
		return -_sin_kernel(r)
	return -_cos_kernel(r)


## atan2 where a side is zero, infinite or NaN, as C has it.
static func _atan2_edge(y: float, x: float) -> float:
	if is_nan(x) or is_nan(y):
		return x + y
	var below := _negative(y)
	if y == 0.0:
		if not _negative(x):
			return y
		return -PI if below else PI
	if x == 0.0 or not is_inf(x):
		return -PI / 2.0 if below else PI / 2.0
	var z := PI * 0.25 if is_inf(y) else 0.0
	if x < 0.0:
		z = PI - (z - _PI_LO)
	return -z if below else z


## sin on [-pi/4, pi/4] (fdlibm __kernel_sin).
static func _sin_kernel(x: float) -> float:
	var z := x * x
	var v := z * x
	var r := _S2 + z * (_S3 + z * (_S4 + z * (_S5 + z * _S6)))
	return x + v * (_S1 + z * r)


## cos on [-pi/4, pi/4] (fdlibm __kernel_cos).
static func _cos_kernel(x: float) -> float:
	var z := x * x
	var r := z * (_C1 + z * (_C2 + z * (_C3 + z * (_C4 + z * (_C5 + z * _C6)))))
	var hz := 0.5 * z
	var w := 1.0 - hz
	return w + (((1.0 - w) - hz) + z * r)


## atan(t) for t >= 0 (fdlibm atan): t brought near 0, 0.5, 1, 1.5 or infinity first.
static func _atan(t: float) -> float:
	if t >= _HUGE:
		return PI / 2.0
	var at := -1
	if t < 0.4375:
		if t < _TINY:
			return t
	elif t < 0.6875:
		at = 0
		t = (2.0 * t - 1.0) / (2.0 + t)
	elif t < 1.1875:
		at = 1
		t = (t - 1.0) / (t + 1.0)
	elif t < 2.4375:
		at = 2
		t = (t - 1.5) / (1.0 + 1.5 * t)
	else:
		at = 3
		t = -1.0 / t
	var z := t * t
	var w := z * z
	var s1 := z * (_T0 + w * (_T2 + w * (_T4 + w * (_T6 + w * (_T8 + w * _T10)))))
	var s2 := w * (_T1 + w * (_T3 + w * (_T5 + w * (_T7 + w * _T9))))
	if at < 0:
		return t - t * (s1 + s2)
	return _ATAN_HI[at] - ((t * (s1 + s2) - _ATAN_LO[at]) - t)


## True if `v` is below zero or is -0.0.
static func _negative(v: float) -> bool:
	return v < 0.0 or (v == 0.0 and 1.0 / v < 0.0)
