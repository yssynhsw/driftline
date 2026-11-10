# Local Flutter launch with Gemini for development only (direct API key).
# Reads GEMINI_API_KEY from .env.local (gitignored). Never prints the key.
# For the production-like proxy path, use scripts/run_backend.ps1 + run_dev_proxy.ps1.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

& (Join-Path $PSScriptRoot 'sync_dart_defines.ps1')
$defines = Join-Path $root 'dart_defines.json'
if (-not (Test-Path $defines)) {
  Write-Host 'dart_defines.json missing after sync'
  exit 1
}

Write-Host 'Starting Flutter with Gemini dart-defines (secrets not displayed)...'
flutter run --dart-define-from-file=dart_defines.json @args
