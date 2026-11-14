# phone.ps1 - drive the Android phone over ADB and inspect its UI.
# Usage: pwsh -File phone.ps1 <command> [args]
#   cap <name>        screenshot + UI dump -> reference/screens/<name>.png/.xml, then list elements
#   look              UI dump only (no screenshot), list elements
#   els               re-list elements from the last dump
#   tap <x> <y>       tap at coordinates
#   tapt <text>       tap the element whose text/desc matches <text> (from last dump)
#   long <x> <y>      long press at coordinates
#   type <text>       type text into the focused field (avoid & % ' " characters)
#   back | home | enter
#   key <KEYCODE_X>   send a key event
#   swipe <x1> <y1> <x2> <y2> [ms]
#   down | up         scroll the screen content down / up
#   focus             print the focused window
#   awake on|off      keep screen on while on USB (on) or restore default (off)

param(
    [Parameter(Position = 0)][string]$Cmd,
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Rest
)

$adb  = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$ref  = "C:\Users\Shoeb\Desktop\Expense Tracker\reference\screens"
$last = Join-Path $ref "_last.xml"
$pkg  = "com.freeman.moneymanager"
New-Item -ItemType Directory -Force $ref | Out-Null

function Get-Focus {
    $f = (& $adb shell dumpsys window 2>$null | Select-String 'mCurrentFocus' | Select-Object -First 1)
    if ($f) { $f.ToString().Trim() -replace '^mCurrentFocus=Window\{[^ ]+ u0 ', '' -replace '\}$', '' } else { "unknown" }
}

function Dump-Xml([string]$dest) {
    for ($try = 0; $try -lt 3; $try++) {
        & $adb shell rm -f /sdcard/et.xml 2>&1 | Out-Null
        & $adb shell uiautomator dump /sdcard/et.xml 2>&1 | Out-Null
        & $adb pull /sdcard/et.xml $dest 2>&1 | Out-Null
        if ((Test-Path $dest) -and (Get-Item $dest).Length -gt 200) { return $true }
        Start-Sleep -Milliseconds 700
    }
    return $false
}

function Show-Elements([string]$file) {
    if (-not (Test-Path $file)) { "NO DUMP AVAILABLE"; return }
    try { [xml]$x = Get-Content $file -Raw } catch { "DUMP PARSE FAILED"; return }
    $count = 0
    foreach ($n in $x.SelectNodes("//node")) {
        $t = $n.text; $d = $n.'content-desc'
        $click = $n.clickable -eq 'true'; $scroll = $n.scrollable -eq 'true'
        if (-not $click -and -not $scroll -and [string]::IsNullOrEmpty($t) -and [string]::IsNullOrEmpty($d)) { continue }
        $cx = 0; $cy = 0
        if ($n.bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
            $cx = [int](([int]$matches[1] + [int]$matches[3]) / 2)
            $cy = [int](([int]$matches[2] + [int]$matches[4]) / 2)
        }
        $cls = ($n.class -split '\.')[-1]
        $rid = ($n.'resource-id' -split '/')[-1]
        $flags = @()
        if ($click) { $flags += 'CLICK' }
        if ($n.'long-clickable' -eq 'true') { $flags += 'LONG' }
        if ($scroll) { $flags += 'SCROLL' }
        if ($n.checked -eq 'true') { $flags += 'CHECKED' }
        if ($n.selected -eq 'true') { $flags += 'SELECTED' }
        if ($n.enabled -eq 'false') { $flags += 'DISABLED' }
        $line = "($cx,$cy) $cls"
        if ($t) { $line += " text=`"$t`"" }
        if ($d) { $line += " desc=`"$d`"" }
        if ($rid) { $line += " id=$rid" }
        if ($flags.Count) { $line += " [" + ($flags -join ',') + "]" }
        $line
        $count++
    }
    if ($count -eq 0) { "(no labelled or clickable elements found)" }
}

function Find-Center([string]$needle) {
    if (-not (Test-Path $last)) { return $null }
    [xml]$x = Get-Content $last -Raw
    $nodes = @($x.SelectNodes("//node"))
    $exact = $nodes | Where-Object { $_.text -ieq $needle -or $_.'content-desc' -ieq $needle }
    $cands = if ($exact) { $exact } else { $nodes | Where-Object { ($_.text -and $_.text -ilike "*$needle*") -or ($_.'content-desc' -and $_.'content-desc' -ilike "*$needle*") } }
    if (-not $cands) { return $null }
    $pick = ($cands | Where-Object { $_.clickable -eq 'true' } | Select-Object -First 1)
    if (-not $pick) { $pick = $cands | Select-Object -First 1 }
    if ($pick.bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
        return @([int](([int]$matches[1] + [int]$matches[3]) / 2), [int](([int]$matches[2] + [int]$matches[4]) / 2), $pick.text, $pick.'content-desc')
    }
    return $null
}

function Warn-IfAd {
    $f = Get-Focus
    if ($f -notmatch $pkg -and $f -notmatch 'launcher|systemui|PopupWindow|InputMethod') { "!! FOCUS LEFT APP: $f  (likely an ad or external screen - press back)" }
    elseif ($f -match 'AdActivity|ads\.') { "!! AD ON SCREEN: $f  (find a close/X button or press back)" }
}

switch ($Cmd) {
    'cap' {
        $name = if ($Rest) { $Rest[0] } else { "shot_" + (Get-Date -Format 'HHmmss') }
        Start-Sleep -Milliseconds 400
        & $adb shell screencap -p /sdcard/et.png 2>&1 | Out-Null
        & $adb pull /sdcard/et.png (Join-Path $ref "$name.png") 2>&1 | Out-Null
        & $adb shell rm -f /sdcard/et.png 2>&1 | Out-Null
        $ok = Dump-Xml (Join-Path $ref "$name.xml")
        if ($ok) { Copy-Item (Join-Path $ref "$name.xml") $last -Force }
        "SAVED $name.png" + $(if ($ok) { " + $name.xml" } else { " (xml dump failed)" })
        "FOCUS: $(Get-Focus)"
        Warn-IfAd
        Show-Elements $last
    }
    'look' {
        Start-Sleep -Milliseconds 300
        $ok = Dump-Xml $last
        "FOCUS: $(Get-Focus)"
        Warn-IfAd
        if ($ok) { Show-Elements $last } else { "DUMP FAILED" }
    }
    'els'   { Show-Elements $last }
    'focus' { "FOCUS: $(Get-Focus)"; Warn-IfAd }
    'tap'   { & $adb shell input tap $Rest[0] $Rest[1]; "tapped ($($Rest[0]),$($Rest[1]))" }
    'long'  { & $adb shell input swipe $Rest[0] $Rest[1] $Rest[0] $Rest[1] 900; "long-pressed ($($Rest[0]),$($Rest[1]))" }
    'tapt'  {
        $needle = ($Rest -join ' ')
        $r = Find-Center $needle
        if ($r) { & $adb shell input tap $r[0] $r[1]; "tapped '$needle' at ($($r[0]),$($r[1])) text=`"$($r[2])`" desc=`"$($r[3])`"" }
        else { "NOT FOUND: '$needle' (run 'look' to refresh the dump)" }
    }
    'type'  {
        $txt = ($Rest -join ' ') -replace ' ', '%s'
        & $adb shell input text "$txt"; "typed: $($Rest -join ' ')"
    }
    'back'  { & $adb shell input keyevent KEYCODE_BACK; "back" }
    'home'  { & $adb shell input keyevent KEYCODE_HOME; "home" }
    'enter' { & $adb shell input keyevent KEYCODE_ENTER; "enter" }
    'key'   { & $adb shell input keyevent $Rest[0]; "key $($Rest[0])" }
    'swipe' {
        $ms = if ($Rest.Count -ge 5) { $Rest[4] } else { 400 }
        & $adb shell input swipe $Rest[0] $Rest[1] $Rest[2] $Rest[3] $ms; "swiped"
    }
    'down'  { & $adb shell input swipe 540 1700 540 700 500; "scrolled down" }
    'up'    { & $adb shell input swipe 540 700 540 1700 500; "scrolled up" }
    'awake' {
        if ($Rest[0] -eq 'on') { & $adb shell svc power stayon usb; "stay-awake on (usb)" }
        else { & $adb shell svc power stayon false; "stay-awake off" }
    }
    default { "unknown command '$Cmd'. See header of phone.ps1 for usage." }
}
