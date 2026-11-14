# Downloads the official precompiled 64-bit sqlite3.dll from sqlite.org into
# app/test/native/ (git-ignored). The tests load it through
# package:sqlite3/open.dart (see test/support/sqlite.dart). Without it the
# tests fall back to Windows' own winsqlite3.dll.
#
# Usage (from the app folder):
#   powershell -ExecutionPolicy Bypass -File tool/get_sqlite_dll.ps1
#   powershell -ExecutionPolicy Bypass -File tool/get_sqlite_dll.ps1 -Url https://www.sqlite.org/2025/sqlite-dll-win-x64-3500400.zip

param([string]$Url)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$appDir = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $appDir 'test\native'
New-Item -ItemType Directory -Force -Path $dest | Out-Null

if (-not $Url) {
  $page = Invoke-WebRequest -UseBasicParsing -Uri 'https://www.sqlite.org/download.html'
  $match = [regex]::Match($page.Content, '(\d{4}/sqlite-dll-win-x64-\d+\.zip)')
  if (-not $match.Success) {
    throw 'Could not find the 64-bit DLL link on https://www.sqlite.org/download.html'
  }
  $Url = 'https://www.sqlite.org/' + $match.Groups[1].Value
}

# Download and unpack in a fresh, empty temp folder.
$work = Join-Path ([IO.Path]::GetTempPath()) ('sqlite-dll-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $work | Out-Null
try {
  $zip = Join-Path $work 'sqlite.zip'
  Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $zip
  $unpacked = Join-Path $work 'unpacked'
  Expand-Archive -Path $zip -DestinationPath $unpacked
  Copy-Item -Path (Join-Path $unpacked 'sqlite3.dll') -Destination (Join-Path $dest 'sqlite3.dll') -Force
} finally {
  Remove-Item -Recurse -Force $work
}

Write-Host "sqlite3.dll saved to $dest (from $Url)"
