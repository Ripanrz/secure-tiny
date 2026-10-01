& (Join-Path $PSScriptRoot 'run_iverilog.ps1') `
    -Top 'tb_tag_auth_modules' `
    -Sources @('rtl/tag_generator.sv', 'rtl/tag_verifier.sv', 'rtl/authentication_guard.sv', 'tb/tb_tag_auth_modules.sv') `
    -OutputName 'tb_tag_auth_modules.vvp'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
