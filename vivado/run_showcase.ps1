[CmdletBinding()]
param(
    [switch]$OpenGui
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = Join-Path $repoRoot "build"
$workDir = Join-Path $buildRoot "xsim_work"
$waveDir = Join-Path $repoRoot "artifacts\waves"
$wdb = Join-Path $waveDir "vivado_dot_product.wdb"
$createProject = Join-Path $PSScriptRoot "create_project.tcl"
$runTcl = Join-Path $PSScriptRoot "run_xsim.tcl"
$openWaveform = Join-Path $PSScriptRoot "open_waveform.tcl"
$simLog = Join-Path $waveDir "vivado_xsim.log"

New-Item -ItemType Directory -Force -Path $buildRoot, $workDir, $waveDir | Out-Null

$vivadoBin = $env:VIVADO_BIN
if ([string]::IsNullOrWhiteSpace($vivadoBin)) {
    $foundVivado = Get-Command vivado.bat -ErrorAction SilentlyContinue
    if ($null -ne $foundVivado) {
        $vivadoBin = Split-Path -Parent $foundVivado.Source
    } else {
        $vivadoBin = "C:\Xilinx\2025.1.1\Vivado\bin"
    }
}

$vivado = Join-Path $vivadoBin "vivado.bat"
$xvlog = Join-Path $vivadoBin "xvlog.bat"
$xelab = Join-Path $vivadoBin "xelab.bat"
$xsim = Join-Path $vivadoBin "xsim.bat"

foreach ($tool in @($vivado, $xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Vivado executable not found: $tool. Set VIVADO_BIN to the Vivado bin directory."
    }
}

function Invoke-Checked {
    param(
        [string]$Program,
        [string[]]$Arguments
    )
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE"
    }
}

Invoke-Checked $vivado @("-mode", "batch", "-source", $createProject)

Push-Location $workDir
try {
    $rtl = Join-Path $repoRoot "rtl\dot_product_int8_vivado.v"
    $tb = Join-Path $repoRoot "tb\tb_dot_product_int8_vivado.sv"
    Invoke-Checked $xvlog @("-sv", "-work", "xil_defaultlib", $rtl, $tb)
    Invoke-Checked $xelab @("-debug", "typical", "-timescale", "1ns/1ps", "-s", "tb_dot_product_int8_vivado", "xil_defaultlib.tb_dot_product_int8_vivado")

    $runTclForXsim = $runTcl.Replace('\', '/')
    $wdbForXsim = $wdb.Replace('\', '/')
    if (Test-Path -LiteralPath $wdb) {
        Remove-Item -LiteralPath $wdb -Force
    }

    $xsimOutput = & $xsim @("tb_dot_product_int8_vivado", "-wdb", $wdbForXsim, "-t", $runTclForXsim) 2>&1
    $xsimExitCode = $LASTEXITCODE
    $xsimOutput | Tee-Object -FilePath $simLog
    if ($xsimExitCode -ne 0) {
        throw "$xsim failed with exit code $xsimExitCode"
    }
    if (($xsimOutput -join [Environment]::NewLine) -notmatch "VIVADO RTL PASS") {
        throw "Simulation completed without the expected VIVADO RTL PASS marker. Log: $simLog"
    }
} finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $wdb)) {
    throw "XSim did not create the waveform database: $wdb"
}
Write-Host "Waveform written to $wdb"

if ($OpenGui) {
    & $vivado "-mode" "gui" "-source" $openWaveform
}