$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$spec = Join-Path $root "docs\\openapi.yaml"
$outDir = Join-Path $root "backend\\src\\generated"
$outFile = Join-Path $outDir "openapi.ts"

if (-not (Test-Path $spec)) {
  Write-Host "OpenAPI spec not found at: $spec"
  exit 1
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "Generating TypeScript types from OpenAPI..."
npx openapi-typescript@latest "$spec" --output "$outFile"

Write-Host "Generated: $outFile"
