param([string]$SuiteRoot = $env:OSS_CAD_SUITE)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SuiteRoot)) {
    throw 'Set OSS_CAD_SUITE to the OSS CAD Suite installation directory or pass -SuiteRoot.'
}
$Python = Join-Path (Resolve-Path -LiteralPath $SuiteRoot).Path 'lib\python3.exe'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $ProjectRoot
try {
    & $Python 'python\check_ascon_acvp_sample.py'
    if ($LASTEXITCODE -ne 0) { throw "ACVP model check failed with exit code $LASTEXITCODE" }
    & $Python 'python\check_ascon_c_kat.py'
    if ($LASTEXITCODE -ne 0) { throw "Ascon-C KAT check failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
