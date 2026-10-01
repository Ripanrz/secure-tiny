$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$QuartusDir = Join-Path $ProjectRoot 'quartus'
$QpfPath = Join-Path $QuartusDir 'secure_tiny.qpf'
$QsfPath = Join-Path $QuartusDir 'secure_tiny.qsf'
$SdcPath = Join-Path $QuartusDir 'secure_tiny.sdc'

foreach ($path in @($QpfPath, $QsfPath, $SdcPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Quartus project file is missing: $path"
    }
}

$qpf = Get-Content -LiteralPath $QpfPath -Raw
$qsf = Get-Content -LiteralPath $QsfPath
$sdc = Get-Content -LiteralPath $SdcPath -Raw

if ($qpf -notmatch 'PROJECT_REVISION\s*=\s*"secure_tiny"') {
    throw 'QPF project revision must be secure_tiny.'
}

$requiredAssignments = @(
    'set_global_assignment -name FAMILY "Cyclone V"',
    'set_global_assignment -name DEVICE 5CSEBA6U23I7',
    'set_global_assignment -name TOP_LEVEL_ENTITY secure_tiny_top',
    'set_parameter -name MAX_DATA_BYTES 16',
    'set_location_assignment PIN_V11 -to clk',
    'set_location_assignment PIN_AH17 -to rst_n'
)
foreach ($assignment in $requiredAssignments) {
    if (-not ($qsf -contains $assignment)) {
        throw "Required QSF assignment is missing: $assignment"
    }
}

$virtualPorts = @(
    'start', 'decrypt', '"key[*]"', '"nonce[*]"', '"ad_length[*]"',
    '"data_length[*]"', '"received_tag[*]"', 'ad_valid', 'ad_ready',
    '"ad_data[*]"', 'data_valid', 'data_ready', '"data_in[*]"',
    'out_valid', 'out_ready', '"out_data[*]"', 'tag_valid', 'tag_ready',
    '"tag_out[*]"', 'auth_result_valid', 'accept', 'reject', 'busy', 'done',
    'command_error'
)
foreach ($port in $virtualPorts) {
    $virtualAssignment = "set_instance_assignment -name VIRTUAL_PIN ON -to $port"
    if (-not ($qsf -contains $virtualAssignment)) {
        throw "Top-level transaction port is missing its virtual-pin assignment: $port"
    }
}

$rtlAssignments = @($qsf | Where-Object { $_ -match '^set_global_assignment -name SYSTEMVERILOG_FILE\s+' })
$expectedRtl = @(
    'ascon_permutation.sv',
    'ascon_core.sv',
    'tag_generator.sv',
    'tag_verifier.sv',
    'authentication_guard.sv',
    'aead_controller.sv',
    'secure_tiny_top.sv'
)
if ($rtlAssignments.Count -ne $expectedRtl.Count) {
    throw "QSF must assign exactly $($expectedRtl.Count) RTL files; found $($rtlAssignments.Count)."
}
$actualRtl = @($rtlAssignments | ForEach-Object {
    (($_ -replace '^set_global_assignment -name SYSTEMVERILOG_FILE\s+', '').Trim().Trim('"') | Split-Path -Leaf)
} | Sort-Object -Unique)
if (Compare-Object -ReferenceObject ($expectedRtl | Sort-Object) -DifferenceObject $actualRtl) {
    throw "QSF RTL list does not match the expected top-level source set: $($actualRtl -join ', ')"
}

foreach ($assignment in $rtlAssignments) {
    $relativePath = ($assignment -replace '^set_global_assignment -name SYSTEMVERILOG_FILE\s+', '').Trim().Trim('"')
    $sourcePath = Join-Path $QuartusDir $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "QSF RTL source does not resolve: $relativePath"
    }
    if ([IO.Path]::GetFileName($sourcePath) -notin $expectedRtl) {
        throw "Unexpected RTL source in QSF: $relativePath"
    }
}

if (-not ($qsf -contains 'set_global_assignment -name SDC_FILE secure_tiny.sdc')) {
    throw 'QSF must include secure_tiny.sdc.'
}
if ($sdc -notmatch 'create_clock\s+-name\s+FPGA_CLK1_50\s+-period\s+20\.000\s+\[get_ports\s+\{clk\}\]') {
    throw 'SDC must define the 50 MHz FPGA_CLK1_50 clock on port clk.'
}
if ($sdc -notmatch 'derive_clock_uncertainty') {
    throw 'SDC must derive clock uncertainty.'
}

Write-Output 'PASS: Quartus project files, source paths, Cyclone V device, parameter, clock/reset pins, transaction virtual pins, and 50 MHz clock constraints are consistent.'
