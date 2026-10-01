POWERSHELL ?= powershell.exe

.PHONY: test test-counter test-ascon-permutation test-ascon-core test-top test-vectors lint-verilator synth-yosys check-quartus-project build-quartus

test: test-counter test-ascon-permutation test-ascon-core test-top test-vectors

test-counter:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_counter.ps1

test-ascon-permutation:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_ascon_permutation.ps1

test-ascon-core:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_ascon_core.ps1

test-top:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_secure_tiny_top.ps1

test-vectors:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/run_python_reference.ps1

lint-verilator:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1

synth-yosys:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/synth_yosys.ps1

check-quartus-project:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/check_quartus_project.ps1

build-quartus:
	$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File scripts/build_quartus.ps1
