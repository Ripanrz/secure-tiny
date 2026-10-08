# Build penuh Quartus Cyclone V: preflight proyek, lalu Analysis & Synthesis,
# Fitter, Assembler, dan Timing Analyzer. Hasil `.sof` dibuat oleh Assembler.
param([string]$QuartusSh = 'quartus_sh')

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
# Pastikan file proyek, device, sumber RTL, pin, dan clock konsisten sebelum compile.
& (Join-Path $PSScriptRoot 'check_quartus_project.ps1')
Push-Location (Join-Path $ProjectRoot 'quartus')
try {
    $quartusCommand = Get-Command $QuartusSh -ErrorAction SilentlyContinue
    if (-not $quartusCommand) {
        throw "Quartus Prime command '$QuartusSh' was not found. The project preflight passed, but no FPGA compile was run."
    }
    & $quartusCommand.Source --flow compile secure_tiny
    if ($LASTEXITCODE -ne 0) {
        throw "Quartus compile failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
