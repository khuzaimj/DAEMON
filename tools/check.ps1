param(
    [switch]$Full
)

$ErrorActionPreference = "Stop"

function Resolve-Godot {
    if ($env:GODOT -and (Test-Path $env:GODOT)) {
        return $env:GODOT
    }
    $userGodot = [System.Environment]::GetEnvironmentVariable("GODOT", "User")
    if ($userGodot -and (Test-Path $userGodot)) {
        $env:GODOT = $userGodot
        return $userGodot
    }
    $cmd = Get-Command "Godot*_win64_console.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        $env:GODOT = $cmd.Source
        return $cmd.Source
    }
    throw "GODOT executable not found. Please set `$env:GODOT to the console binary."
}

$godot = Resolve-Godot

function Run-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    Write-Host "[check] $Name ..." -ForegroundColor Cyan
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $Action 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    foreach ($line in $output) {
        $lineStr = $line.ToString()
        Write-Host $lineStr
        if ($lineStr -match "^\s*(SCRIPT\s+)?ERROR:") {
            Write-Host "[check] FAILED: $Name (Error detected in output)" -ForegroundColor Red
            exit 1
        }
    }

    if ($exitCode -ne 0) {
        Write-Host "[check] FAILED: $Name (Exit code $exitCode)" -ForegroundColor Red
        exit $exitCode
    }
    Write-Host "[check] PASSED: $Name" -ForegroundColor Green
}

# 1. Import
Run-Step "Godot Import" { & $godot --headless --path . --import }

# 2. Load all resources
Run-Step "Load All Resources" { & $godot --headless --path . --script res://tools/load_all.gd }

# 3. Validate data
Run-Step "Validate Data" { & $godot --headless --path . --script res://tools/validate_data.gd }

# 4. GUT Tests
Run-Step "GUT Unit & Scenario Tests" { & $godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit }

if ($Full) {
    # 5. Graphics smoke
    Run-Step "Graphics Smoke Test" { & $godot --path . --quit-after 180 -- --smoke }

    # 6. Build
    Run-Step "Build Windows Executable" { & powershell -File tools/build.ps1 -SkipCheck }

    # 7. Frozen smoke
    Run-Step "Frozen Build Smoke Test" { & build/Daemon.exe --quit-after 180 -- --smoke }
}

Write-Host "`n[check] ALL CHECKS GREEN." -ForegroundColor Green
exit 0
