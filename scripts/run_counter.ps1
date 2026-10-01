& (Join-Path $PSScriptRoot 'run_iverilog.ps1') `
    -Top 'tb_counter' `
    -Sources @('rtl/counter.sv', 'tb/tb_counter.sv') `
    -OutputName 'tb_counter.vvp'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
