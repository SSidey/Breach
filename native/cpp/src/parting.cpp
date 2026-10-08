#include "parting.hpp"

#include <algorithm>
#include <cmath>
#include <unordered_map>

namespace breach {
namespace {

constexpr float BUCKET = 2.0f; // UnitBodies.BUCKET
constexpr double EPSILON = 0.001; // UnitBodies.EPSILON

inline V2 add(V2 a, V2 b) { return { a.x + b.x, a.y + b.y }; }
inline V2 sub(V2 a, V2 b) { return { a.x - b.x, a.y - b.y }; }
// `Vector2 * float`: the GDScript float (double) is narrowed to real_t first.
inline V2 scale(V2 a, double s) {
	const float f = static_cast<float>(s);
	return { a.x * f, a.y * f };
}
// Vector2::length: Math::sqrt(x * x + y * y) in real_t.
inline float length(V2 a) { return std::sqrt(a.x * a.x + a.y * a.y); }
// Vector2::normalized.
inline V2 normalized(V2 a) {
	float l = a.x * a.x + a.y * a.y;
	if (l != 0.0f) {
		l = std::sqrt(l);
		return { a.x / l, a.y / l };
	}
	return a;
}
inline bool equal(V2 a, V2 b) { return a.x == b.x && a.y == b.y; }
inline bool framed(uint8_t flags) { return (flags & (LOOSE | FLEEING)) == 0; }

inline uint64_t key(int32_t x, int32_t y) {
	return (static_cast<uint64_t>(static_cast<uint32_t>(x)) << 32) | static_cast<uint32_t>(y);
}

std::vector<V2> positions(const Bodies &b) {
	std::vector<V2> at(b.points.size());
	for (size_t i = 0; i < at.size(); i++) {
		at[i] = (b.flags[i] & FLEEING) ? add(b.bases[i], b.points[i]) : b.points[i];
	}
	return at;
}

// [(i, j), ...] sorted, for bodies that overlap, not both framed (UnitBodies._pairs).
std::vector<uint64_t> pairs(const Bodies &b, const std::vector<V2> &at) {
	const size_t count = at.size();
	std::vector<std::pair<int32_t, int32_t>> homes(count);
	std::unordered_map<uint64_t, std::vector<uint32_t>> buckets;
	buckets.reserve(count);
	for (size_t i = 0; i < count; i++) {
		homes[i] = { static_cast<int32_t>(std::floor(at[i].x / BUCKET)),
			static_cast<int32_t>(std::floor(at[i].y / BUCKET)) };
		buckets[key(homes[i].first, homes[i].second)].push_back(static_cast<uint32_t>(i));
	}
	std::vector<uint64_t> found;
	for (size_t index = 0; index < count; index++) {
		if (framed(b.flags[index])) {
			continue;
		}
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				auto it = buckets.find(key(homes[index].first + dx, homes[index].second + dy));
				if (it == buckets.end()) {
					continue;
				}
				for (uint32_t o : it->second) {
					const size_t other = o;
					if (!framed(b.flags[other]) && other <= index) {
						continue;
					}
					const size_t one = std::min(index, other);
					const size_t two = std::max(index, other);
					const V2 apart = sub(at[two], at[one]);
					if (b.radii[one] + b.radii[two] - static_cast<double>(length(apart)) > EPSILON) {
						found.push_back(one * count + two);
					}
				}
			}
		}
	}
	std::sort(found.begin(), found.end());
	return found;
}

double mass(const Bodies &b, const Tuning &t, size_t i) {
	return framed(b.flags[i]) ? b.areas[i] * t.resist : b.areas[i];
}

bool keeps(const Bodies &b, const Tuning &t, size_t keeper, size_t other, double depth) {
	if (!framed(b.flags[keeper]) || !(b.flags[other] & LOOSE)) {
		return false;
	}
	return b.squads[keeper] != b.squads[other] || depth < t.brush;
}

// UnitBodies._move.
void apply(Bodies &b, size_t i, V2 push, std::vector<int32_t> &loosened) {
	const uint8_t flags = b.flags[i];
	b.flags[i] |= MOVED;
	if (flags & FLEEING) {
		b.points[i] = add(b.points[i], push);
		return;
	}
	if (!(flags & LOOSE)) {
		b.flags[i] |= LOOSE;
		b.nexts[i] = b.points[i];
		loosened.push_back(static_cast<int32_t>(i));
	}
	const bool resting = equal(b.nexts[i], b.points[i]);
	b.points[i] = add(b.points[i], push);
	if (resting) {
		b.nexts[i] = b.points[i];
	}
}

} // namespace

Outcome part(Bodies &b, const Tuning &t, const std::function<V2(int64_t, int64_t)> &way) {
	const size_t count = b.points.size();
	Outcome out;
	std::vector<V2> moves(count);
	std::vector<char> has_move(count, 0);
	std::vector<size_t> order;
	order.reserve(count);
	auto accumulate = [&](size_t i, V2 v, bool minus) {
		if (!has_move[i]) {
			has_move[i] = 1;
			order.push_back(i);
		}
		moves[i] = minus ? sub(moves[i], v) : add(moves[i], v);
	};
	for (int64_t pass = 0; pass < t.passes; pass++) {
		const std::vector<V2> at = positions(b);
		const std::vector<uint64_t> found = pairs(b, at);
		out.pairs += static_cast<int64_t>(found.size());
		order.clear();
		for (uint64_t k : found) {
			const size_t a = k / count;
			const size_t c = k % count;
			// UnitBodies._push.
			const V2 apart = sub(at[c], at[a]);
			const double depth = b.radii[a] + b.radii[c] - static_cast<double>(length(apart));
			if (depth <= EPSILON) {
				continue;
			}
			V2 w = normalized(apart);
			if (static_cast<double>(length(apart)) < EPSILON) {
				w = way(static_cast<int64_t>(a), static_cast<int64_t>(c));
			}
			double share = 0.5;
			if (b.factions[a] == b.factions[c]) {
				share = mass(b, t, c) / (mass(b, t, a) + mass(b, t, c));
				if (keeps(b, t, a, c, depth)) {
					share = 0.0;
				} else if (keeps(b, t, c, a, depth)) {
					share = 1.0;
				}
			}
			if (share > 0.0) {
				accumulate(a, scale(scale(w, depth), share), true);
			}
			if (share < 1.0) {
				accumulate(c, scale(scale(w, depth), 1.0 - share), false);
			}
		}
		if (order.empty()) {
			break;
		}
		out.passes++;
		for (size_t i : order) {
			apply(b, i, moves[i], out.loosened);
			moves[i] = V2{};
			has_move[i] = 0;
		}
	}
	return out;
}

} // namespace breach
