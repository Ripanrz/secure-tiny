param([string]$QuartusSh = 'quartus_sh')

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
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
