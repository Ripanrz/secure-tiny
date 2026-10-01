& (Join-Path $PSScriptRoot 'run_iverilog.ps1') `
    -Top 'tb_ascon_permutation' `
    -Sources @('rtl/ascon_permutation.sv', 'tb/tb_ascon_permutation.sv') `
    -OutputName 'tb_ascon_permutation.vvp'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
