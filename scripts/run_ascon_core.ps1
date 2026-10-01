& (Join-Path $PSScriptRoot 'run_iverilog.ps1') `
    -Top 'tb_ascon_core' `
    -Sources @('rtl/ascon_permutation.sv', 'rtl/ascon_core.sv', 'tb/tb_ascon_core.sv') `
    -OutputName 'tb_ascon_core.vvp'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
