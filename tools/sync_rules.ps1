$ErrorActionPreference = "Stop"

$agentsMd = "AGENTS.md"
$daemonRule = ".agents/rules/daemon.md"

if (Test-Path $agentsMd) {
    if (-not (Test-Path ".agents/rules")) {
        New-Item -ItemType Directory -Path ".agents/rules" -Force | Out-Null
    }
    Copy-Item -Path $agentsMd -Destination $daemonRule -Force
    Write-Host "Synced AGENTS.md -> $daemonRule" -ForegroundColor Green
} else {
    Write-Host "AGENTS.md not found!" -ForegroundColor Red
    exit 1
}
