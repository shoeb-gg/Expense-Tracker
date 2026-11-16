# Builds the APKs for a GitHub release, signed with the permanent release key.
#
#   pwsh tool/release.ps1            (run from the app folder)
#
# Output, in build/release/:
#   Spill-the-Bills-<version>.apk            about 24 MB, for 64-bit phones (almost all phones)
#   Spill-the-Bills-<version>-all-phones.apk about 60 MB, installs on any Android phone
#
# Both files share one version code, so either one can update the other.
# The script stops if an APK isn't signed with the permanent key, because such
# a file couldn't update an existing install.
#
# Before each new release, raise the version in pubspec.yaml (for example
# 1.0.0+1 to 1.0.1+2). The number after + must always go up, or phones
# refuse the update.

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

# SHA-256 of the permanent key's certificate (CN=Spill the Bills, valid to 2054).
$expected = '34f3f80f26d843ac4094f4c88ce7f3f066e3d8a494705d9b3372de4c78714dfa'

if (-not (Test-Path 'android/key.properties')) {
  throw 'android/key.properties is missing, so the APK would be signed with the debug key. Restore it from your backup first.'
}
if (-not $env:JAVA_HOME) {
  # apksigner needs Java; Android Studio ships one.
  $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
}
$buildTools = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Directory |
  Sort-Object { [version]$_.Name } | Select-Object -Last 1
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'

function Confirm-Apk([string]$apk) {
  dart run tool/check_release_icons.dart --apk $apk
  if ($LASTEXITCODE -ne 0) { throw "icon check failed for $apk" }
  $certs = & $apksigner verify --print-certs $apk
  if ($LASTEXITCODE -ne 0) { throw "apksigner could not verify $apk" }
  $digest = ($certs | Select-String 'certificate SHA-256 digest: (\w+)').Matches[0].Groups[1].Value
  if ($digest -ne $expected) {
    throw "$apk is signed with the wrong key ($digest). Check android/key.properties."
  }
}

$version = (Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$name = ($version -split '\+')[0]
$outputs = 'build/app/outputs/flutter-apk'
New-Item -ItemType Directory -Force 'build/release' | Out-Null

flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build (all phones) failed' }
Confirm-Apk "$outputs/app-release.apk"
Copy-Item "$outputs/app-release.apk" "build/release/Spill-the-Bills-$name-all-phones.apk" -Force

# Not --split-per-abi: that adds 2000 to the 64-bit APK's version code, so a
# phone with the 64-bit file would refuse the all-phones file as a downgrade.
# --target-platform keeps one version code for both files.
flutter build apk --release --target-platform android-arm64
if ($LASTEXITCODE -ne 0) { throw 'flutter build (64-bit) failed' }
Confirm-Apk "$outputs/app-release.apk"
Copy-Item "$outputs/app-release.apk" "build/release/Spill-the-Bills-$name.apk" -Force

$aapt = Join-Path $buildTools.FullName 'aapt.exe'
foreach ($f in "Spill-the-Bills-$name.apk", "Spill-the-Bills-$name-all-phones.apk") {
  $badging = & $aapt dump badging "build/release/$f" | Select-Object -First 1
  if ($badging -notmatch "versionCode='(\d+)'") { throw "could not read the version code of $f" }
  "$f has version code $($matches[1])"
}

Get-ChildItem 'build/release' -Filter "Spill-the-Bills-$name*.apk" | ForEach-Object {
  "Ready: build/release/$($_.Name) ($([math]::Round($_.Length / 1MB, 1)) MB)"
}
"Version $version, both signed with the permanent key."
