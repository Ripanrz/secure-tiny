# Uji transaksi terarah: valid/ready, tag/data salah, reset, kapasitas, dan stall.
& (Join-Path $PSScriptRoot 'run_iverilog.ps1') `
    -Top 'tb_secure_tiny_top' `
    -Sources @(
        'rtl/ascon_permutation.sv', 'rtl/ascon_core.sv',
        'rtl/tag_generator.sv', 'rtl/tag_verifier.sv',
        'rtl/authentication_guard.sv', 'rtl/aead_controller.sv',
        'rtl/secure_tiny_top.sv', 'tb/tb_secure_tiny_top.sv'
    ) `
    -OutputName 'tb_secure_tiny_top.vvp'
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
