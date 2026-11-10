# Release APK that talks to the deployed Gemini proxy.
# Never injects GEMINI_API_KEY into the APK.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$envFile = Join-Path $root '.env.local'
$proxyUrl = $null
$token = $null

if (Test-Path $envFile) {
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
}

if (-not $proxyUrl -or $proxyUrl -match 'localhost|127\.0\.0\.1|10\.0\.2\.2') {
  Write-Host 'Set a public HTTPS GEMINI_PROXY_URL in .env.local before building a shared APK.'
  Write-Host 'Example: GEMINI_PROXY_URL=https://your-host.example/api/v1/gemini/generate'
  exit 1
}

$defines = @(
  "--dart-define=GEMINI_PROXY_URL=$proxyUrl"
)
if ($token) {
  $defines += "--dart-define=GEMINI_APP_TOKEN=$token"
}

Write-Host 'Building release APK with proxy URL only (API key not included)...'
flutter build apk --release @defines
Write-Host 'APK ready under build/app/outputs/flutter-apk/'
