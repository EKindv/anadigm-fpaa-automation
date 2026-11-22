# build_example.ps1 -- complete worked example: a 4-dimensional chaotic system on
# two AN231E04 chips, 10 CAMs, cross-chip feedback, zero-delay loops broken with
# Hold CAMs. Copy this file and edit section 2 to build your own system.
#
# The system (model time units):
#     x' = y
#     y' = u - x + y*z
#     z' = 5 - |y| - 0.2*z
#     u' = y*z
#
# Voltage scaling: state = S * V, so with the clock at 4 MHz and K = 0.04 1/us,
#     Vx' = Vy
#     Vy' = Vu - Vx + (K3/K)*VyVz        K3 = K*S   (per-pin integrator gain!)
#     Vz' = (5/S) - |Vy| - 0.2*Vz
#     Vu' = (K1u/K)*VyVz                 K1u = K*S
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File build_example.ps1 `
#       -Template "C:\path\one_chip.ad2" -Out "C:\path\p17.ad2" -Csv "C:\path\w.csv"
#
# ASCII only.

param(
    [Parameter(Mandatory = $true)][string]$Template,
    [Parameter(Mandatory = $true)][string]$Out,
    [Parameter(Mandatory = $true)][string]$Csv,
    [double]$EndMs = 20,
    [string]$LogFile = 'build_example.log'
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\ad2_lib.ps1"
AD2-Init $LogFile

# ----------------------------------------------------------------- 1. setup
$app = AD2-Open -Path $Template        # AD2-Open also kills stale AD20 processes
for ($gi = $app.Simulator.SignalGenerators.Count - 1; $gi -ge 0; $gi--) {
    try { $app.Simulator.SignalGenerators.Item($gi).Delete() } catch { }
}
$chips = AD2-EnsureChips -App $app -Count 2
$c1 = $chips.Item(0); $c2 = $chips.Item(1)
foreach ($c in @($c1, $c2)) { $null = AD2-ClearCams $c }
AD2-Log ('chips=' + $chips.Count)

# ------------------------------------------------------- 2. the devices
# EDIT HERE for your own system.
$S = 20.0
$K = 0.04
$Ks = $K * $S

$x  = AD2-AddCam $c1 'AnadigmApex\SumIntegrator' 'x'
$y  = AD2-AddCam $c1 'AnadigmApex\SumIntegrator' 'y'
$z  = AD2-AddCam $c1 'AnadigmApex\SumIntegrator' 'z'
$u  = AD2-AddCam $c1 'AnadigmApex\SumIntegrator' 'u'
$hz = AD2-AddCam $c1 'AnadigmApex\Hold'           'holdZ'     # breaks z self loop
$gh = AD2-AddCam $c1 'AnadigmApex\GainHold'       'g02'       # the 0.2 damping
$hp = AD2-AddCam $c1 'AnadigmApex\Hold'           'holdP'     # breaks the product loop
$hx = AD2-AddCam $c1 'AnadigmApex\Hold'           'holdX'     # breaks the x<->y loop
$rc = AD2-AddCam $c2 'AnadigmApex\RectifierFilter' 'rect'
$ml = AD2-AddCam $c2 'AnadigmApex\Multiplier'      'mult'

# clock and gain
$clk = $x.Clocks.Item(0).ChipClock
AD2-Log ('clock ' + $clk.Name + ' = ' + $clk.Frequency + ' kHz')
$fMHz = [double]$clk.Frequency / 1000.0
$K = 0.01 * $fMHz                    # device invariant: K_min * T_clk = 0.01
$Ks = $K * $S
AD2-Log ('K=' + $K + '  K*S=' + $Ks)

# options
$null = AD2-SetOpt $x 'outp' 'Phase 1'; $null = AD2-SetOpt $x 'in1' 'Non-inverting'
$null = AD2-SetOpt $x 'in2' 'Inverting'; $null = AD2-SetOpt $x 'in3' 'Off'
$null = AD2-SetOpt $y 'outp' 'Phase 1'; $null = AD2-SetOpt $y 'in1' 'Non-inverting'
$null = AD2-SetOpt $y 'in2' 'Inverting'; $null = AD2-SetOpt $y 'in3' 'Non-inverting'
$null = AD2-SetOpt $z 'outp' 'Phase 1'; $null = AD2-SetOpt $z 'in1' 'Non-inverting'
$null = AD2-SetOpt $z 'in2' 'Inverting'; $null = AD2-SetOpt $z 'in3' 'Non-inverting'
$null = AD2-SetOpt $u 'outp' 'Phase 1'; $null = AD2-SetOpt $u 'in1' 'Non-inverting'
$null = AD2-SetOpt $u 'in2' 'Inverting'; $null = AD2-SetOpt $u 'in3' 'Off'
foreach ($h in @($hz, $gh, $hp, $hx)) { $null = AD2-SetOpt $h 'isp' 'Phase 1' }
$null = AD2-SetOpt $rc 'rect' 'Full Wave'; $null = AD2-SetOpt $rc 'pol' 'Non-inverting'
$null = AD2-SetOpt $ml 'hold' 'Off'          # valid choices are 'Off' and 'Input X'

# parameters.  NOTE the compensation factors: a half-cycle CAM loses gain, so the
# nominal 0.80 / 0.20 come out around 0.69 / 0.13.  0.92 and 0.34 put the
# realised coefficients back on the design values.
$null = AD2-SetPar $x 'K1' $K; $null = AD2-SetPar $x 'K2' $K
$null = AD2-SetPar $y 'K1' $K; $null = AD2-SetPar $y 'K2' $K; $null = AD2-SetPar $y 'K3' 0.92
$null = AD2-SetPar $z 'K1' $K; $null = AD2-SetPar $z 'K2' $K; $null = AD2-SetPar $z 'K3' $K
$null = AD2-SetPar $u 'K1' 0.92; $null = AD2-SetPar $u 'K2' $K
$null = AD2-SetPar $rc 'Fo' 400; $null = AD2-SetPar $rc 'G' 1.0
$null = AD2-SetPar $ml 'M' 1
$null = AD2-SetPar $gh 'G' 0.34

# IO cells: 0..5 and 8 are analog, 6 is RAM transfer, 7 is digital
$iDC = AD2-IoMode $c1 0 'Input'      # constant 5/S
$iGN = AD2-IoMode $c1 1 'Input'      # startup dither into x
$oY2 = AD2-IoMode $c1 2 'Output'     # y -> chip 2
$oZ2 = AD2-IoMode $c1 3 'Output'     # z -> chip 2
$iRC = AD2-IoMode $c1 4 'Input'      # rect -> chip 1
$iML = AD2-IoMode $c1 5 'Input'      # mult -> chip 1
$iG2 = AD2-IoMode $c1 8 'Input'      # clean 0 V for u.Input2
$iY2 = AD2-IoMode $c2 0 'Input'
$iZ2 = AD2-IoMode $c2 1 'Input'
$oRC2 = AD2-IoMode $c2 2 'Output'
$oML2 = AD2-IoMode $c2 3 'Output'

# ------------------------------------------------------- 3. wiring, chip 1
$ok = 0; $tot = 0
$links = @(
    @($y, 'Out', $x, 'Input1'),   @($iGN, 'Out', $x, 'Input2'),
    @($u, 'Out', $y, 'Input1'),   @($hx, 'Out', $y, 'Input2'),  @($hp, 'Out', $y, 'Input3'),
    @($iDC, 'Out', $z, 'Input1'), @($iRC, 'Out', $z, 'Input2'), @($gh, 'Out', $z, 'Input3'),
    @($hp, 'Out', $u, 'Input1'),  @($iG2, 'Out', $u, 'Input2'),
    @($z, 'Out', $hz, 'In'), @($hz, 'Out', $gh, 'In'), @($x, 'Out', $hx, 'In'),
    @($y, 'Out', $oY2, 'In'), @($z, 'Out', $oZ2, 'In'), @($iML, 'Out', $hp, 'In')
)
foreach ($l in $links) { $tot++; if (AD2-Ln $l[0] $l[1] $l[2] $l[3]) { $ok++ } }
AD2-Log ('chip1 links ' + $ok + '/' + $tot)

# ------------------------------------------------------- 4. wiring, chip 2
$ok = 0; $tot = 0
$links = @(
    @($iY2, 'Out', $rc, 'In'), @($iY2, 'Out', $ml, 'X'), @($iZ2, 'Out', $ml, 'Y'),
    @($rc, 'Out', $oRC2, 'In'), @($ml, 'Out', $oML2, 'In')
)
foreach ($l in $links) { $tot++; if (AD2-Ln $l[0] $l[1] $l[2] $l[3]) { $ok++ } }
AD2-Log ('chip2 links ' + $ok + '/' + $tot)

# ------------------------------------------------------- 5. cross chip
$cross = 0
foreach ($p in @(
    @($oY2, $iY2), @($oZ2, $iZ2), @($oRC2, $iRC), @($oML2, $iML)
)) { if (AD2-LinkChips $p[0] $p[1]) { $cross++ } }
AD2-Log ('cross-chip pairs ' + $cross + '/4')

# ------------------------------------------------------- 6. sources
$null = AD2-AddDcSource -App $app -InputCell $iDC -Volts (5.0 / $S)
$null = AD2-AddDcSource -App $app -InputCell $iG2 -Volts 0.0
# startup kick: the all-zero state is invariant (x=y=u stay 0), so a real chip
# starts on op-amp offsets alone; in the simulator a dither is needed.
$null = AD2-AddGenerator -App $app -Contact (AD2-Ct $iGN 'In_neg') -DcOffset 2.0 -Amplitude 0.02 -FrequencyHz 500

# ------------------------------------------------------- 7. run and dump
$sim = $app.Simulator
$sim.Probes.DeleteAll()
$sim.Probes.Add((AD2-Ct $x 'Out')) | Out-Null
$sim.Probes.Add((AD2-Ct $y 'Out')) | Out-Null
$sim.Probes.Add((AD2-Ct $z 'Out')) | Out-Null
$sim.Probes.Add((AD2-Ct $u 'Out')) | Out-Null
AD2-Log ('probes=' + $sim.Probes.Count)

$result = AD2-Run -App $app -EndMs $EndMs
if ($result -eq 'ok') { $null = AD2-Dump -App $app -CsvPath $Csv }
$null = AD2-Save -App $app -Path $Out
AD2-Close $app


