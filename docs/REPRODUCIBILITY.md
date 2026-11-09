# Keterulangan Hasil

This repository keeps the **sumber kebenaran** in RTL, testbenches, scripts, model referensis, vectors, and Quartus project files. Generated simulation and FPGA-build artifacts are intentionally not tracked. The recorded 2026 Hasil are historical bukti; this repository snapshot does not claim a fresh toolchain rerun.

## Environment

Recorded baseline:

- Icarus Verilog 14.0 development build
- Python 3.11.6
- Verilator 5.053
- Yosys 0.69+156
- Quartus Prime Lite 25.1std.0 Build 1129
- Cyclone V `5CSEBA6U23I7`
- Quartus baseline parameter: `MAX_DATA_BYTES=16`

Exact tool versions may change the artefak hasil pembangkitan. Always record the tool version with a new benchmark.

## RTL regression — historical recipe

From the repository root:

```powershell
$env:OSS_CAD_SUITE = 'C:\tools\oss-cad-suite'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1
```

The pelaksana uji executes the current test suites:

1. Counter learning/unit test
2. Ascon permutation
3. Ascon core KAT
4. Tag/authentication modules
5. Uji terarah tingkat atas tests
6. Top-level KAT sweep
7. Model referensi Python checks

Generated VCD/log files are written to `sim/` and are intentionally ignored by Git.

## Lint and sintesis generik — historical recipe

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1 -MaxDataBytes 16
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/synth_yosys.ps1 -MaxDataBytes 16
```

Yosys cell counts are sintesis generik statistics, not Cyclone V ALM counts.

## Quartus — historical build recipe

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/check_quartus_project.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/build_quartus.ps1 -QuartusSh 'C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe'
```

A historical Quartus build generated reports and `.sof` under `quartus/output_files/`. These artifacts are not tracked.

## Hardware boundary

The recorded Quartus build is **not** a DE10-Nano fisik test. The current project has no HPS/Avalon transaction path, no physical throughput measurement, no power measurement, and no board-level I/O timing sign-off.
