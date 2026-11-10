# Local Flutter launch through the Spring Boot Gemini proxy (no key in the app).
# Requires the backend already running (scripts/run_backend.ps1).

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$envFile = Join-Path $root '.env.local'
if (-not (Test-Path $envFile)) {
  Write-Host 'Missing .env.local'
  exit 1
}

$proxyUrl = $null
$token = $null
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -match '^\s*#' -or $line -eq '') { return }
  if ($line -match '^\s*GEMINI_PROXY_URL\s*=\s*(.+)\s*$') {
    $proxyUrl = $Matches[1].Trim().Trim('"').Trim("'")
  }
  if ($line -match '^\s*DRIFTLINE_APP_TOKEN\s*=\s*(.+)\s*$') {
    $token = $Matches[1].Trim().Trim('"').Trim("'")
  }
  if ($line -match '^\s*GEMINI_APP_TOKEN\s*=\s*(.+)\s*$') {
    $token = $Matches[1].Trim().Trim('"').Trim("'")
  }
}

if (-not $proxyUrl) {
  $lanIp = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
      $_.IPAddress -notlike '127.*' -and
      $_.IPAddress -notlike '169.254.*' -and
      $_.PrefixOrigin -ne 'WellKnown'
    } |
    Select-Object -First 1 -ExpandProperty IPAddress
  if ($lanIp) {
    # Physical device / classmate phone on same Wi‑Fi
    $proxyUrl = "http://${lanIp}:8080/api/v1/gemini/generate"
  } else {
    # Android emulator reaches host machine via 10.0.2.2
    $proxyUrl = 'http://10.0.2.2:8080/api/v1/gemini/generate'
  }
}

Write-Host "Starting Flutter with GEMINI_PROXY_URL (no API key dart-define)..."
$defines = @(
  "--dart-define=GEMINI_PROXY_URL=$proxyUrl"
)
if ($token) {
  $defines += "--dart-define=GEMINI_APP_TOKEN=$token"
}

flutter run @defines @args
