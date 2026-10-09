//! `DetMath.sin` and `DetMath.cos` (sim/skirmish/formation/det_math.gd), operation for
//! operation in the same order, so they give the same bits as the GDScript and the same
//! bits on every platform (Decision 93). The C library's sin and cos are not correctly
//! rounded and differ between glibc, the Windows CRT and Apple's libm; these use only
//! `+`, `-`, `*` and `floor`, which IEEE 754 fixes exactly. fdlibm's Cody-Waite reduction
//! by pi/2 in three exact parts, then its minimax kernels. Rust never fuses `a * b + c`.

const S1: f64 = f64::from_bits(0xbfc5555555555549); // -1.66666666666666324348e-01
const S2: f64 = f64::from_bits(0x3f8111111110f8a6); // 8.33333333332248946124e-03
const S3: f64 = f64::from_bits(0xbf2a01a019c161d5); // -1.98412698298579493134e-04
const S4: f64 = f64::from_bits(0x3ec71de357b1fe7d); // 2.75573137070700676789e-06
const S5: f64 = f64::from_bits(0xbe5ae5e68a2b9ceb); // -2.50507602534068634195e-08
const S6: f64 = f64::from_bits(0x3de5d93a5acfd57c); // 1.58969099521155010221e-10
const C1: f64 = f64::from_bits(0x3fa555555555554c); // 4.16666666666666019037e-02
const C2: f64 = f64::from_bits(0xbf56c16c16c15177); // -1.38888888888741095749e-03
const C3: f64 = f64::from_bits(0x3efa01a019cb1590); // 2.48015872894767294178e-05
const C4: f64 = f64::from_bits(0xbe927e4f809c52ad); // -2.75573143513906633035e-07
const C5: f64 = f64::from_bits(0x3e21ee9ebdb4b1c4); // 2.08757232129817482790e-09
const C6: f64 = f64::from_bits(0xbda8fae9be8838d4); // -1.13596475577881948265e-11
const PIO2_1: f64 = f64::from_bits(0x3ff921fb54400000); // 1.57079632673412561417e+00
const PIO2_2: f64 = f64::from_bits(0x3dd0b4611a600000); // 6.07710050630396597660e-11
const PIO2_3: f64 = f64::from_bits(0x3ba3198a2e000000); // 2.02226624871116645580e-21
const INVPIO2: f64 = f64::from_bits(0x3fe45f306dc9c883); // 6.36619772367581382433e-01

/// `DetMath.sin`: sin(x), x in radians.
pub fn sin(x: f64) -> f64 {
    let k = (x * INVPIO2 + 0.5).floor();
    let r = reduced(x, k);
    let quarter = k - 4.0 * (k * 0.25).floor();
    if quarter == 0.0 {
        sin_kernel(r)
    } else if quarter == 1.0 {
        cos_kernel(r)
    } else if quarter == 2.0 {
        -sin_kernel(r)
    } else {
        -cos_kernel(r)
    }
}

/// `DetMath.cos`: cos(x), x in radians.
pub fn cos(x: f64) -> f64 {
    let k = (x * INVPIO2 + 0.5).floor();
    let r = reduced(x, k);
    let quarter = k - 4.0 * (k * 0.25).floor();
    if quarter == 0.0 {
        cos_kernel(r)
    } else if quarter == 1.0 {
        -sin_kernel(r)
    } else if quarter == 2.0 {
        -cos_kernel(r)
    } else {
        sin_kernel(r)
    }
}

/// x less k times pi/2, the three parts of pi/2 taken off in turn (each product exact).
#[inline]
fn reduced(x: f64, k: f64) -> f64 {
    ((x - k * PIO2_1) - k * PIO2_2) - k * PIO2_3
}

/// sin on [-pi/4, pi/4] (fdlibm __kernel_sin).
#[inline]
fn sin_kernel(x: f64) -> f64 {
    let z = x * x;
    let v = z * x;
    let r = S2 + z * (S3 + z * (S4 + z * (S5 + z * S6)));
    x + v * (S1 + z * r)
}

/// cos on [-pi/4, pi/4] (fdlibm __kernel_cos).
#[inline]
fn cos_kernel(x: f64) -> f64 {
    let z = x * x;
    let r = z * (C1 + z * (C2 + z * (C3 + z * (C4 + z * (C5 + z * C6)))));
    let hz = 0.5 * z;
    let w = 1.0 - hz;
    w + (((1.0 - w) - hz) + z * r)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Inputs and the bits DetMath.sin and DetMath.cos give for them, printed by Godot
    // 4.7.2: radians from 1e-9 to 12345.678 and the bearings' deg_to_rad of 0 to 359.
    const CASES: [(f64, u64, u64); 26] = [
        (
            f64::from_bits(0x0000000000000000),
            0x0000000000000000,
            0x3ff0000000000000,
        ),
        (
            f64::from_bits(0x3e112e0be826d695),
            0x3e112e0be826d695,
            0x3ff0000000000000,
        ),
        (
            f64::from_bits(0x3fe0000000000000),
            0x3fdeaee8744b05f0,
            0x3fec1528065b7d50,
        ),
        (
            f64::from_bits(0xbfe8000000000000),
            0xbfe5cffc16bf8f0d,
            0x3fe769fec655211f,
        ),
        (
            f64::from_bits(0x3ff0000000000000),
            0x3feaed548f090cee,
            0x3fe14a280fb5068c,
        ),
        (
            f64::from_bits(0x3fe921fb54442d18),
            0x3fe6a09e667f3bcc,
            0x3fe6a09e667f3bcd,
        ),
        (
            f64::from_bits(0x3ff921fb54442d18),
            0x3ff0000000000000,
            0x3c91a62633145c00,
        ),
        (
            f64::from_bits(0x400921fb54442d18),
            0x3ca1a62633145c00,
            0xbff0000000000000,
        ),
        (
            f64::from_bits(0x4000000000000000),
            0x3fed18f6ead1b446,
            0xbfdaa22657537205,
        ),
        (
            f64::from_bits(0x4008000000000000),
            0x3fc210386db6d55b,
            0xbfefae04be85e5d2,
        ),
        (
            f64::from_bits(0xc00c000000000000),
            0x3fd6733b7eba621f,
            0xbfedf77403c11a5f,
        ),
        (
            f64::from_bits(0x401921fb54442d18),
            0xbcb1a62633145c00,
            0x3ff0000000000000,
        ),
        (
            f64::from_bits(0x4024000000000000),
            0xbfe1689ef5f34f53,
            0xbfead9ac890c6b1f,
        ),
        (
            f64::from_bits(0xc059000000000000),
            0x3fe03425b78c4db8,
            0x3feb981dbf665fdf,
        ),
        (
            f64::from_bits(0x408f420000000000),
            0x3fee1702343c0531,
            0x3fd5c7d948a31cf2,
        ),
        (
            f64::from_bits(0x40c81cd6c8b43958),
            0xbfe687d5890974a5,
            0x3fe6b94c3bbe24b8,
        ),
        (
            f64::from_bits(0x0000000000000000),
            0x0000000000000000,
            0x3ff0000000000000,
        ),
        (
            f64::from_bits(0x3fe0c152382d7365),
            0x3fdfffffffffffff,
            0x3febb67ae8584cab,
        ),
        (
            f64::from_bits(0x3fe921fb54442d18),
            0x3fe6a09e667f3bcc,
            0x3fe6a09e667f3bcd,
        ),
        (
            f64::from_bits(0x3ff921fb54442d18),
            0x3ff0000000000000,
            0x3c91a62633145c00,
        ),
        (
            f64::from_bits(0x4002d97c7f3321d2),
            0x3fe6a09e667f3bcd,
            0xbfe6a09e667f3bcc,
        ),
        (
            f64::from_bits(0x400921fb54442d18),
            0x3ca1a62633145c00,
            0xbff0000000000000,
        ),
        (
            f64::from_bits(0x400f111dc8299b4c),
            0xbfe59e6f5ae6a0a6,
            0xbfe797c6a435ce85,
        ),
        (
            f64::from_bits(0x4012d97c7f3321d2),
            0xbff0000000000000,
            0xbcaa79394c9e8a00,
        ),
        (
            f64::from_bits(0x4019101c0da1da7b),
            0xbf91df0b2b89dd2c,
            0x3feffec097f5af8a,
        ),
        (
            f64::from_bits(0x40178fdb9effea47),
            0xbfd87de2a6aea95f,
            0x3fed906bcf328d47,
        ),
    ];

    #[test]
    fn matches_the_gdscript() {
        for &(x, s, c) in CASES.iter() {
            assert_eq!(sin(x).to_bits(), s, "sin({x})");
            assert_eq!(cos(x).to_bits(), c, "cos({x})");
        }
    }
}
