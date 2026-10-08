# Shortcut untuk menjalankan runner PowerShell dari terminal yang mendukung make.
POWERSHELL ?= powershell.exe

.PHONY: test test-counter test-ascon-permutation test-ascon-core test-tag-auth test-top test-top-kat test-vectors lint-verilator synth-yosys check-quartus-project build-quartus

# Target agregat: seluruh suite unit, integrasi, dan model Python.
test:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1

test-counter:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_counter.ps1

test-ascon-permutation:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_ascon_permutation.ps1

test-ascon-core:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_ascon_core.ps1

test-tag-auth:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_tag_auth_modules.ps1

test-top:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_secure_tiny_top.ps1

test-top-kat:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_secure_tiny_kat.ps1

test-vectors:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_python_reference.ps1

# Lint dan sintesis generik hanya memberi pemeriksaan tambahan, bukan KAT.
lint-verilator:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1

synth-yosys:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/synth_yosys.ps1

check-quartus-project:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/check_quartus_project.ps1

# Build perangkat Cyclone V penuh; butuh Quartus dan dukungan device terpasang.
build-quartus:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/build_quartus.ps1
