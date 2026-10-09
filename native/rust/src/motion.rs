//! How a unit turns (UnitMotion's bearing_to, pace and turn; UnitShuffle's look and
//! turning), operation for operation as the GDScript has them: `Vector2` maths in f32,
//! GDScript floats in f64, `fposmod`, `clampf`, `maxf` and `rad_to_deg` as Godot computes
//! them, and DetMath's atan2 and acos (`det_math`). Bearings are degrees clockwise from
//! north.

use crate::det_math;
use crate::maths::{bearing_vector, V2};

/// UnitMotion.EPSILON and UnitShuffle.EPSILON.
const EPSILON: f64 = 0.000001;

/// What of a unit its turning reads.
#[derive(Clone, Copy)]
pub struct Mover {
    pub bearing: f64,
    pub turn_rate: f64,
    pub backward_pace: f64,
}

/// Godot's `fposmod`: `fmod`, moved into the divisor's sign, and -0 made 0.
#[inline]
pub fn fposmod(x: f64, y: f64) -> f64 {
    let mut value = x % y;
    if (value < 0.0 && y > 0.0) || (value > 0.0 && y < 0.0) {
        value += y;
    }
    value + 0.0
}

/// Godot's `rad_to_deg`: `x * (180 / PI)`.
#[inline]
pub fn rad_to_deg(x: f64) -> f64 {
    x * (180.0 / std::f64::consts::PI)
}

/// Godot's `clampf`.
#[inline]
fn clampf(v: f64, low: f64, high: f64) -> f64 {
    if v < low {
        low
    } else if v > high {
        high
    } else {
        v
    }
}

/// Godot's `maxf`.
#[inline]
fn maxf(a: f64, b: f64) -> f64 {
    if a > b {
        a
    } else {
        b
    }
}

/// UnitMotion.bearing_to: the bearing of the way from `from` to `to` (`current` if they
/// coincide).
pub fn bearing_to(from: V2, to: V2, current: f64) -> f64 {
    let way = to.sub(from);
    if (way.length() as f64) < EPSILON {
        return current;
    }
    fposmod(rad_to_deg(det_math::atan2(way.x as f64, -way.y as f64)), 360.0)
}

/// UnitMotion.pace: the share of its speed the unit makes along `heading` facing `bearing`.
pub fn pace(unit: &Mover, heading: V2, bearing: f64) -> f64 {
    if (heading.length() as f64) < EPSILON {
        return 1.0;
    }
    let cosine = clampf(heading.normalized().dot(bearing_vector(bearing)) as f64, -1.0, 1.0);
    let off = rad_to_deg(det_math::acos(cosine)) / 180.0;
    1.0 - (1.0 - unit.backward_pace) * off
}

/// UnitShuffle._turning: seconds the unit takes to turn from one bearing to another.
fn turning(unit: &Mover, from: f64, to: f64) -> f64 {
    let cosine = clampf(bearing_vector(from).dot(bearing_vector(to)) as f64, -1.0, 1.0);
    rad_to_deg(det_math::acos(cosine)) / maxf(unit.turn_rate, EPSILON)
}

/// UnitShuffle.look: the point the unit should look towards walking from `at` to `to`, to
/// arrive facing `bearing` soonest; `speed` is its full speed in cells a second.
pub fn look(unit: &Mover, at: V2, to: V2, bearing: f64, speed: f64) -> V2 {
    let way = to.sub(at);
    let ahead = at.add(bearing_vector(bearing));
    let length = way.length() as f64;
    if length < EPSILON || speed < EPSILON {
        return ahead;
    }
    let heading = bearing_to(at, to, unit.bearing);
    let facing_pace = maxf(pace(unit, way, bearing), EPSILON);
    let shuffling = turning(unit, unit.bearing, bearing) + length / (speed * facing_pace);
    let walking =
        turning(unit, unit.bearing, heading) + length / speed + turning(unit, heading, bearing);
    if shuffling <= walking {
        ahead
    } else {
        to
    }
}

/// UnitMotion._apart: degrees from `from` to `to` the short way round, in (-180, 180].
fn apart(from: f64, to: f64) -> f64 {
    let turn = fposmod(to - from, 360.0);
    if turn > 180.0 + EPSILON {
        turn - 360.0
    } else {
        turn
    }
}

/// UnitMotion.turn: the unit's bearing after turning towards `wanted` by what its turn
/// rate allows in `seconds`.
pub fn turn(unit: &Mover, wanted: f64, seconds: f64) -> f64 {
    let left = apart(unit.bearing, wanted);
    if left.abs() < EPSILON {
        return fposmod(wanted, 360.0);
    }
    let reach = unit.turn_rate * seconds;
    if reach >= left.abs() - EPSILON {
        return fposmod(wanted, 360.0);
    }
    let sign = if left > 0.0 {
        1.0
    } else if left < 0.0 {
        -1.0
    } else {
        0.0
    };
    fposmod(unit.bearing + sign * reach, 360.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn godot_s_helpers() {
        assert_eq!(rad_to_deg(1.0).to_bits(), 0x404ca5dc1a63c1f8); // printed by Godot
        assert_eq!(fposmod(-90.0, 360.0), 270.0);
        assert_eq!(fposmod(-0.0, 360.0).to_bits(), 0);
        assert_eq!(fposmod(720.0, 360.0).to_bits(), 0);
        assert_eq!(bearing_to(V2::ZERO, V2::new(1.0, 0.0), 7.0), 90.0);
        assert_eq!(bearing_to(V2::ZERO, V2::new(0.0, 1.0), 7.0), 180.0);
        assert_eq!(bearing_to(V2::ZERO, V2::ZERO, 7.0), 7.0);
    }

    #[test]
    fn turning_is_limited_by_the_turn_rate() {
        let unit = Mover { bearing: 350.0, turn_rate: 100.0, backward_pace: 0.4 };
        assert_eq!(turn(&unit, 20.0, 0.1), 0.0); // 10 of the 30 degrees, clockwise
        assert_eq!(turn(&unit, 355.0, 0.1), 355.0);
        assert_eq!(turn(&unit, 170.0, 0.1), 0.0); // an about-turn goes clockwise
    }
}
