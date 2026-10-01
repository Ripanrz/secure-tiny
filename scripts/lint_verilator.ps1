param(
    [ValidateRange(1, 65535)]
    [int]$MaxDataBytes = 16,
    [string]$SuiteRoot = $env:OSS_CAD_SUITE
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($SuiteRoot)) {
    throw 'Set OSS_CAD_SUITE to the OSS CAD Suite installation directory or pass -SuiteRoot.'
}
$SuiteRoot = (Resolve-Path -LiteralPath $SuiteRoot).Path
$Verilator = Join-Path $SuiteRoot 'bin\verilator_bin.exe'
$VerilatorRoot = Join-Path $SuiteRoot 'share\verilator'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogPath = Join-Path $ProjectRoot "sim\verilator_secure_tiny_${MaxDataBytes}.log"
foreach ($path in @($Verilator, $VerilatorRoot)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required Verilator path is missing: $path"
    }
}

$PreviousVerilatorRoot = $env:VERILATOR_ROOT
$PreviousPath = $env:PATH
try {
    $env:VERILATOR_ROOT = $VerilatorRoot
    $env:PATH = (Join-Path $SuiteRoot 'bin') + ';' +
                (Join-Path $SuiteRoot 'lib') + ';' + $PreviousPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $LogPath) -Force | Out-Null

    $rtlSources = @(
        'rtl\ascon_permutation.sv',
        'rtl\ascon_core.sv',
        'rtl\tag_generator.sv',
        'rtl\tag_verifier.sv',
        'rtl\authentication_guard.sv',
        'rtl\aead_controller.sv',
        'rtl\secure_tiny_top.sv'
    )
    & $Verilator --lint-only --top-module secure_tiny_top `
        "-GMAX_DATA_BYTES=$MaxDataBytes" @rtlSources 2>&1 |
        Tee-Object -FilePath $LogPath
    if ($LASTEXITCODE -ne 0) {
        throw "Verilator lint failed with exit code $LASTEXITCODE"
    }
}
finally {
    $env:PATH = $PreviousPath
    if ($null -eq $PreviousVerilatorRoot) {
        Remove-Item Env:VERILATOR_ROOT -ErrorAction SilentlyContinue
    }
    else {
        $env:VERILATOR_ROOT = $PreviousVerilatorRoot
    }
}
