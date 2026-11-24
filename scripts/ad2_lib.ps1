# ad2_lib.ps1 -- shared helpers for driving AnadigmDesigner2 over COM.
#
# ASCII ONLY. Windows PowerShell reads .ps1 files as the system ANSI code page
# when there is no BOM, so any non-ASCII character here becomes garbage.
# Pass non-ASCII paths as ARGUMENTS, never as literals in this file.
#
# Usage:  . "$PSScriptRoot\ad2_lib.ps1"
#
# Every function that touches COM is wrapped in a retry loop, because the AD2
# automation server throws transient RPC faults while it is busy (opening a
# document, rebuilding the netlist) even when nothing is actually wrong.

$script:AD2Log = $null
# Captured while this file executes, so functions can find the helper scripts
# even when they are called from a script in another directory.
$script:Ad2LibDir = $PSScriptRoot

function AD2-Init {
    param([string]$LogPath)
    if ($LogPath) {
        $script:AD2Log = $LogPath
        if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
    }
}

function AD2-Log {
    param([string]$Message)
    $line = (Get-Date -Format 'HH:mm:ss') + ' ' + $Message
    if ($script:AD2Log) { Add-Content -Path $script:AD2Log -Value $line -Encoding UTF8 }
    Write-Host $line
}

# Run a script block, retrying on COM exceptions. Returns $null if all fail.
function AD2-Retry {
    param([scriptblock]$Block, [string]$What = 'com call', [int]$Tries = 15)
    for ($k = 0; $k -lt $Tries; $k++) {
        try { return (& $Block) } catch { Start-Sleep -Milliseconds 400 }
    }
    AD2-Log ('FAIL ' + $What)
    return $null
}

# Start AD2 and open a document. Returns the Application object.
# IMPORTANT: keep AD2 VISIBLE. A hidden instance runs the simulation fine but
# SaveSimulatorData then writes only the time column.
#
# Opening can BLOCK. If the saved design does not fit the chip, AD2 asks
# "Not enough resources ... Do you want to keep these settings?" and waits for a
# human - measured at 111.89 s for one document. That box is raised while
# Document.Open is still on the stack, so this process cannot dismiss it. A
# helper process is therefore started FIRST and answers it with "No" (revert),
# which keeps the design consistent with what the chip can actually hold.
function AD2-Open {
    param([string]$Path, [switch]$Hidden, [switch]$NoDialogHelper, [int]$HelperSec = 120)
    Get-Process AD20 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 1200

    $helper = $null
    if (-not $NoDialogHelper) {
        $hp = Join-Path $script:Ad2LibDir 'suppress_dialogs.ps1'
        if (Test-Path $hp) {
            $hlog = if ($script:AD2Log) { $script:AD2Log -replace '\.log$', '_dlg.log' } else { Join-Path $env:TEMP 'ad2_dlg.log' }
            $helper = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $hp,
                '-Seconds', "$HelperSec", '-IntervalMs', '200', '-LogFile', $hlog
            ) -PassThru -WindowStyle Hidden
            Start-Sleep -Milliseconds 700
        } else {
            AD2-Log '  no suppress_dialogs.ps1 next to ad2_lib.ps1; dialogs will not be answered'
        }
    }

    $app = New-Object -ComObject 'AnadigmDesigner2.Application'
    $app.Visible = (-not $Hidden)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { $app.Document.Open($Path, 0, $false, $false) }
    catch { AD2-Log ('  open threw: ' + $_.Exception.Message.Split([char]10)[0]) }
    $sw.Stop()
    if ($sw.Elapsed.TotalSeconds -ge 5) {
        AD2-Log ('  open took ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s (a modal dialog was probably waiting)')
    }

    # the object model answers only after the document is really loaded
    for ($k = 0; $k -lt 40; $k++) {
        try { if ($app.Workspace.Chips.Count -ge 1) { break } } catch { }
        Start-Sleep -Milliseconds 400
    }
    if ($helper) { try { Stop-Process -Id $helper.Id -Force -ErrorAction SilentlyContinue } catch { } }
    AD2-Log ('opened ' + $Path + '  chips=' + $app.Workspace.Chips.Count)
    return $app
}

function AD2-Close {
    param($App)
    try { if ($App) { $App.Visible = $false } } catch { }
    Start-Sleep -Milliseconds 400
    Get-Process AD20 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Make sure the workspace has at least $Count chips of type $TypeId (9 = AN231E04).
function AD2-EnsureChips {
    param($App, [int]$Count = 1, [int]$TypeId = 9)
    $chips = $App.Workspace.Chips
    while ($chips.Count -lt $Count) { $null = $chips.Add($TypeId) }
    return $chips
}

# Delete every CAM on a chip. Cams.DeleteAll() is a no-op, so do it backwards.
function AD2-ClearCams {
    param($Chip)
    for ($i = $Chip.Cams.Count - 1; $i -ge 0; $i--) {
        try { $Chip.Cams.Item($i).Delete() } catch { }
    }
    return $Chip.Cams.Count
}

# Find a contact by name. Throws inside the retry wrapper if it does not exist.
function AD2-Ct {
    param($Cam, [string]$Name)
    for ($i = 0; $i -lt $Cam.Contacts.Count; $i++) {
        if ($Cam.Contacts.Item($i).Name -eq $Name) { return $Cam.Contacts.Item($i) }
    }
    throw ('no contact ' + $Name + ' on ' + $Cam.Name)
}

function AD2-FindCam {
    param($Chip, [string]$Name)
    for ($i = 0; $i -lt $Chip.Cams.Count; $i++) {
        $c = $Chip.Cams.Item($i)
        if ($c.Name -eq $Name) { return $c }
    }
    throw ('no CAM named ' + $Name)
}

# Add a CAM and name it. Returns the CAM object (or $null on failure).
#
# Do NOT blanket-retry the Add. "Not enough resources" and "is not a valid CAM"
# are permanent failures, and their message is the single most useful text AD2
# ever produces ("Not enough resources in chip FPAA1 for CAM
# AnadigmApex\SumIntegrator"). Retrying 15 times turned a 0.2 s, perfectly
# readable rejection into a 7 s wait plus a vague "FAIL add".
function AD2-AddCam {
    param($Chip, [string]$Type, [string]$Name)
    $last = ''
    for ($k = 0; $k -lt 15; $k++) {
        try {
            $null = $Chip.Cams.Add($Type)
            $cam = $Chip.Cams.Item($Chip.Cams.Count - 1)
            try { $cam.Name = $Name } catch { }
            AD2-Log ('  add ' + $Name + ' (' + $Type + ')  cams=' + $Chip.Cams.Count)
            return $cam
        } catch {
            $last = $_.Exception.Message.Split([char]10)[0]
            if ($last -match 'Not enough resources|not a valid|Unknown CAM|invalid') {
                AD2-Log ('  ADD REJECTED ' + $Name + ' (' + $Type + '): ' + $last)
                AD2-Log ('  -> chip already holds ' + $Chip.Cams.Count + ' CAMs; a chip takes at most 8')
                return $null
            }
            Start-Sleep -Milliseconds 400
        }
    }
    AD2-Log ('  FAIL add ' + $Name + ' (' + $Type + '): ' + $last)
    return $null
}

# Set an option by name. AD2 fails SILENTLY on a bad choice text, so check the
# return value. Wrong spellings are common ('On' vs 'Input X').
function AD2-SetOpt {
    param($Cam, [string]$OptionName, [string]$Choice)
    for ($i = 0; $i -lt $Cam.Options.Count; $i++) {
        $o = $Cam.Options.Item($i)
        if ($o.Name -ne $OptionName) { continue }
        try {
            $o.SelectedChoice = $Choice
            AD2-Log ('   opt ' + $Cam.Name + '.' + $OptionName + '=' + $Choice)
            return $true
        } catch {
            AD2-Log ('   OPTFAIL ' + $Cam.Name + '.' + $OptionName + '=' + $Choice)
            return $false
        }
    }
    AD2-Log ('   NOOPT ' + $Cam.Name + '.' + $OptionName)
    return $false
}

# Set a numeric parameter, then report Value vs Realized (AD2 quantises).
function AD2-SetPar {
    param($Cam, [string]$ParamName, [double]$Value)
    for ($i = 0; $i -lt $Cam.Parameters.Count; $i++) {
        $p = $Cam.Parameters.Item($i)
        if ($p.Name -ne $ParamName) { continue }
        try {
            $p.Value = $Value
            $real = $p.Realized
            $flag = ''
            if ([math]::Abs([double]$real - $Value) -gt 0.02 * [math]::Abs($Value) + 1e-9) { $flag = '  <-- QUANTISED' }
            AD2-Log ('   par ' + $Cam.Name + '.' + $ParamName + '=' + $Value + ' realized=' + $real + $flag)
            return $true
        } catch {
            AD2-Log ('   PARFAIL ' + $Cam.Name + '.' + $ParamName)
            return $false
        }
    }
    AD2-Log ('   NOPAR ' + $Cam.Name + '.' + $ParamName)
    return $false
}

# Switch an IO cell to Input/Output. Index: 0..5 and 8 are the analog cells,
# 6 is RAM_Transfer_Cell, 7 is Digital_IOCell.
function AD2-IoMode {
    param($Chip, [int]$Index, [string]$Mode)
    try {
        $io = $Chip.IOCells.Item($Index)
        $io.Options.Item(0).SelectedChoice = $Mode
        AD2-Log ('  io' + $Index + ' ' + $io.Name + ' -> ' + $Mode)
        return $io
    } catch {
        AD2-Log ('  IOMODE FAIL io' + $Index + ' ' + $Mode)
        return $null
    }
}

# Wire two contacts on the SAME chip. Returns $true on success.
function AD2-Ln {
    param($CamA, [string]$ContactA, $CamB, [string]$ContactB)
    try {
        (AD2-Ct $CamA $ContactA).ConnectWire((AD2-Ct $CamB $ContactB))
        return $true
    } catch {
        $msg = $_.Exception.Message.Split([char]10)[0]
        AD2-Log ('  LINKFAIL ' + $CamA.Name + '.' + $ContactA + ' -> ' + $CamB.Name + '.' + $ContactB + ' : ' + $msg)
        return $false
    }
}

# Wire across chips through a pair of IO cells. BOTH halves are required;
# wiring only Out_pos -> In_pos gives a floating negative input.
function AD2-LinkChips {
    param($OutCell, $InCell)
    $ok = 0
    try { (AD2-Ct $OutCell 'Out_pos').ConnectWire((AD2-Ct $InCell 'In_pos')); $ok++ } catch { AD2-Log '  XCROSS pos fail' }
    try { (AD2-Ct $OutCell 'Out_neg').ConnectWire((AD2-Ct $InCell 'In_neg')); $ok++ } catch { AD2-Log '  XCROSS neg fail' }
    return ($ok -eq 2)
}

# Delete every generator, then add one and RETURN IT. Never use
# SignalGenerators.Item(Count-1) after more than one Add: the collection order
# is not what you expect and you will overwrite the wrong source.
function AD2-AddGenerator {
    param($App, $Contact, [double]$DcOffset, [double]$Amplitude = 0.0, [double]$FrequencyHz = 100.0, [int]$TypeIndex = 0)
    $g = $null
    try {
        $g = $App.Simulator.SignalGenerators.Add($Contact, $TypeIndex)
    } catch {
        AD2-Log ('  gen add fail: ' + $_.Exception.Message.Split([char]10)[0])
        return $null
    }
    try {
        $g.Amplitude = $Amplitude
        $g.DCOffset = $DcOffset
        $g.CommonModeOffset = 0.0
        $g.Frequency = $FrequencyHz
        AD2-Log ('  gen DC=' + $g.DCOffset + ' A=' + $g.Amplitude + ' F=' + $g.Frequency)
    } catch {
        AD2-Log '  gen param fail'
    }
    return $g
}

# DC source helper: give the IO cell a real DC voltage. The measured mapping is
#   V = (DCOffset - 2)/2  ->  DCOffset = 2 + 2V
function AD2-AddDcSource {
    param($App, $InputCell, [double]$Volts)
    return AD2-AddGenerator -App $App -Contact (AD2-Ct $InputCell 'In_neg') -DcOffset (2.0 + 2.0 * $Volts)
}

# Run the simulator for $EndMs milliseconds and block until it stops.
# Returns 'ok', 'error', 'stalled' or 'timeout'.
#
# 'stalled' is the important one. When AD2 refuses the netlist it does NOT raise
# a COM error: it pops a modal box, IsRunning reports true for ever, and
# CurrentIteration stays at 0. A healthy run has CurrentIteration > 0 within the
# first clock, so one look after StallMs is enough to tell the two apart - and it
# turns a 90 s timeout into a 1.5 s, unambiguous failure.
#
# Recovery: a second Start() in the same session never succeeds. Dismiss the box
# with AD2-DismissDialogs, then restart AD2 (AD2-Close + AD2-Open) and rebuild.
function AD2-Run {
    param($App, [double]$EndMs, [int]$TimeoutSec = 600, [int]$StallMs = 1500)
    $sim = $App.Simulator
    $sim.EndTime = $EndMs
    try { $sim.Start() } catch {
        AD2-Log ('  start threw: ' + $_.Exception.Message.Split([char]10)[0])
        return 'error'
    }
    $sw = [Diagnostics.Stopwatch]::StartNew()

    Start-Sleep -Milliseconds $StallMs
    $it = -1
    try { $it = $sim.CurrentIteration } catch { }
    $running = $true
    try { $running = $sim.IsRunning } catch {
        AD2-Log ('  SIMERR: ' + ($_.Exception.Message -replace "`r`n", ' | '))
        return 'error'
    }
    if ($running -and $it -le 0) {
        AD2-Log '  STALLED: CurrentIteration still 0, netlist rejected (modal dialog on screen)'
        return 'stalled'
    }

    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
        $running = $true
        try { $running = $sim.IsRunning } catch {
            AD2-Log ('  SIMERR: ' + ($_.Exception.Message -replace "`r`n", ' | '))
            return 'error'
        }
        if (-not $running) { break }
        Start-Sleep -Milliseconds 300
    }
    if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) { AD2-Log '  TIMEOUT'; return 'timeout' }
    AD2-Log ('  sim ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s')
    return 'ok'
}

function AD2-Dump {
    param($App, [string]$CsvPath)
    try {
        $App.Simulator.SaveSimulatorData($CsvPath)
        AD2-Log ('  dumped ' + $CsvPath)
        return $true
    } catch {
        AD2-Log ('  DUMPFAIL ' + $_.Exception.Message.Split([char]10)[0])
        return $false
    }
}

function AD2-Save {
    param($App, [string]$Path)
    try { $App.Document.SaveAs($Path, $true); AD2-Log ('  saved ' + $Path); return $true }
    catch { AD2-Log ('  SAVEFAIL ' + $_.Exception.Message.Split([char]10)[0]); return $false }
}

# Read the text of an option choice. A choice is a COM object: [string] gives
# "System.__ComObject", so .Name is the reliable accessor.
function AD2-ChoiceText {
    param($Choice)
    $t = ''
    try { $t = [string]$Choice } catch { }
    if ($t -eq 'System.__ComObject' -or $t -eq '') {
        try { $t = $Choice.Name } catch { $t = '?' }
    }
    return $t
}



# Dismiss any modal Simulation Error dialog currently on screen, ticking the
# "Don't show this message again" box first so it stops re-opening.
function AD2-DismissDialogs {
    param([string]$Helper = '', [int]$WaitSec = 8)
    if (-not $Helper) { $Helper = Join-Path $PSScriptRoot 'suppress_dialogs.ps1' }
    if (-not (Test-Path $Helper)) { AD2-Log '  no suppress_dialogs.ps1 next to ad2_lib.ps1'; return '' }
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Helper -Seconds $WaitSec 2>&1
    $txt = ($out -join ' ').Trim()
    AD2-Log ('  dismiss: ' + $txt)
    return $txt
}
