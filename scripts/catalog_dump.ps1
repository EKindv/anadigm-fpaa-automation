# catalog_dump.ps1 -- enumerate EVERY CAM type of a library and dump its runtime
# surface (contacts, option choices, parameters) as Markdown.
#
# The .cam files in the AD2 installation are binary, so the type names come from
# the file names and all the detail comes from the COM object model - which is
# what actually matters, and which differs from the documentation anyway
# (option texts are exact strings you must pass to AD2-SetOpt).
#
#   powershell -File catalog_dump.ps1 -LibDir "C:\Program Files (x86)\Anadigm\AnadigmDesigner2\Libraries\AnadigmApex" `
#            -Template <ad2 with 1 chip> -Namespace AnadigmApex -OutFile catalog.md
#
# ASCII only.

param(
    [string]$LibDir = 'C:\Program Files (x86)\Anadigm\AnadigmDesigner2\Libraries\AnadigmApex',
    [Parameter(Mandatory = $true)][string]$Template,
    [string]$Namespace = 'AnadigmApex',
    [Parameter(Mandatory = $true)][string]$OutFile,
    [string]$Only = ''
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\ad2_lib.ps1"
AD2-Init ($OutFile -replace '\.md$', '.log')

# ---------------------------------------------------------------- type list
if ($Only) {
    $types = $Only.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
} else {
    $types = Get-ChildItem $LibDir -Filter *.cam | Sort-Object Name | ForEach-Object { $_.BaseName }
}
AD2-Log ('types to probe: ' + $types.Count)
if ($types.Count -eq 0) { throw 'no CAM types found' }

$md = New-Object System.Collections.Generic.List[string]
$md.Add('# Runtime probe - ' + $Namespace + ' - ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
$md.Add('')

$app = AD2-Open -Path $Template
$chips = $app.Workspace.Chips
$chip = $chips.Item(0)
$sim = $app.Simulator

$memberDumped = $false
$okCount = 0; $failCount = 0

foreach ($t in $types) {
    $full = $Namespace + '\' + $t
    $null = AD2-ClearCams $chip
    $cam = $null
    try {
        $null = $chip.Cams.Add($full)
        $cam = $chip.Cams.Item($chip.Cams.Count - 1)
    } catch {
        $msg = $_.Exception.Message.Split([char]10)[0]
        AD2-Log ('  ' + $t + ' -> ADD FAILED: ' + $msg)
        $md.Add('## ' + $full)
        $md.Add('')
        $md.Add('**Add failed:** ' + $msg)
        $md.Add('')
        $failCount++
        continue
    }
    $okCount++
    $slots = $chip.Cams.Count
    AD2-Log ('  ' + $t + '  ok  slots=' + $slots)

    # one-time introspection of the COM surface
    if (-not $memberDumped) {
        $memberDumped = $true
        try {
            $md.Add('<!-- member dump: contact -->')
            $c0 = $cam.Contacts.Item(0)
            $c0 | Get-Member -MemberType Property | ForEach-Object { $md.Add('<!--   contact.' + $_.Name + ' -->') }
            $md.Add('<!-- member dump: option -->')
            $cam.Options.Item(0) | Get-Member -MemberType Property | ForEach-Object { $md.Add('<!--   option.' + $_.Name + ' -->') }
            $md.Add('<!-- member dump: parameter -->')
            $cam.Parameters.Item(0) | Get-Member -MemberType Property | ForEach-Object { $md.Add('<!--   param.' + $_.Name + ' -->') }
            $md.Add('')
        } catch { }
    }

    $md.Add('## ' + $full)
    $md.Add('')
    $md.Add('_occupies ' + $slots + ' CAM slot(s)_')

    # contacts
    $ins = @(); $outs = @(); $other = @()
    for ($i = 0; $i -lt $cam.Contacts.Count; $i++) {
        $c = $cam.Contacts.Item($i)
        $nm = $c.Name
        $dir = $null
        foreach ($prop in @('IsInput', 'IsOutput', 'Direction', 'Kind', 'Type')) {
            try {
                $v = $c.$prop
                if ($null -ne $v) { $dir = "$prop=$v"; break }
            } catch { }
        }
        if ($dir -match 'IsInput=True') { $ins += $nm }
        elseif ($dir -match 'IsOutput=True') { $outs += $nm }
        elseif ($nm -match '^(In|in|X|Y|Z|S|Ref|Pol)') { $ins += $nm }
        elseif ($nm -match '^(Out|out|W|Sum)') { $outs += $nm }
        else { $other += ($nm + '(' + $dir + ')') }
    }
    $md.Add('')
    $md.Add('| | contacts |')
    $md.Add('| --- | --- |')
    $md.Add('| in | ' + $(if ($ins.Count) { ($ins -join ', ') } else { '-' }) + ' |')
    $md.Add('| out | ' + $(if ($outs.Count) { ($outs -join ', ') } else { '-' }) + ' |')
    if ($other.Count) { $md.Add('| other | ' + ($other -join ', ') + ' |') }

    # options
    if ($cam.Options.Count -gt 0) {
        $md.Add('')
        $md.Add('| option | selected | choices (exact text) |')
        $md.Add('| --- | --- | --- |')
        for ($i = 0; $i -lt $cam.Options.Count; $i++) {
            $o = $cam.Options.Item($i)
            $ch = @()
            for ($j = 0; $j -lt $o.Choices.Count; $j++) { $ch += (AD2-ChoiceText $o.Choices.Item($j)) }
            $sel = ''
            try { $sel = (AD2-ChoiceText $o.SelectedChoice) } catch { }
            $md.Add('| ' + $o.Name + ' | ' + $sel + ' | ' + ($ch -join ' / ') + ' |')
        }
    }

    # parameters
    if ($cam.Parameters.Count -gt 0) {
        $md.Add('')
        $md.Add('| parameter | default | realized |')
        $md.Add('| --- | --- | --- |')
        for ($i = 0; $i -lt $cam.Parameters.Count; $i++) {
            $p = $cam.Parameters.Item($i)
            $real = ''
            try { $real = $p.Realized } catch { }
            $md.Add('| ' + $p.Name + ' | ' + $p.Value + ' | ' + $real + ' |')
        }
    }
    $md.Add('')
}

AD2-Close $app
$md.Add('---')
$md.Add('')
$md.Add('probed ' + $types.Count + ' types: ' + $okCount + ' added, ' + $failCount + ' rejected')

$md -join "`r`n" | Set-Content $OutFile -Encoding UTF8
AD2-Log ('wrote ' + $OutFile + '  ok=' + $okCount + ' fail=' + $failCount)
