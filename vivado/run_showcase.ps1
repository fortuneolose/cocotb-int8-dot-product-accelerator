param(
    [string]$VivadoBin = "C:\Xilinx\2025.1\Vivado\bin",
    [switch]$OpenGui
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildDirectory = Join-Path $PSScriptRoot "xsim_work"
$WaveDatabase = Join-Path $ProjectRoot "artifacts\waves\vivado_dot_product.wdb"
$WaveDatabaseForXsim = $WaveDatabase.Replace("\", "/")
$RunScriptForXsim = (Join-Path $PSScriptRoot "run_xsim.tcl").Replace("\", "/")
$XsimLog = Join-Path $BuildDirectory "xsim.log"

New-Item -ItemType Directory -Force -Path $BuildDirectory | Out-Null
Push-Location $BuildDirectory

try {
    & (Join-Path $VivadoBin "xvlog.bat") --sv `
        (Join-Path $ProjectRoot "rtl\dot_product_int8.sv") `
        (Join-Path $PSScriptRoot "tb_dot_product_showcase.sv")
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin "xelab.bat") --debug typical `
        tb_dot_product_showcase --snapshot dot_product_showcase_sim
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

    & (Join-Path $VivadoBin "xsim.bat") dot_product_showcase_sim `
        -tclbatch $RunScriptForXsim `
        -wdb $WaveDatabaseForXsim
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}

if (!(Test-Path -LiteralPath $WaveDatabase)) {
    throw "XSIM did not produce the waveform database: $WaveDatabase"
}
if (!(Select-String -LiteralPath $XsimLog -Pattern "VIVADO XSIM SHOWCASE PASS" -Quiet)) {
    throw "XSIM completed without the required showcase PASS marker; inspect $XsimLog"
}

Write-Host "Vivado XSIM waveform written to $WaveDatabase"

if ($OpenGui) {
    Start-Process -FilePath (Join-Path $VivadoBin "vivado.bat") `
        -ArgumentList @(
            "-mode", "gui",
            "-source", (Join-Path $PSScriptRoot "open_waveform.tcl")
        )
}
