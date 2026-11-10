# Build a classmate APK that talks to THIS PC's Gemini proxy on Wi‑Fi.
# Embeds GEMINI_PROXY_URL + optional GEMINI_APP_TOKEN only — never GEMINI_API_KEY.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$envFile = Join-Path $root '.env.local'
$token = $null
$port = '8080'

if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\s*#' -or $line -eq '') { return }
    if ($line -match '^\s*DRIFTLINE_APP_TOKEN\s*=\s*(.+)\s*$') {
      $token = $Matches[1].Trim().Trim('"').Trim("'")
    }
    if ($line -match '^\s*GEMINI_APP_TOKEN\s*=\s*(.+)\s*$') {
      $token = $Matches[1].Trim().Trim('"').Trim("'")
    }
    if ($line -match '^\s*PORT\s*=\s*(.+)\s*$') {
      $port = $Matches[1].Trim().Trim('"').Trim("'")
    }
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
  Write-Host 'No LAN IPv4 found. Connect to Wi‑Fi first.'
  exit 1
}

$proxyUrl = "http://${lanIp}:${port}/api/v1/gemini/generate"
$defines = @(
  "--dart-define=GEMINI_PROXY_URL=$proxyUrl"
)
if ($token) {
  $defines += "--dart-define=GEMINI_APP_TOKEN=$token"
}

Write-Host "Building classmate APK → proxy $proxyUrl"
Write-Host '(GEMINI_API_KEY is NOT included in the APK)'
flutter build apk --release @defines
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
Write-Host ''
Write-Host 'Done.'
Write-Host "APK: $apk"
Write-Host "Keep this PC on the same Wi‑Fi and run: .\scripts\run_backend.ps1"
Write-Host 'Share only the APK with classmates — never share GEMINI_API_KEY.'
