# probe.ps1 -- dump everything AnadigmDesigner2 knows about a CAM and an IO cell.
#
# Two modes:
#   1. catalog: create one of every CAM type on a scratch chip and print all of
#      its OPTIONS (with their allowed choice texts) and PARAMETERS (with the
#      value AD2 picked by default).
#   2. dump: open an existing .ad2 and print the same for the CAMs it contains,
#      plus the IO cell modes and the signal generators.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File probe.ps1 -Catalog
#   powershell -NoProfile -ExecutionPolicy Bypass -File probe.ps1 -Doc "C:\...\x.ad2"
#
# ASCII only: pass document paths as arguments, never inline them.

param(
    [string]$Doc = '',
    [switch]$Catalog,
    [string]$LogFile = 'probe.log',
    [string]$Template = ''
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\ad2_lib.ps1"
AD2-Init $LogFile

function Dump-Cam {
    param($Cam, [string]$Indent = '')
    AD2-Log ($Indent + 'CAM ' + $Cam.Name + '  type=' + $Cam.Type)
    $contacts = @()
    for ($i = 0; $i -lt $Cam.Contacts.Count; $i++) { $contacts += $Cam.Contacts.Item($i).Name }
    AD2-Log ($Indent + '  contacts: ' + ($contacts -join ', '))
    for ($i = 0; $i -lt $Cam.Options.Count; $i++) {
        $o = $Cam.Options.Item($i)
        $choices = @()
        for ($j = 0; $j -lt $o.Choices.Count; $j++) { $choices += (AD2-ChoiceText $o.Choices.Item($j)) }
        AD2-Log ($Indent + '  OPTION ' + $o.Name + ' = [' + $o.SelectedChoice + ']  choices: ' + ($choices -join ' | '))
    }
    for ($i = 0; $i -lt $Cam.Parameters.Count; $i++) {
        $p = $Cam.Parameters.Item($i)
        AD2-Log ($Indent + '  PARAM  ' + $p.Name + ' = ' + $p.Value + '  realized=' + $p.Realized)
    }
    try {
        $clk = $Cam.Clocks.Item(0).ChipClock
        AD2-Log ($Indent + '  clock: ' + $clk.Name + '  ' + $clk.Frequency + ' kHz')
    } catch { }
}

function Dump-Doc {
    param($App)
    $chips = $App.Workspace.Chips
    for ($c = 0; $c -lt $chips.Count; $c++) {
        $chip = $chips.Item($c)
        AD2-Log ('=== chip ' + ($c + 1) + '  cams=' + $chip.Cams.Count)
        for ($i = 0; $i -lt $chip.Cams.Count; $i++) { Dump-Cam $chip.Cams.Item($i) '  ' }
        AD2-Log ('  IO cells: ' + $chip.IOCells.Count)
        for ($i = 0; $i -lt $chip.IOCells.Count; $i++) {
            $io = $chip.IOCells.Item($i)
            $mode = '?'
            try { $mode = $io.Options.Item(0).SelectedChoice } catch { }
            AD2-Log ('    io' + $i + ' ' + $io.Name + ' mode=' + $mode)
        }
    }
    $gens = $App.Simulator.SignalGenerators
    AD2-Log ('=== generators: ' + $gens.Count)
    for ($i = 0; $i -lt $gens.Count; $i++) {
        $g = $gens.Item($i)
        try {
            AD2-Log ('  gen' + $i + '  Type=' + $g.Type + ' WaveForm=' + $g.WaveForm +
                     ' DC=' + $g.DCOffset + ' A=' + $g.Amplitude + ' F=' + $g.Frequency +
                     ' Duty=' + $g.DutyCycle + ' PWidth=' + $g.PulseWidth)
        } catch { }
    }
}

if ($Catalog) {
    if (-not $Template) { Write-Output 'catalog mode needs -Template <a small .ad2 with at least one chip>'; exit 1 }
    $app = AD2-Open -Path $Template
    $chip = $app.Workspace.Chips.Item(0)
    AD2-Log ('cleared ' + (AD2-ClearCams $chip) + ' cams')
    $types = @(
        'AnadigmApex\SumIntegrator', 'AnadigmApex\Integrator', 'AnadigmApex\Hold',
        'AnadigmApex\GainHold', 'AnadigmApex\GainPolarity', 'AnadigmApex\Multiplier',
        'AnadigmApex\RectifierFilter', 'AnadigmApex\RectifierHalf', 'AnadigmApex\SumFilter',
        'AnadigmApex\TransferFunction', 'AnadigmApex\Comparator', 'AnadigmApex\SampleHold'
    )
    foreach ($t in $types) {
        $cam = $null
        try { $null = $chip.Cams.Add($t); $cam = $chip.Cams.Item($chip.Cams.Count - 1) } catch { }
        if (-not $cam) { AD2-Log ('=== ' + $t + '  -- NOT AVAILABLE'); continue }
        AD2-Log ('=== ' + $t)
        Dump-Cam $cam '  '
        try { $cam.Delete() } catch { }
    }
    AD2-Close $app
} elseif ($Doc) {
    $app = AD2-Open -Path $Doc
    Dump-Doc $app
    AD2-Close $app
} else {
    Write-Output 'usage: probe.ps1 -Catalog -Template <ad2>   |   probe.ps1 -Doc <ad2>'
}


