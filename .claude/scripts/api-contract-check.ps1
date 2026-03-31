$ErrorActionPreference = "Stop"

function Get-BigBackRoot {
  # Script lives at: BigBack/.claude/scripts/*.ps1
  return (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}

function Find-OpenApiSpecFile([string]$root) {
  $candidates = @(
    (Join-Path $root "openapi.yaml"),
    (Join-Path $root "openapi.yml"),
    (Join-Path $root "openapi.json"),
    (Join-Path $root "swagger.yaml"),
    (Join-Path $root "swagger.yml"),
    (Join-Path $root "swagger.json"),
    (Join-Path $root "docs/openapi.yaml"),
    (Join-Path $root "docs/openapi.yml"),
    (Join-Path $root "docs/openapi.json"),
    (Join-Path $root "docs/swagger.yaml"),
    (Join-Path $root "docs/swagger.yml"),
    (Join-Path $root "docs/swagger.json")
  )

  foreach ($p in $candidates) {
    if (Test-Path $p) { return $p }
  }

  # Light recursive search (avoid scanning huge repos)
  $found = Get-ChildItem -Path $root -Recurse -File -Depth 4 -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(openapi|swagger).*\.((ya?ml)|json)$' } |
    Select-Object -First 1

  if ($found) { return $found.FullName }
  return $null
}

$root = Get-BigBackRoot
$spec = Find-OpenApiSpecFile -root $root

if (-not $spec) {
  Write-Host "No OpenAPI spec found."
  Write-Host "Expected something like: openapi.yaml (repo root) or docs/openapi.yaml."
  Write-Host "Tip: once you add one, re-run /api-contract-check."
  exit 1
}

Write-Host "Linting OpenAPI spec: $spec"

# Uses Redocly CLI (installs on demand via npx)
npx @redocly/cli@latest lint "$spec"
