# Start the Driftline Gemini proxy (Spring Boot).
# Loads GEMINI_API_KEY / DRIFTLINE_APP_TOKEN from .env.local — never prints secrets.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location (Join-Path $root 'backend')

$envFile = Join-Path $root '.env.local'
if (-not (Test-Path $envFile)) {
  Write-Host 'Missing .env.local at repo root.'
  Write-Host 'Copy .env.local.example and set GEMINI_API_KEY + DRIFTLINE_APP_TOKEN.'
  exit 1
}

function Read-EnvValue([string]$name) {
  $value = $null
  Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\s*#' -or $line -eq '') { return }
    if ($line -match ("^\s*" + [regex]::Escape($name) + "\s*=\s*(.+)\s*$")) {
      $value = $Matches[1].Trim().Trim('"').Trim("'")
    }
  }
  return $value
}

$key = Read-EnvValue 'GEMINI_API_KEY'
$token = Read-EnvValue 'DRIFTLINE_APP_TOKEN'
$model = Read-EnvValue 'GEMINI_MODEL'
$port = Read-EnvValue 'PORT'

if (-not $key -or $key.Length -lt 20) {
  Write-Host 'GEMINI_API_KEY missing or invalid in .env.local'
  exit 1
}

$env:GEMINI_API_KEY = $key
if ($token) { $env:DRIFTLINE_APP_TOKEN = $token }
if ($model) { $env:GEMINI_MODEL = $model }
if ($port) { $env:PORT = $port } else { $env:PORT = '8080' }

Write-Host "Starting Gemini proxy on port $($env:PORT) (secrets not displayed)..."
.\mvnw.cmd spring-boot:run
