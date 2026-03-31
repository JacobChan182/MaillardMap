$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$compose = Join-Path $root "docker-compose.yml"

if (-not (Test-Path $compose)) {
  Write-Host "docker-compose.yml not found at: $compose"
  exit 1
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Host "Docker is not installed / not on PATH."
  exit 1
}

Write-Host "Stopping Postgres..."
docker compose -f "$compose" down
