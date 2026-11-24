# run_dump.ps1 -- open an existing .ad2, run the simulator, dump the waveform.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File run_dump.ps1 `
#       -Doc "C:\path\circuit.ad2" -Csv "C:\path\wave.csv" -EndMs 20 `
#       -Probes Out:x,Out:y,Out:z,Out:u
#
# -Probes is a comma separated list of CAMNAME:CONTACT. At most FOUR probes are
# allowed by AD2; the fifth throws.
#
# ASCII only: pass every path as an argument.

param(
    [Parameter(Mandatory = $true)][string]$Doc,
    [Parameter(Mandatory = $true)][string]$Csv,
    [double]$EndMs = 20,
    [string]$Probes = '',
    [string]$LogFile = 'run_dump.log',
    [switch]$Hidden,
    [double]$WarmupMs = 0.5,
    [int]$TimeoutSec = 900
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\ad2_lib.ps1"
AD2-Init $LogFile

$app = AD2-Open -Path $Doc -Hidden:$Hidden

# probes
$sim = $app.Simulator
# do not touch the probe list unless the caller asked: deleting and re-adding
# probes on a document that already has saved probes makes the dump contain
# only the time column.
if ($Probes) {
    try { $sim.Probes.DeleteAll() } catch { }
    foreach ($spec in $Probes.Split(',')) {
        $parts = $spec.Split(':')
        $camName = $parts[0].Trim()
        $contact = if ($parts.Count -gt 1) { $parts[1].Trim() } else { 'Out' }
        try {
            $chip = $app.Workspace.Chips.Item(0)
            $cam = AD2-FindCam $chip $camName
            $sim.Probes.Add((AD2-Ct $cam $contact)) | Out-Null
            AD2-Log ('  probe ' + $camName + '.' + $contact)
        } catch {
            AD2-Log ('  probe fail ' + $spec)
        }
    }
}
AD2-Log ('probes=' + $sim.Probes.Count)

# A document opened from disk binds the simulator channels only on the SECOND
# run: the first Start compiles the netlist and the probes are dropped. Always do
# a short warm-up run before the one you intend to dump.
if ($WarmupMs -gt 0) {
    $null = AD2-Run -App $app -EndMs $WarmupMs -TimeoutSec 60
    AD2-Log 'warm-up done'
}

$result = AD2-Run -App $app -EndMs $EndMs -TimeoutSec $TimeoutSec
AD2-Log ('run result: ' + $result)

if ($result -eq 'ok') {
    $null = AD2-Dump -App $app -CsvPath $Csv
}
AD2-Close $app




