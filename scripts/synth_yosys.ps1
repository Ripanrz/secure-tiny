# Sintesis Yosys generik untuk memeriksa hierarchy, proses, dan struktur RTL.
# Jumlah sel generik yang dilaporkan bukan metrik ALM Cyclone V.
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
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogPath = Join-Path $ProjectRoot "sim\yosys_secure_tiny_${MaxDataBytes}.log"
New-Item -ItemType Directory -Path (Split-Path -Parent $LogPath) -Force | Out-Null

$UsedDrives = (Get-PSDrive -PSProvider FileSystem).Name
$DriveLetter = @('Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') |
    Where-Object { $_ -notin $UsedDrives } |
    Select-Object -First 1
if (-not $DriveLetter) { throw 'No free drive letter from Q: through Z: is available.' }
$Drive = "${DriveLetter}:"
& subst.exe $Drive $SuiteRoot
if ($LASTEXITCODE -ne 0) { throw "Could not map OSS CAD Suite to $Drive" }

$PreviousYosyshqRoot = $env:YOSYSHQ_ROOT
$PreviousPath = $env:PATH
try {
    $env:YOSYSHQ_ROOT = "$Drive\"
    $env:PATH = "$Drive\bin;$Drive\lib;$PreviousPath"
    # Urutan: baca SV -> atur parameter -> cek hierarchy/proses -> sintesis -> stat.
    $yosysScript = "read_verilog -sv rtl/ascon_permutation.sv rtl/ascon_core.sv rtl/tag_generator.sv rtl/tag_verifier.sv rtl/authentication_guard.sv rtl/aead_controller.sv rtl/secure_tiny_top.sv; chparam -set MAX_DATA_BYTES $MaxDataBytes secure_tiny_top; hierarchy -check -top secure_tiny_top; proc; check; synth -top secure_tiny_top -flatten; stat"
    & "$Drive\bin\yosys.exe" -Q -l $LogPath -p $yosysScript
    if ($LASTEXITCODE -ne 0) { throw "Yosys failed with exit code $LASTEXITCODE" }
}
finally {
    $env:PATH = $PreviousPath
    if ($null -eq $PreviousYosyshqRoot) {
        Remove-Item Env:YOSYSHQ_ROOT -ErrorAction SilentlyContinue
    }
    else {
        $env:YOSYSHQ_ROOT = $PreviousYosyshqRoot
    }
    & subst.exe $Drive /d
}
