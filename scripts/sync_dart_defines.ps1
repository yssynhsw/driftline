# Builds gitignored dart_defines JSON from .env.local for Flutter --dart-define-from-file.
# Never prints secret values.
#
# Default: local direct Gemini key (dev on your machine).
# -ProxyOnly: classmate/proxy mode — GEMINI_PROXY_URL + token only (no API key in the app).

param(
  [switch]$ProxyOnly
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env.local'
$outFile = if ($ProxyOnly) {
  Join-Path $root 'dart_defines.proxy.json'
} else {
  Join-Path $root 'dart_defines.json'
}

if (-not (Test-Path $envFile)) {
  Write-Host 'Missing .env.local'
  exit 1
}

$map = @{}
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -match '^\s*#' -or $line -eq '') { return }
  if ($line -match '^\s*([A-Z0-9_]+)\s*=\s*(.+)\s*$') {
    $name = $Matches[1]
    $value = $Matches[2].Trim().Trim('"').Trim("'")
    if ($name -in @(
      'GEMINI_API_KEY',
      'GEMINI_PROXY_URL',
      'GEMINI_APP_TOKEN',
      'DRIFTLINE_APP_TOKEN',
      'OPENTRIPMAP_API_KEY',
      'OPENROUTESERVICE_API_KEY'
    )) {
      if ($value) { $map[$name] = $value }
    }
  }
}

# Flutter expects GEMINI_APP_TOKEN; accept DRIFTLINE_APP_TOKEN as alias.
if (-not $map.ContainsKey('GEMINI_APP_TOKEN') -and $map.ContainsKey('DRIFTLINE_APP_TOKEN')) {
  $map['GEMINI_APP_TOKEN'] = $map['DRIFTLINE_APP_TOKEN']
}

$payload = [ordered]@{}

if ($ProxyOnly) {
  if (-not $map.ContainsKey('GEMINI_PROXY_URL')) {
    Write-Host 'Need GEMINI_PROXY_URL in .env.local for -ProxyOnly'
    exit 1
  }
  $payload['GEMINI_PROXY_URL'] = $map['GEMINI_PROXY_URL']
  if ($map.ContainsKey('GEMINI_APP_TOKEN')) {
    $payload['GEMINI_APP_TOKEN'] = $map['GEMINI_APP_TOKEN']
  }
  if ($map.ContainsKey('OPENTRIPMAP_API_KEY')) {
    $payload['OPENTRIPMAP_API_KEY'] = $map['OPENTRIPMAP_API_KEY']
  }
  if ($map.ContainsKey('OPENROUTESERVICE_API_KEY')) {
    $payload['OPENROUTESERVICE_API_KEY'] = $map['OPENROUTESERVICE_API_KEY']
  }
} else {
  if (-not $map.ContainsKey('GEMINI_API_KEY') -and -not $map.ContainsKey('GEMINI_PROXY_URL')) {
    Write-Host 'Need GEMINI_API_KEY or GEMINI_PROXY_URL in .env.local'
    exit 1
  }
  # Prefer direct key for local phone testing.
  if ($map.ContainsKey('GEMINI_API_KEY')) {
    $payload['GEMINI_API_KEY'] = $map['GEMINI_API_KEY']
  }
  if ($map.ContainsKey('GEMINI_APP_TOKEN')) {
    $payload['GEMINI_APP_TOKEN'] = $map['GEMINI_APP_TOKEN']
  }
  if ($map.ContainsKey('OPENTRIPMAP_API_KEY')) {
    $payload['OPENTRIPMAP_API_KEY'] = $map['OPENTRIPMAP_API_KEY']
  }
  if ($map.ContainsKey('OPENROUTESERVICE_API_KEY')) {
    $payload['OPENROUTESERVICE_API_KEY'] = $map['OPENROUTESERVICE_API_KEY']
  }
}

# UTF-8 without BOM — a BOM breaks Flutter --dart-define-from-file parsing.
$json = ($payload | ConvertTo-Json -Compress)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($outFile, $json, $utf8NoBom)
Write-Host "Wrote $(Split-Path $outFile -Leaf) with keys: $($payload.Keys -join ', ')"
