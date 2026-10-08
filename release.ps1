# Builds a signed release app bundle (.aab) to upload to Google Play.
#
# Usage (from the project folder):
#   .\release.ps1                     rebuild the current version
#   .\release.ps1 -Version 1.0.1      set a new version name and bump the version code
#
# It asks for your upload key password each time and never saves it.
# See docs/release.md for creating the upload key.

param(
    [string]$Version, # New version name, e.g. "1.0.1". Google Play needs a higher version code for every upload.
    [string]$Keystore = "$env:USERPROFILE\keys\bunnyhop-upload.keystore",
    [string]$Alias = "upload",
    [string]$Godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
)

# Not "Stop": Windows PowerShell treats any text a program prints to stderr as
# an error. We check results instead.
$ErrorActionPreference = "Continue"
$project = $PSScriptRoot
$presets = Join-Path $project "export_presets.cfg"

function Fail($message) {
    Write-Host "`n$message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Godot)) { Fail "Godot not found at $Godot" }
if (-not (Test-Path $Keystore)) { Fail "No upload key at $Keystore. Create one first: see docs/release.md." }
$jdk = Get-ChildItem "C:\Program Files\Microsoft" -Directory -Filter "jdk-17*" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $jdk) { Fail "JDK 17 not found in C:\Program Files\Microsoft" }

# 1. Version. Both export presets share it.
$text = [IO.File]::ReadAllText($presets)
$code = [int][regex]::Match($text, 'version/code=(\d+)').Groups[1].Value
$name = [regex]::Match($text, 'version/name="([^"]*)"').Groups[1].Value
if ($Version) {
    $code++
    $name = $Version
    $text = [regex]::Replace($text, 'version/code=\d+', "version/code=$code")
    $text = [regex]::Replace($text, 'version/name="[^"]*"', "version/name=`"$name`"")
    [IO.File]::WriteAllText($presets, $text)
    Write-Host "Version set to $name (code $code). Commit export_presets.cfg after uploading." -ForegroundColor Cyan
}
Write-Host "Building Bunny Hop $name (version code $code)" -ForegroundColor Cyan

# 2. Build, with the password passed to Godot only for this run.
$secure = Read-Host "Upload key password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
New-Item -ItemType Directory -Force (Join-Path $project "build") | Out-Null
$out = Join-Path $project "build\bunnyhop-$name-$code.aab"
$log = Join-Path $project "build\release.log"
if (Test-Path $out) { Remove-Item $out }
$godotArgs = @("--headless", "--path", $project)
if (-not (Test-Path (Join-Path $project "android\build"))) { $godotArgs += "--install-android-build-template" }
$godotArgs += @("--export-release", "Android Release", $out)
# Gradle normally leaves a background helper (its "daemon") running for hours
# after a build. Godot's console program waits for every process it started,
# so this script would sit here until that helper quit. Turn the helper off.
$oldGradleOpts = $env:GRADLE_OPTS
try {
    $env:GRADLE_OPTS = "$oldGradleOpts -Dorg.gradle.daemon=false".Trim()
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $Keystore
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $Alias
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    Write-Host "Exporting (the Gradle build takes a minute or two)..."
    & $Godot @godotArgs *> $log
} finally {
    $env:GRADLE_OPTS = $oldGradleOpts
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
if (-not (Test-Path $out)) {
    Get-Content $log | Where-Object { $_ -match "ERROR|FAILURE|wrong password|Keystore" } | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Fail "Build failed. Full log: $log"
}

# 3. Check it's signed with the upload key.
$verify = & (Join-Path $jdk.FullName "bin\jarsigner.exe") -verify $out 2>&1 | Out-String
if ($verify -notmatch "jar verified") { Fail "The bundle isn't properly signed:`n$verify" }
$cert = & (Join-Path $jdk.FullName "bin\keytool.exe") -printcert -jarfile $out 2>&1 | Select-String "Owner:" | Select-Object -First 1

Write-Host ("`nDone! {0} ({1:N1} MB)" -f $out, ((Get-Item $out).Length / 1MB)) -ForegroundColor Green
Write-Host "Signed by: $($cert.Line.Trim())"
Write-Host "Upload it in Play Console: Testing > Internal testing > Create new release."
