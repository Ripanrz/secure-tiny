# Ekstrak metrik dari laporan Quartus yang ada. Script ini menjalankan map/fit/STA
# sebelum ekstraksi; angka harus selalu dipasangkan dengan report dan konfigurasi.
param(
    [string]$Project = 'secure_tiny',
    [string]$QuartusBin = ''
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$QuartusProjectDir = Join-Path $ProjectRoot 'quartus'
$OutputDir = Join-Path $QuartusProjectDir 'output_files'
$ProjectRevision = 'secure_tiny'
$ClockName = 'FPGA_CLK1_50'

& (Join-Path $PSScriptRoot 'check_quartus_project.ps1')

function Resolve-QuartusTool([string]$Name) {
    # Cari executable dari folder yang diberikan atau dari PATH.
    if (-not [string]::IsNullOrWhiteSpace($QuartusBin)) {
        $candidate = Join-Path $QuartusBin "$Name.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
        throw "Quartus tool not found: $candidate"
    }

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

$Tools = @{}
foreach ($name in @('quartus_map', 'quartus_fit', 'quartus_sta')) {
    $Tools[$name] = Resolve-QuartusTool $name
}
$Missing = @($Tools.Keys | Where-Object { -not $Tools[$_] })
if ($Missing.Count -gt 0) {
    Write-Output "BLOCKED: Quartus Prime tools unavailable: $($Missing -join ', ')."
    Write-Output 'Preflight passed, but no map/fit/timing run or FPGA metric extraction was performed.'
    Write-Output 'Install Quartus Prime Lite with Cyclone V support or pass -QuartusBin <Quartus bin64 directory>.'
    exit 2
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Push-Location $QuartusProjectDir
try {
    # Jalankan tiga tahap agar laporan resource dan timing berasal dari compile ini.
    foreach ($stage in @('quartus_map', 'quartus_fit', 'quartus_sta')) {
        $logPath = Join-Path $OutputDir "$ProjectRevision.$($stage.Replace('quartus_', '')).log"
        Write-Output "RUN $stage $Project"
        & $Tools[$stage] $Project --read_settings_files=on --write_settings_files=off 2>&1 |
            Tee-Object -FilePath $logPath
        if ($LASTEXITCODE -ne 0) {
            throw "$stage failed with exit code $LASTEXITCODE. See $logPath"
        }
    }
}
finally {
    Pop-Location
}

$ReportFiles = @(Get-ChildItem -LiteralPath $QuartusProjectDir -Recurse -File -Filter '*.rpt' |
    Where-Object { $_.FullName -notmatch '[\\/]db[\\/]' })
if ($ReportFiles.Count -eq 0) {
    throw "Quartus commands completed, but no .rpt files were found under $QuartusProjectDir."
}

function Find-ReportMetric([string]$LabelPattern, [string]$ValuePattern, [string]$MetricName) {
    # Ambil metrik dari laporan Quartus terbaru dan simpan baris asal agar angka
    # dapat ditelusuri. Jika format laporan berubah, tandai sebagai belum terbaca.
    foreach ($report in ($ReportFiles | Sort-Object LastWriteTime -Descending)) {
        foreach ($line in [IO.File]::ReadLines($report.FullName)) {
            if ($line -match $LabelPattern) {
                $match = [regex]::Match($line, $ValuePattern)
                if ($match.Success) {
                    return [PSCustomObject]@{
                        Metric = $MetricName
                        Value = $match.Groups['value'].Value.Replace(',', '')
                        Status = 'EXTRACTED'
                        Report = $report.FullName.Substring($ProjectRoot.Length + 1)
                        Evidence = $line.Trim()
                    }
                }
                return [PSCustomObject]@{
                    Metric = $MetricName; Value = 'TBD - belum diekstrak'; Status = 'UNPARSED'
                    Report = $report.FullName.Substring($ProjectRoot.Length + 1); Evidence = $line.Trim()
                }
            }
        }
    }
    return [PSCustomObject]@{
        Metric = $MetricName; Value = 'TBD - belum ditemukan'; Status = 'NOT_FOUND'
        Report = ''; Evidence = ''
    }
}

$Metrics = @(
    Find-ReportMetric '(?i)Logic utilization\s*\(in ALMs\)' '(?i)Logic utilization\s*\(in ALMs\).*?(?<value>[\d,]+)\s*/' 'ALM used'
    Find-ReportMetric '(?i)Total registers' '(?i)Total registers.*?(?<value>[\d,]+)(?:\s*/|\s*;|\s*$)' 'Registers used'
)

# Fmax dicari terpisah karena nilainya harus cocok dengan nama clock pada SDC.
$FmaxMetric = $null
foreach ($report in ($ReportFiles | Sort-Object LastWriteTime -Descending)) {
    foreach ($line in [IO.File]::ReadLines($report.FullName)) {
        if ($line -match [regex]::Escape($ClockName) -and $line -match '(?i)Fmax|MHz') {
            $match = [regex]::Match($line, '(?<value>[\d,.]+)\s*MHz', 'IgnoreCase')
            if ($match.Success) {
                $FmaxMetric = [PSCustomObject]@{
                    Metric = "Fmax ($ClockName)"
                    Value = $match.Groups['value'].Value.Replace(',', '') + ' MHz'
                    Status = 'EXTRACTED'
                    Report = $report.FullName.Substring($ProjectRoot.Length + 1)
                    Evidence = $line.Trim()
                }
                break
            }
        }
    }
    if ($FmaxMetric) { break }
}
if (-not $FmaxMetric) {
    $FmaxMetric = [PSCustomObject]@{
        Metric = "Fmax ($ClockName)"; Value = 'TBD - belum ditemukan'; Status = 'NOT_FOUND'
        Report = ''; Evidence = ''
    }
}
$Metrics += $FmaxMetric

$Metrics += [PSCustomObject]@{
    Metric = 'Target device'; Value = 'Cyclone V 5CSEBA6U23I7'; Status = 'PROJECT_SETTING'
    Report = 'quartus/secure_tiny.qsf'; Evidence = 'Target from project assignment; not a measured metric.'
}
$Metrics += [PSCustomObject]@{
    Metric = 'MAX_DATA_BYTES'; Value = '16'; Status = 'PROJECT_SETTING'
    Report = 'quartus/secure_tiny.qsf'; Evidence = 'Compile parameter from project assignment.'
}

$MetricsPath = Join-Path $QuartusProjectDir 'secure_tiny_metrics.csv'
$Metrics | Export-Csv -LiteralPath $MetricsPath -NoTypeInformation -Encoding UTF8
Write-Output "METRICS CSV: $MetricsPath"
$Metrics | Format-Table Metric,Value,Status,Report -AutoSize
if (@($Metrics | Where-Object { $_.Status -eq 'EXTRACTED' }).Count -lt 3) {
    Write-Output 'WARNING: one or more target metrics were not extracted; keep those fields marked TBD.'
}
