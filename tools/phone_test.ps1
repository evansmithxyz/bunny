# Helpers for testing Bunny Hop on the phone safely over USB (adb).
# Usage: . .\tools\phone_test.ps1  then Start-PhoneTest, Send-PhoneInput, Stop-PhoneTest.
# - Start-PhoneTest / Stop-PhoneTest post and remove a "please don't touch" notification.
# - Every input goes through Send-PhoneInput, which first checks Bunny Hop is the
#   app in front and stops the test if anything else is (so taps never land in
#   another app).

$script:adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$script:pkg = "com.evansmith.bunnyhop"
$script:tag = "bunnyhop_claude_test"

function Start-PhoneTest([string]$what = "a quick test", [int]$minutes = 1) {
    # One string for the phone's shell, with single quotes around the texts.
    # Windows PowerShell mangles inner double quotes, and apostrophes would end
    # the single-quoted text, so the message avoids both.
    $text = "Please do not touch the phone for about $minutes min while I run $what. You will get a message here when it is done."
    & $script:adb shell "cmd notification post -S bigtext -t 'Claude is testing Bunny Hop' $($script:tag) '$text'" | Out-Null
}

function Stop-PhoneTest {
    # Replace the notice with a short "done" message (Android shell can't always cancel).
    & $script:adb shell "cmd notification post -t 'Test finished' $($script:tag) 'Thanks. The phone is all yours again.'" | Out-Null
}

function Test-GameInFront {
    $top = & $script:adb shell dumpsys activity activities 2>&1 | Select-String "topResumedActivity" | Select-Object -First 1
    return [bool]($top -and $top.Line -match [regex]::Escape($script:pkg))
}

## Runs an adb input command only if Bunny Hop is in front; otherwise throws.
function Send-PhoneInput([string[]]$inputArgs) {
    if (-not (Test-GameInFront)) {
        Stop-PhoneTest
        throw "STOPPED: Bunny Hop isn't the app in front, so no input was sent."
    }
    & $script:adb shell input @inputArgs
}
