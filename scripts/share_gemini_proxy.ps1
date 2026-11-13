# Classroom helper:
# 1) Prints the LAN proxy URL for classmates
# 2) Optionally starts the backend
# 3) Optionally builds the LAN APK (no Gemini API key inside)

param(
  [switch]$StartBackend,
  [switch]$BuildApk
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$envFile = Join-Path $root '.env.local'
if (-not (Test-Path $envFile)) {
  Write-Host 'Missing .env.local — copy .env.local.example and set GEMINI_API_KEY + DRIFTLINE_APP_TOKEN.'
  exit 1
}

$port = '8080'
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -match '^\s*PORT\s*=\s*(.+)\s*$') {
    $port = $Matches[1].Trim().Trim('"').Trim("'")
  }
}

$lanIp = Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -notlike '127.*' -and
    $_.IPAddress -notlike '169.254.*' -and
    $_.PrefixOrigin -ne 'WellKnown'
  } |
  Sort-Object -Property PrefixLength |
  Select-Object -First 1 -ExpandProperty IPAddress

if (-not $lanIp) {
  Write-Host 'No LAN IPv4 found.'
  exit 1
}

$proxyUrl = "http://${lanIp}:${port}/api/v1/gemini/generate"
$healthUrl = "http://${lanIp}:${port}/api/v1/gemini/health"

Write-Host '=== Driftline Gemini proxy (classroom) ==='
Write-Host "LAN IP:     $lanIp"
Write-Host "Proxy URL:  $proxyUrl"
Write-Host "Health URL: $healthUrl"
Write-Host ''
Write-Host 'Camarades: installent l’APK proxy. Toi: tu gardes GEMINI_API_KEY dans .env.local.'
Write-Host ''

# Keep .env.local proxy URL useful for physical devices on Wi‑Fi.
$lines = Get-Content $envFile
$updated = $false
$newLines = foreach ($line in $lines) {
  if ($line -match '^\s*GEMINI_PROXY_URL\s*=') {
    $updated = $true
    "GEMINI_PROXY_URL=$proxyUrl"
  } else {
    $line
  }
}
if (-not $updated) {
  $newLines += "GEMINI_PROXY_URL=$proxyUrl"
}
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($envFile, $newLines, $utf8NoBom)
Write-Host "Updated .env.local GEMINI_PROXY_URL → $proxyUrl"

if ($BuildApk) {
  & (Join-Path $PSScriptRoot 'build_apk_lan.ps1')
}

if ($StartBackend) {
  Write-Host 'Starting backend (Ctrl+C to stop)...'
  & (Join-Path $PSScriptRoot 'run_backend.ps1')
} else {
  Write-Host ''
  Write-Host 'Next:'
  Write-Host '  1 - .\scripts\run_backend.ps1'
  Write-Host '  2 - .\scripts\build_apk_lan.ps1'
  Write-Host '  3 - Share build/app/outputs/flutter-apk/app-release.apk'
}
