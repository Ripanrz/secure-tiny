# Jalankan seluruh suite unit, integrasi, dan reference-model secara berurutan.
# Hentikan regresi jika satu runner gagal agar error tidak tertutup.
$ErrorActionPreference = 'Stop'
$TestScripts = @(
    'run_counter.ps1',
    'run_ascon_permutation.ps1',
    'run_ascon_core.ps1',
    'run_tag_auth_modules.ps1',
    'run_secure_tiny_top.ps1',
    'run_secure_tiny_kat.ps1',
    'run_python_reference.ps1'
)

foreach ($TestScript in $TestScripts) {
    # Tiap runner membuat log/waveform suite-nya sendiri.
    $TestPath = Join-Path $PSScriptRoot $TestScript
    Write-Output "RUN $TestScript"
    & $TestPath
    if ($LASTEXITCODE -ne 0) {
        throw "$TestScript failed with exit code $LASTEXITCODE"
    }
}

Write-Output 'PASS: all SECURE-TINY test scripts completed'
