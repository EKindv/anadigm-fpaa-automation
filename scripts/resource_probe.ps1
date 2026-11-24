# resource_probe.ps1 -- what happens when AD2 runs out of resources?
#
# Fills a chip past its 8-CAM limit and watches, from a second process, which
# dialogs appear and whether the COM call that triggered them blocks.
#
#   powershell -File resource_probe.ps1 -Doc <ad2 with >=1 empty chip> -WorkDir <dir>
#
# ASCII only.

param(
    [Parameter(Mandatory = $true)][string]$Doc,
    [Parameter(Mandatory = $true)][string]$WorkDir
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\ad2_lib.ps1"
AD2-Init (Join-Path $WorkDir 'resource_probe.log')

$app = AD2-Open -Path $Doc
$chip = $app.Workspace.Chips.Item(0)
$null = AD2-ClearCams $chip
AD2-Log ('cleared, cams=' + $chip.Cams.Count)

# keep adding until AD2 refuses; time each Add so a blocking call is obvious
for ($i = 1; $i -le 12; $i++) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $ok = $false
    try {
        $null = $chip.Cams.Add('AnadigmApex\SumIntegrator')
        $ok = $true
    } catch {
        AD2-Log ('  add #' + $i + ' threw: ' + $_.Exception.Message.Split([char]10)[0])
    }
    $sw.Stop()
    AD2-Log ('  add #' + $i + ' ok=' + $ok + '  cams=' + $chip.Cams.Count +
             '  took=' + [math]::Round($sw.Elapsed.TotalSeconds, 2) + ' s')
    if (-not $ok) { break }
}

AD2-Log ('final cams=' + $chip.Cams.Count)
AD2-Log '=== try a run anyway ==='
$r = AD2-Run -App $app -EndMs 1 -TimeoutSec 30
AD2-Log ('run result = ' + $r)
AD2-Close $app
