// Breach's native spike in C++ (godot-cpp): UnitBodies' body-parting pass as the
// GDExtension class BodyPartingCpp. The GDScript side is
// sim/skirmish/formation/body_parting.gd; the switch is BREACH_NATIVE.

#include <chrono>

#include <gdextension_interface.h>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

#include "parting.hpp"

using namespace godot;

namespace {

std::vector<breach::V2> to_v2(const PackedVector2Array &a) {
	std::vector<breach::V2> out(a.size());
	const Vector2 *p = a.ptr();
	for (size_t i = 0; i < out.size(); i++) {
		out[i] = { p[i].x, p[i].y };
	}
	return out;
}

PackedVector2Array to_packed(const std::vector<breach::V2> &v) {
	PackedVector2Array out;
	out.resize(static_cast<int64_t>(v.size()));
	Vector2 *p = out.ptrw();
	for (size_t i = 0; i < v.size(); i++) {
		p[i] = Vector2(v[i].x, v[i].y);
	}
	return out;
}

} // namespace

// UnitBodies.step's passes over packed arrays: data in, new points out. The same contract
// as native/rust's BodyPartingRust::part (threaded is accepted and ignored: no pool here).
class BodyPartingCpp : public RefCounted {
	GDCLASS(BodyPartingCpp, RefCounted)

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("part", "points", "bases", "nexts", "radii", "areas", "squads",
									 "factions", "flags", "tuning", "way", "threaded"),
				&BodyPartingCpp::part);
	}

public:
	Array part(const PackedVector2Array &points, const PackedVector2Array &bases,
			const PackedVector2Array &nexts, const PackedFloat64Array &radii,
			const PackedFloat64Array &areas, const PackedInt32Array &squads,
			const PackedInt32Array &factions, const PackedByteArray &flags,
			const PackedFloat64Array &tuning, const Callable &way, bool threaded) {
		(void)threaded;
		const std::vector<breach::V2> base_points = to_v2(bases);
		breach::Bodies bodies;
		bodies.points = to_v2(points);
		bodies.nexts = to_v2(nexts);
		bodies.flags.assign(flags.ptr(), flags.ptr() + flags.size());
		bodies.bases = base_points.data();
		bodies.radii = radii.ptr();
		bodies.areas = areas.ptr();
		bodies.squads = squads.ptr();
		bodies.factions = factions.ptr();
		const breach::Tuning t{ static_cast<int64_t>(tuning[0]), tuning[1], tuning[2] };
		auto ask = [&way](int64_t i, int64_t j) -> breach::V2 {
			const Vector2 w = way.call(i, j);
			return { w.x, w.y };
		};
		const auto began = std::chrono::steady_clock::now();
		const breach::Outcome outcome = breach::part(bodies, t, ask);
		const auto usec = std::chrono::duration_cast<std::chrono::microseconds>(
				std::chrono::steady_clock::now() - began)
								  .count();
		PackedByteArray out_flags;
		out_flags.resize(static_cast<int64_t>(bodies.flags.size()));
		std::copy(bodies.flags.begin(), bodies.flags.end(), out_flags.ptrw());
		PackedInt32Array loosened;
		for (int32_t i : outcome.loosened) {
			loosened.push_back(i);
		}
		PackedInt64Array stats;
		stats.push_back(usec);
		stats.push_back(outcome.passes);
		stats.push_back(outcome.pairs);
		Array out;
		out.push_back(to_packed(bodies.points));
		out.push_back(to_packed(bodies.nexts));
		out.push_back(out_flags);
		out.push_back(loosened);
		out.push_back(stats);
		return out;
	}
};

namespace {

void initialize(ModuleInitializationLevel level) {
	if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		GDREGISTER_CLASS(BodyPartingCpp);
	}
}

void uninitialize(ModuleInitializationLevel) {}

} // namespace

extern "C" {
GDExtensionBool GDE_EXPORT breach_cpp_init(GDExtensionInterfaceGetProcAddress get_proc_address,
		GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
	init.register_initializer(initialize);
	init.register_terminator(uninitialize);
	init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init.init();
}
}
