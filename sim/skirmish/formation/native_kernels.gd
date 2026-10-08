class_name NativeKernels
extends RefCounted
## The native spike's one switch (native/README.md): which implementation runs UnitBodies'
## body-parting pass - "gdscript" (the default and the reference), "rust" (godot-rust) or
## "cpp" (godot-cpp). Read from the BREACH_NATIVE environment variable, else the project
## setting breach/native/engine; tests and the bench set it with use(). A native engine
## whose library isn't built (native/build.sh) quietly falls back to GDScript, so a checkout
## without the binaries plays exactly as before. BREACH_NATIVE_THREADS=1 lets the Rust
## kernel find and weigh pairs on its thread pool (applied in a fixed order all the same).
## Every engine gives bit-identical outcomes (tools/formation_digest.gd).

const GDSCRIPT := "gdscript"
## engine -> [its .gdextension, the class it registers, its library's base name]
const LIBRARIES := {
	"rust": ["res://native/breach_rust.gdextension", "BodyPartingRust", "breach_rust"],
	"cpp": ["res://native/breach_cpp.gdextension", "BodyPartingCpp", "breach_cpp"],
}

## Whether a native kernel may use threads (Rust's Rayon pool).
static var threaded := false
static var _engine := ""
static var _kernels := {}


## The engine chosen: use()'s, else BREACH_NATIVE's, else the project setting's.
static func engine() -> String:
	if _engine == "":
		_engine = OS.get_environment("BREACH_NATIVE")
		if _engine == "":
			_engine = str(ProjectSettings.get_setting("breach/native/engine", GDSCRIPT))
		threaded = OS.get_environment("BREACH_NATIVE_THREADS") == "1"
	return _engine


## Picks the engine from now on ("gdscript", "rust" or "cpp").
static func use(engine_name: String) -> void:
	_engine = engine_name


## True if the engine runs here: GDScript always, a native one once its library is built.
static func available(engine_name: String) -> bool:
	if engine_name == GDSCRIPT:
		return true
	if not LIBRARIES.has(engine_name):
		return false
	var library: Array = LIBRARIES[engine_name]
	if not ClassDB.class_exists(library[1]) and FileAccess.file_exists(_binary(library[2])):
		GDExtensionManager.load_extension(library[0])
	return ClassDB.class_exists(library[1])


## The chosen engine's body-parting kernel, or null to run the GDScript passes.
static func body_parting() -> Object:
	var engine_name := engine()
	if engine_name == GDSCRIPT:
		return null
	if not _kernels.has(engine_name):
		var built := available(engine_name)
		_kernels[engine_name] = ClassDB.instantiate(LIBRARIES[engine_name][1]) if built else null
	return _kernels[engine_name]


## Where native/build.sh puts the library for this platform.
static func _binary(library_name: String) -> String:
	match OS.get_name():
		"Windows":
			return "res://native/bin/%s.windows.x86_64.dll" % library_name
		"macOS":
			return "res://native/bin/lib%s.macos.universal.dylib" % library_name
	return "res://native/bin/lib%s.linux.x86_64.so" % library_name
