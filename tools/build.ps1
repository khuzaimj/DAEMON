param(
    [switch]$SkipCheck
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

if (-not $SkipCheck) {
    Write-Host "[build] Running tools/check.ps1 ..." -ForegroundColor Cyan
    & powershell -File tools/check.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[build] check.ps1 failed, aborting build." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path "build")) {
    New-Item -ItemType Directory -Path "build" -Force | Out-Null
}

Write-Host "[build] Exporting Windows Desktop release build to build/Daemon.exe ..." -ForegroundColor Cyan
& $godot --headless --path . --export-release "Windows Desktop" build/Daemon.exe
if ($LASTEXITCODE -ne 0) {
    Write-Host "[build] Export failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "[build] Running frozen smoke test on build/Daemon.exe ..." -ForegroundColor Cyan
& build/Daemon.exe --quit-after 180 -- --smoke
if ($LASTEXITCODE -ne 0) {
    Write-Host "[build] Frozen smoke test failed with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "[build] Build successful: build/Daemon.exe" -ForegroundColor Green
exit 0
