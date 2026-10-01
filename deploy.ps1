# Builds Bunny Hop for Android and installs it on the phone connected by USB.
#
# Usage (from the project folder):
#   powershell -ExecutionPolicy Bypass -File deploy.ps1
# Or double-click deploy.bat.

param(
    [string]$Godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Package = "com.evansmith.bunnyhop"
)

# Not "Stop": Windows PowerShell treats any text a program prints to stderr
# (like adb's "daemon started" notice) as an error. We check results instead.
$ErrorActionPreference = "Continue"
$project = $PSScriptRoot
$apk = Join-Path $project "build\bunnyhop.apk"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$adb = Join-Path $sdk "platform-tools\adb.exe"

## Starts adb's background server as its own detached process. (Started from
## this script directly, it would inherit the script's output and anything
## capturing that output would wait for it forever.)
function Start-AdbServer {
    # Wait for just this command, not the server it leaves running (-Wait would
    # wait for that too, forever).
    $p = Start-Process -FilePath $adb -ArgumentList "start-server" -WindowStyle Hidden -PassThru
    $p.WaitForExit(15000) | Out-Null
}

function Fail($message) {
    Write-Host "`n$message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $Godot)) { Fail "Godot not found at $Godot" }
if (-not (Test-Path $adb)) { Fail "adb not found at $adb" }

# 1. Make sure a phone is connected and has allowed USB debugging.
Write-Host "Checking for phone..." -ForegroundColor Cyan
Start-AdbServer
$devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_.Trim() }
if (-not $devices) { Fail "No phone found. Plug it in with USB and make sure USB debugging is on." }
if ($devices -match "unauthorized") { Fail "Phone is connected but not authorized. Unlock it and tap 'Allow' on the USB debugging prompt, then run this again." }
if (-not ($devices -match "\tdevice$")) { Fail "Phone not ready: $devices" }
Write-Host "  Found: $(($devices -split "`t")[0])"

# 2. Export the debug APK.
Write-Host "Building APK..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force (Split-Path $apk) | Out-Null
# Tells Godot not to scan the build folder as part of the game.
$gdignore = Join-Path $project "build\.gdignore"
if (-not (Test-Path $gdignore)) { New-Item -ItemType File $gdignore | Out-Null }
if (Test-Path $apk) { Remove-Item $apk }
$log = Join-Path $project "build\export.log"
& $Godot --headless --path $project --export-debug "Android" $apk *> $log
if (-not (Test-Path $apk)) {
    Get-Content $log | Where-Object { $_ -match "ERROR" } | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Fail "Build failed. Full log: $log"
}
Write-Host ("  Built {0:N1} MB" -f ((Get-Item $apk).Length / 1MB))

# 3. Install and launch.
Write-Host "Installing on phone..." -ForegroundColor Cyan
# Godot shuts down adb when it exits, so start it again before installing.
Start-AdbServer
$result = cmd /c "`"$adb`" install -r `"$apk`" 2>&1" | Out-String
if ($result -notmatch "Success") { Fail "Install failed:`n$result" }
& $adb shell am force-stop $Package
& $adb shell monkey -p $Package -c android.intent.category.LAUNCHER 1 *> $null

Write-Host "`nDone! Bunny Hop is running on your phone." -ForegroundColor Green
