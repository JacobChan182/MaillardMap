$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$backendDir = Join-Path $root "backend"

if (-not (Test-Path (Join-Path $backendDir "package.json"))) {
  Write-Host "No backend/package.json found at: $backendDir"
  exit 1
}

Write-Host "Starting backend dev server..."
Push-Location $backendDir
try {
  npm run dev
} finally {
  Pop-Location
}
