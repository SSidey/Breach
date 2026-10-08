#!/usr/bin/env bash
# Builds the native spike's libraries into native/bin/ (git-ignored): the Rust kernel
# (godot-rust) and the C++ kernel (godot-cpp). See native/README.md.
#
#   bash native/build.sh [rust] [cpp]     # default: both
#
# Env: JOBS (default 2), GODOT_CPP_REF (the pinned godot-cpp commit), GODOT_CPP_DIR (where
# godot-cpp is cloned: outside the repo, by default ~/.cache/breach-native/godot-cpp-<ref>).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
jobs="${JOBS:-2}"
# godot-cpp master as of 2026-10-07: bundles extension_api-4-7.json.
godot_cpp_ref="${GODOT_CPP_REF:-272e7f4a5fde342ea20983371fffafdccea07f20}"
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(rust cpp)

case "$(uname -s)" in
	Linux) platform=linux.x86_64; prefix=lib; ext=so ;;
	Darwin) platform=macos.universal; prefix=lib; ext=dylib ;;
	MINGW* | MSYS* | CYGWIN*) platform=windows.x86_64; prefix=; ext=dll ;;
	*) echo "build.sh: unknown platform $(uname -s)"; exit 1 ;;
esac
mkdir -p "$here/bin"

build_rust() {
	cargo build --release -j "$jobs" --manifest-path "$here/rust/Cargo.toml"
	local built="$here/rust/target/release/${prefix}breach_native.$ext"
	cp "$built" "$here/bin/${prefix}breach_rust.$platform.$ext"
}

build_cpp() {
	local cache="${XDG_CACHE_HOME:-$HOME/.cache}/breach-native"
	local deps="${GODOT_CPP_DIR:-$cache/godot-cpp-${godot_cpp_ref:0:12}}"
	if [ ! -d "$deps/.git" ]; then
		git clone --filter=blob:none https://github.com/godotengine/godot-cpp "$deps"
	fi
	git -C "$deps" fetch --quiet origin "$godot_cpp_ref" || true
	git -C "$deps" checkout --quiet "$godot_cpp_ref"
	cmake -S "$here/cpp" -B "$here/cpp/build" -DCMAKE_BUILD_TYPE=Release -DGODOT_CPP_DIR="$deps" \
		-DGODOTCPP_TARGET=template_release -DGODOTCPP_API_VERSION=4.7
	cmake --build "$here/cpp/build" --config Release -j "$jobs" --target breach_cpp
	local built
	built="$(find "$here/cpp/build" -name "${prefix}breach_cpp*.$ext" | head -n 1)"
	cp "$built" "$here/bin/${prefix}breach_cpp.$platform.$ext"
}

for target in "${targets[@]}"; do
	"build_$target"
done
ls -l "$here/bin"
