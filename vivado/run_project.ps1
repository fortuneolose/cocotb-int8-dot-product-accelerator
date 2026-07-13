param(
    [ValidateSet("Create", "Simulate", "Synthesize", "Implement")]
    [string]$Action = "Simulate",
    [string]$Part = "",
    [string]$VivadoExecutable = "vivado.bat"
)

$ErrorActionPreference = "Stop"
$ScriptDirectory = $PSScriptRoot

$TclScript = switch ($Action) {
    "Create"     { Join-Path $ScriptDirectory "create_project.tcl" }
    "Simulate"   { Join-Path $ScriptDirectory "run_project_simulation.tcl" }
    "Synthesize" { Join-Path $ScriptDirectory "run_synthesis.tcl" }
    "Implement"  { Join-Path $ScriptDirectory "run_implementation.tcl" }
}

$VivadoArguments = @("-mode", "batch", "-source", $TclScript)
if ($Part) {
    $VivadoArguments += @("-tclargs", $Part)
}

if ($Action -in @("Synthesize", "Implement") -and -not $Part) {
    throw "$Action requires -Part with the exact FPGA device name."
}

& $VivadoExecutable @VivadoArguments
if ($LASTEXITCODE -ne 0) {
    throw "Vivado $Action failed with exit code $LASTEXITCODE"
}

if ($Action -eq "Create") {
    $ProjectFile = Join-Path $ScriptDirectory "build\int8_dot_product_vivado.xpr"
    Write-Host "Project created: $ProjectFile"
}
