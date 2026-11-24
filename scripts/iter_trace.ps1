# iter_trace.ps1 -- does CurrentIteration advance DURING a long simulation?
#
# This decides whether a 1.5 s stall check is safe. If the counter only updates
# when the run finishes, then a legitimate 20 ms simulation (about 60 s of wall
# clock) would look identical to a rejected netlist and a stall detector would
# kill it.
#
#   powershell -File iter_trace.ps1 -Doc <valid.ad2> -EndMs 8 -WorkDir <dir>
#
# ASCII only.

param(
    [Parameter(Mandatory = $true)][string]$Doc,
    [double]$EndMs = 8,
    [Parameter(Mandatory = $true)][string]$WorkDir,
    [int]$MaxSec = 180
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\ad2_lib.ps1"
AD2-Init (Join-Path $WorkDir 'iter_trace.log')

$app = AD2-Open -Path $Doc
$sim = $app.Simulator
AD2-Log ('probes=' + $sim.Probes.Count + '  cams=' + $app.Workspace.Chips.Item(0).Cams.Count)
$sim.EndTime = $EndMs
AD2-Log ('EndTime=' + $EndMs + ' ms')

try { $sim.Start() } catch { AD2-Log ('Start threw: ' + $_.Exception.Message.Split([char]10)[0]) }
$sw = [Diagnostics.Stopwatch]::StartNew()
$lastLog = -10
while ($sw.Elapsed.TotalSeconds -lt $MaxSec) {
    $it = -1; $run = $null
    try { $it = $sim.CurrentIteration } catch { }
    try { $run = $sim.IsRunning } catch { }
    $t = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    if ($t - $lastLog -ge 1.0 -or $null -eq $run -or -not $run) {
        AD2-Log ('  t=' + $t + 's  iteration=' + $it + '  running=' + $run)
        $lastLog = $t
    }
    if ($null -ne $run -and -not $run) { break }
    Start-Sleep -Milliseconds 250
}
AD2-Log ('finished in ' + [math]::Round($sw.Elapsed.TotalSeconds, 1) + ' s')
try { $sim.SaveSimulatorData((Join-Path $WorkDir 'iter_trace.csv')); AD2-Log 'dumped' } catch { AD2-Log 'dump failed' }
AD2-Close $app
