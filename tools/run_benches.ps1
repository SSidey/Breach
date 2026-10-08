# Runs Breach's simulation benchmarks on this machine and writes one report to compare with
# others (native/README.md, "Running the benchmarks locally"). Windows PowerShell 5.1 or
# PowerShell 7 on any platform:
#
#   powershell -ExecutionPolicy Bypass -File tools\run_benches.ps1 -Godot <Godot exe>
#       [-Side 1024] [-SkipDigests] [-SkipGdscript]
#
# On Windows use Godot 4.7.2's console build (Godot_v4.7.2-stable_win64_console.exe) so
# its output reaches the report. Build the native core first (native\build.ps1, or
# native/build.sh elsewhere). Steps:
#   1. identity: the per-tick digests under each engine, against the reference hashes -
#      the same battles must replay bit for bit on every machine and engine
#   2. a whole tick, phase by phase (tools/tick_phases.gd), mid-fight and marching
#   3. the native core's passes (tools/native_bench.gd)
# The report lands in reports\bench\ (git-ignored).
param(
	[Parameter(Mandatory = $true)][string]$Godot,
	[int]$Side = 1024,
	[switch]$SkipDigests,
	[switch]$SkipGdscript
)
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$out = Join-Path $root "reports\bench"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$machine = [Environment]::MachineName
$report = Join-Path $out "bench_${machine}_$stamp.txt"

# The per-tick digest files' sha256 on the reference (Linux) build.
$reference = @{
	"standard" = "bf2111e4aef6d3c4b2aa51350e65d6e6fd087ab82641762a74d3af6b9304c908"
	"clash160" = "a0b69851c6636a6eb8ed39234c7cb23c1fe06be70d1b88dac13d3c690d9cbd79"
	"wide"     = "6236171952e39ccd6ca2368ec01f190814df13dc6bab9dcf0f490248442f55b0"
}

function Write-Report([string]$text) {
	Write-Host $text
	Add-Content -Path $report -Value $text
}

function Invoke-Godot([string]$script, [string[]]$arguments, [string]$engine) {
	$env:BREACH_NATIVE = $engine
	$all = @("--headless", "--path", $root, "--script", $script, "--") + $arguments
	& $Godot @all 2>&1 | ForEach-Object { "$_" } |
		Where-Object { $_ -notmatch "^\s+at:|ObjectDB instances|resources still in use|PagedAllocator" }
}

Write-Report "Breach benchmarks - $machine - $(Get-Date -Format s)"
$onWindows = [Environment]::OSVersion.Platform -eq "Win32NT"
if ($onWindows) {
	$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1)
	$memory = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
	$cores = "$($cpu.NumberOfCores) cores, $($cpu.NumberOfLogicalProcessors) threads"
	Write-Report "CPU: $($cpu.Name.Trim()) - $cores, $($cpu.MaxClockSpeed) MHz"
	Write-Report "Memory: $memory GB"
	$dll = Join-Path $root "native\bin\breach_rust.windows.x86_64.dll"
} else {
	$name = (Select-String -Path /proc/cpuinfo -Pattern "model name" | Select-Object -First 1)
	Write-Report "CPU: $(($name.Line -split ':', 2)[1].Trim()) - $([Environment]::ProcessorCount) threads"
	Write-Report "Memory: $((Select-String -Path /proc/meminfo -Pattern 'MemTotal').Line)"
	$dll = Join-Path $root "native/bin/libbreach_rust.linux.x86_64.so"
}
Write-Report "Commit: $(git -C $root rev-parse --short HEAD) ($(git -C $root rev-parse --abbrev-ref HEAD))"
$engines = @("rust")
if (-not (Test-Path $dll)) {
	Write-Report "WARNING: $dll missing - build the native core first; Rust runs skipped"
	$engines = @()
}
if (-not $SkipGdscript) { $engines = @("gdscript") + $engines }
Write-Report "Engines: $($engines -join ', ')"

Write-Report "`n== Importing the project"
& $Godot --headless --path $root --import 2>&1 | Out-Null

if (-not $SkipDigests) {
	Write-Report "`n== Identity: per-tick digests against the reference build"
	foreach ($engine in $engines) {
		foreach ($set in $reference.Keys) {
			$file = Join-Path $out "digest_${set}_$engine.txt"
			Invoke-Godot "res://tools/formation_digest.gd" @("set=$set", "out=$file") $engine | Out-Null
			$hash = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower()
			$verdict = if ($hash -eq $reference[$set]) { "matches" } else { "DIFFERS from $($reference[$set])" }
			Write-Report ("{0,-9} {1,-9} {2} {3}" -f $engine, $set, $hash, $verdict)
		}
	}
}

Write-Report "`n== A tick, phase by phase ($Side a side; ms a tick)"
foreach ($engine in $engines) {
	foreach ($stage in @("fight", "march")) {
		Write-Report "-- $engine, $stage"
		Invoke-Godot "res://tools/tick_phases.gd" @("engine=$engine", "side=$Side", "stage=$stage", "fight=5") $engine |
			Where-Object { $_ -match "machine:|ms a tick|^\s+\S|WARNING" } | ForEach-Object { Write-Report $_ }
	}
}

Write-Report "`n== The native core's passes (tools/native_bench.gd)"
$list = ($engines -join ",")
Invoke-Godot "res://tools/native_bench.gd" @("engines=$list", "runs=3") "" |
	Where-Object { $_ -notmatch "^Godot Engine|^Initialize|^$" } | ForEach-Object { Write-Report $_ }

Write-Report "`nReport: $report"
