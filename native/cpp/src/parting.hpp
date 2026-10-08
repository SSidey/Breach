// The body-parting pass of sim/skirmish/formation/unit_bodies.gd, over plain arrays.
//
// Every operation mirrors the GDScript path's precision and order, so results are bit for
// bit the same: Vector2 maths in float (Godot's real_t), GDScript floats in double, a
// `Vector2 * float` narrowing the float to real_t first, the same summation order. Built
// with -ffp-contract=off (/fp:precise on MSVC) and no fast-math, so nothing is fused.
#pragma once

#include <cstdint>
#include <functional>
#include <vector>

namespace breach {

constexpr uint8_t LOOSE = 1;
constexpr uint8_t FLEEING = 2;
constexpr uint8_t MOVED = 4;

struct V2 {
	float x = 0.0f;
	float y = 0.0f;
};

// The bodies of one step: what moves (points, nexts, flags) and what doesn't.
struct Bodies {
	std::vector<V2> points; // a fleeing body's offset, a loose body's point, a framed one's place
	std::vector<V2> nexts; // a loose body's next point
	std::vector<uint8_t> flags;
	const V2 *bases = nullptr; // a fleeing body's point on its route
	const double *radii = nullptr;
	const double *areas = nullptr;
	const int32_t *squads = nullptr;
	const int32_t *factions = nullptr;
};

struct Tuning {
	int64_t passes = 0;
	double resist = 0.0;
	double brush = 0.0;
};

struct Outcome {
	int64_t passes = 0;
	int64_t pairs = 0;
	std::vector<int32_t> loosened;
};

// Pushes apart every pair of bodies that overlap (UnitBodies' passes). `way(i, j)` gives
// the seeded way two bodies lying on each other part (a call back into GDScript).
Outcome part(Bodies &bodies, const Tuning &tuning, const std::function<V2(int64_t, int64_t)> &way);

} // namespace breach
