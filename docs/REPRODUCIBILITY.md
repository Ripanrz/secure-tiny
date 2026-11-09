# Reproducibility

This repository keeps the **source of truth** in RTL, testbenches, scripts, reference models, vectors, and Quartus project files. Generated simulation and FPGA-build artifacts are intentionally not tracked.

## Environment

Recorded baseline:

- Icarus Verilog 14.0 development build
- Python 3.11.6
- Verilator 5.053
- Yosys 0.69+156
- Quartus Prime Lite 25.1std.0 Build 1129
- Cyclone V `5CSEBA6U23I7`
- Quartus baseline parameter: `MAX_DATA_BYTES=16`

Exact tool versions may change the generated artifacts. Always record the tool version with a new benchmark.

## RTL regression

From the repository root:

```powershell
$env:OSS_CAD_SUITE = 'C:\tools\oss-cad-suite'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1
```

The runner executes the current product test suites:

1. Ascon permutation
2. Ascon core KAT
3. Tag/authentication modules
4. Top-level directed tests
5. Top-level KAT sweep
6. Python reference checks

Generated VCD/log files are written to `sim/` and are intentionally ignored by Git.

## Lint and generic synthesis

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1 -MaxDataBytes 16
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/synth_yosys.ps1 -MaxDataBytes 16
```

Yosys cell counts are generic synthesis statistics, not Cyclone V ALM counts.

## Quartus

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/check_quartus_project.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/build_quartus.ps1 -QuartusSh 'C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe'
```

The build generates reports and `.sof` under `quartus/output_files/`. These are build artifacts and are not tracked.

## Hardware boundary

A successful Quartus build is **not** a physical DE10-Nano test. The current project has no HPS/Avalon transaction path, no physical throughput measurement, no power measurement, and no board-level I/O timing sign-off.
