param(
    [Parameter(Mandatory = $true)]
    [string]$Top,

    [Parameter(Mandatory = $true)]
    [string[]]$Sources,

    [Parameter(Mandatory = $true)]
    [string]$OutputName,

    [string]$SuiteRoot = $env:OSS_CAD_SUITE
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SuiteRoot)) {
    throw 'Set OSS_CAD_SUITE to the OSS CAD Suite installation directory or pass -SuiteRoot.'
}

$SuiteRoot = (Resolve-Path -LiteralPath $SuiteRoot).Path
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$OutputDir = Join-Path $ProjectRoot 'sim'
$OutputFile = Join-Path $OutputDir $OutputName
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Icarus in this Windows suite needs a drive-letter root for VPI path lookup.
$UsedDrives = (Get-PSDrive -PSProvider FileSystem).Name
$DriveLetter = @('Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') |
    Where-Object { $_ -notin $UsedDrives } |
    Select-Object -First 1
if (-not $DriveLetter) {
    throw 'No free drive letter from Q: through Z: is available for OSS CAD Suite.'
}

$Drive = "${DriveLetter}:"
& subst.exe $Drive $SuiteRoot
if ($LASTEXITCODE -ne 0) {
    throw "Could not map OSS CAD Suite to $Drive"
}

$PreviousYosyshqRoot = $env:YOSYSHQ_ROOT
$PreviousPath = $env:PATH
try {
    $env:YOSYSHQ_ROOT = "$Drive\"
    $env:PATH = "$Drive\bin;$Drive\lib;$PreviousPath"

    $ResolvedSources = @($Sources | ForEach-Object { Join-Path $ProjectRoot $_ })
    & "$Drive\bin\iverilog.exe" -B "$Drive\lib\ivl" -g2012 -s $Top -o $OutputFile @ResolvedSources
    if ($LASTEXITCODE -ne 0) {
        throw "iverilog failed with exit code $LASTEXITCODE"
    }

    Push-Location $ProjectRoot
    try {
        & "$Drive\bin\vvp.exe" $OutputFile
        if ($LASTEXITCODE -ne 0) {
            throw "vvp failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    $env:PATH = $PreviousPath
    if ($null -eq $PreviousYosyshqRoot) {
        Remove-Item Env:YOSYSHQ_ROOT -ErrorAction SilentlyContinue
    }
    else {
        $env:YOSYSHQ_ROOT = $PreviousYosyshqRoot
    }
    & subst.exe $Drive /d
}
