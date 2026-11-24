# test_stall.ps1 -- the two cases that matter, in about 10 seconds.
#
#   VALID   : a document that runs  -> AD2-Run returns 'ok' quickly
#   BROKEN  : an integrator with nothing connected -> AD2-Run returns 'stalled'
#             in ~1.5 s instead of hanging for the whole timeout
#
#   powershell -File test_stall.ps1 -Doc <known-good.ad2> -WorkDir <dir>
#
# ASCII only.

param(
    [Parameter(Mandatory = $true)][string]$Doc,
    [Parameter(Mandatory = $true)][string]$WorkDir
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\ad2_lib.ps1"
$log = Join-Path $WorkDir 'test_stall.log'
AD2-Init $log

# ---------------------------------------------------------------- valid case
AD2-Log '=== VALID ==='
$app = AD2-Open -Path $Doc
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = AD2-Run -App $app -EndMs 1 -TimeoutSec 60
$sw.Stop()
AD2-Log ('  result=' + $r + '  in ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s')
if ($r -eq 'ok') { $null = AD2-Dump -App $app -CsvPath (Join-Path $WorkDir 'valid.csv') }
AD2-Close $app

# --------------------------------------------------------------- broken case
AD2-Log '=== BROKEN (unconnected integrator) ==='
$app = AD2-Open -Path $Doc
$chips = $app.Workspace.Chips
$chip = $chips.Item(0)
for ($c = 0; $c -lt $chips.Count; $c++) { $null = AD2-ClearCams $chips.Item($c) }
for ($gi = $app.Simulator.SignalGenerators.Count - 1; $gi -ge 0; $gi--) {
    try { $app.Simulator.SignalGenerators.Item($gi).Delete() } catch { }
}
$null = AD2-AddCam $chip 'AnadigmApex\SumIntegrator' 'a'
$sim = $app.Simulator
try { $sim.Probes.DeleteAll() } catch { }
$sim.Probes.Add((AD2-Ct (AD2-FindCam $chip 'a') 'Out')) | Out-Null

$sw = [Diagnostics.Stopwatch]::StartNew()
$r = AD2-Run -App $app -EndMs 1 -TimeoutSec 120
$sw.Stop()
AD2-Log ('  result=' + $r + '  in ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s')

if ($r -eq 'stalled') {
    AD2-Log '=== dismiss the box, then check the object model still answers ==='
    $null = AD2-DismissDialogs
    try { AD2-Log ('  chip still readable: cams=' + $chip.Cams.Count) }
    catch { AD2-Log ('  object model dead: ' + $_.Exception.Message) }
}
AD2-Close $app

# ------------------------------------------------- does a restart recover?
AD2-Log '=== AFTER RESTART (fresh AD20 process, same document) ==='
$app = AD2-Open -Path $Doc
$sw = [Diagnostics.Stopwatch]::StartNew()
$r = AD2-Run -App $app -EndMs 1 -TimeoutSec 60
$sw.Stop()
AD2-Log ('  result=' + $r + '  in ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s')
if ($r -eq 'ok') { $null = AD2-Dump -App $app -CsvPath (Join-Path $WorkDir 'after_restart.csv') }
AD2-Close $app

AD2-Log '=== DONE ==='

