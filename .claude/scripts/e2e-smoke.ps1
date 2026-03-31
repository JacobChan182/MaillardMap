$ErrorActionPreference = "Stop"

function Get-BigBackRoot {
  # Script lives at: BigBack/.claude/scripts/*.ps1
  return (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
}

function Resolve-ApiDir([string]$root) {
  $dirs = @(
    (Join-Path $root "backend"),
    (Join-Path $root "backend/api"),
    (Join-Path $root "apps/api"),
    (Join-Path $root "api"),
    (Join-Path $root "server")
  )

  foreach ($d in $dirs) {
    if (Test-Path (Join-Path $d "package.json")) { return $d }
  }
  return $null
}

function Get-NpmScripts([string]$dir) {
  try {
    $pkgPath = Join-Path $dir "package.json"
    if (-not (Test-Path $pkgPath)) { return $null }
    $pkg = Get-Content -Raw -Path $pkgPath | ConvertFrom-Json
    return $pkg.scripts
  } catch {
    return $null
  }
}

function Invoke-IfScriptExists([string]$dir, $scripts, [string]$scriptName) {
  if ($null -ne $scripts -and $scripts.PSObject.Properties.Name -contains $scriptName) {
    Write-Host "Running: npm --prefix `"$dir`" run $scriptName"
    npm --prefix "$dir" run $scriptName
    return $true
  }
  return $false
}

$root = Get-BigBackRoot
$apiDir = Resolve-ApiDir -root $root

if (-not $apiDir) {
  Write-Host "No API directory found (looked for backend/, apps/api/, api/, server/ with package.json)."
  Write-Host "Once you add a backend, this will run a small smoke suite (lint/typecheck/test if present)."
  exit 1
}

Write-Host "API directory: $apiDir"
$scripts = Get-NpmScripts -dir $apiDir

if (-not $scripts) {
  Write-Host "Could not read npm scripts from $apiDir/package.json."
  exit 1
}

$ranAny = $false
$ranAny = (Invoke-IfScriptExists -dir $apiDir -scripts $scripts -scriptName "lint") -or $ranAny
$ranAny = (Invoke-IfScriptExists -dir $apiDir -scripts $scripts -scriptName "typecheck") -or $ranAny
$ranAny = (Invoke-IfScriptExists -dir $apiDir -scripts $scripts -scriptName "test") -or $ranAny

if (-not $ranAny) {
  Write-Host "No lint/typecheck/test scripts found in $apiDir package.json."
  Write-Host "Add scripts (recommended): lint, typecheck, test."
  exit 1
}

Write-Host "Smoke run complete."
