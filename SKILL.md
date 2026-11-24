---
name: anadigm-fpaa-automation
description: Build, wire and simulate AnadigmDesigner2 (AD2) switched-capacitor FPAA circuits through COM automation on Windows. Use when a task involves AN231E04 / AN231E04-class FPAA design files (.ad2), AnadigmDesigner2, the "AD20" process, or reproducing / verifying an analog dynamical system (chaotic circuit, oscillator, filter) on an FPAA. Covers launching AD2 headless, eating its modal dialogs, adding and wiring CAMs including across chips, enumerating every CAM option and parameter, running the simulator and dumping waveforms to CSV.
---

# AnadigmDesigner2 COM automation

AD2 has no documented scripting API. Everything here was reverse-engineered by
probing the COM surface and is verified against real runs. Follow the order
below; the traps in `reference/PITFALLS.md` cost hours each if you hit them cold.

## 0. Before you touch anything

- Windows only, Windows PowerShell 5.1 (`powershell.exe`) or PowerShell 7.
- **All `.ps1` files you write must be pure ASCII.** Windows PowerShell reads
  script files as the system ANSI code page (GBK on a Chinese system) when there
  is no BOM. A single Chinese character in a `.ps1` turns into garbage and
  produces a bogus parse error, or worse, a mangled file path at runtime.
  Pass non-ASCII paths in as **arguments**, never as literals inside the script.
- AD2's simulator is **single threaded**. 8 ms of simulated time takes ~22 s of
  wall clock on a modern laptop, saturating exactly one core. Parallel instances
  only buy ~1.3x, so do not build a worker pool; shorten `EndTime` instead.

## 1. The five-step recipe

```
1. start the dialog watchdog        scripts/watchdog.ps1   (separate process)
2. launch AD2 + open a template     $app = New-Object -ComObject "AnadigmDesigner2.Application"
3. build / wire the circuit         dot-source scripts/ad2_lib.ps1
4. run the simulator                $sim.EndTime = <ms>; $sim.Start()
5. dump the waveform                $sim.SaveSimulatorData(csv)
```

The watchdog is not optional. AD2 puts up **modal** dialogs on almost every
error (resource limits, unconnected pins, zero-delay loops) and a modal dialog
blocks *every* COM call from your process, so a headless script hangs forever
rather than throwing. `scripts/watchdog.ps1` closes them by window class
`#32770` every 400 ms.

## 2. Launching

```powershell
$app = New-Object -ComObject "AnadigmDesigner2.Application"
$app.Visible = $true                       # REQUIRED: hidden = no channels in the CSV
$app.Document.Open($ad2Path, 0, $false, $false)
# the object model is not ready immediately - poll until it answers
for ($k = 0; $k -lt 40; $k++) {
    try { if ($app.Workspace.Chips.Count -ge 1) { break } } catch { }
    Start-Sleep -Milliseconds 400
}
```

Each `CreateObject` starts its own `AD20` process. `Application.Quit()` does not
reliably kill it; use `Get-Process AD20 | Stop-Process -Force`.

## 3. Building

```powershell
$chips = $app.Workspace.Chips
if ($chips.Count -lt 2) { $null = $chips.Add(9) }    # 9 = AN231E04
$c1 = $chips.Item(0); $c2 = $chips.Item(1)
```

- **A chip holds at most 8 CAMs** (4 CABs x 2). The 9th `Cams.Add` throws.
- `Cams.DeleteAll()` is a **no-op**; delete backwards:
  `for ($i = $chip.Cams.Count - 1; $i -ge 0; $i--) { $chip.Cams.Item($i).Delete() }`
- Add a CAM, then read it back by index:
  `$chip.Cams.Add("AnadigmApex\SumIntegrator"); $cam = $chip.Cams.Item($chip.Cams.Count - 1)`
- Every CAM has `Options`, `Parameters`, `Contacts`, `Clocks`, plus `.Name` / `.Type`.

Full helper set (retry wrappers, contact lookup, wiring): `scripts/ad2_lib.ps1`.
Non-obvious helpers it provides:

| helper | why it exists |
| --- | --- |
| `AD2-Ct $cam 'Input3'` | contacts are only reachable by scanning `Contacts.Item(i).Name` |
| `AD2-SetOpt` / `AD2-SetPar` | both fail **silently** otherwise; always check the return |
| `AD2-Retry` | wrap every COM call; transient RPC faults are normal |
| `AD2-Ln` | `ConnectWire`; logs the source contact name on failure |

## 4. Options and parameters

Options are enums whose choice text you cannot read directly:

```powershell
for ($i = 0; $i -lt $cam.Options.Count; $i++) {
    $o = $cam.Options.Item($i)
    for ($j = 0; $j -lt $o.Choices.Count; $j++) {
        $txt = [string]$o.Choices.Item($j)          # works; .Name also works
    }
    $o.SelectedChoice = 'Inverting'                  # assign by exact text
}
```

`Parameters.Item(i)` has `.Name`, `.Value`, `.Realized`. **Compare `Value` with
`Realized`**: AD2 quantises to what the switched-capacitor network can build, and
a large mismatch means your coefficient is not what you think it is.

Run `scripts/probe.ps1` against any `.ad2` to dump the whole catalog of what each
CAM type accepts. `reference/CAM_CATALOG.md` lists **all 49 AnadigmApex CAMs**
with their exact contact names, option strings and parameters - it is complete for
AN231E04, so there is no need to guess or to consult a datasheet.

Same chip: just connect two contacts.

```powershell
(AD2-Ct $camA 'Out').ConnectWire((AD2-Ct $camB 'Input1'))
```

Different chips: **you cannot wire CAM-to-CAM**. Route through IO cells, and wire
**both halves** of the differential pair:

```powershell
$out.Out_pos -> $in.In_pos
$out.Out_neg -> $in.In_neg
```

IO cell modes/contacts:

| mode | internal contact | external contacts |
| --- | --- | --- |
| `Input` | `Out` | `In_pos`, `In_neg`, `Out_pos`, `Out_neg` |
| `Output` | `In` | `In_pos`, `In_neg`, `Out_pos`, `Out_neg` |

`$chip.IOCells` has 9 entries: indices `0..5` and `8` are the seven analog
`IOCell1..7`; index `6` is `RAM_Transfer_Cell`, index `7` is `Digital_IOCell`.
Only the analog ones can be switched to `Output`.

## 6. Signal sources

```powershell
$g = $app.Simulator.SignalGenerators.Add((AD2-Ct $inputCell 'In_neg'), 0)
$g.Amplitude = 0.0; $g.DCOffset = 2.5; $g.CommonModeOffset = 0.0; $g.Frequency = 100
```

- **Use the return value of `Add`.** After adding two generators,
  `SignalGenerators.Item(Count-1)` may hand you the wrong one and you will
  silently overwrite the other source.
- Voltage mapping (measured): `V = (DCOffset - 2)/2 + (Amplitude/2)·sin(2πft)`.
  So a DC of V volts needs `DCOffset = 2 + 2V`, `Amplitude = 0`.
- Available generator properties: `Type`, `WaveForm`, `Phase`, `DutyCycle`,
  `PulseDelay`, `PulsePeriod`, `PulseWidth`, `WaveFormFile`.

## 7. Running and dumping

```powershell
$sim = $app.Simulator
$sim.Probes.DeleteAll()
$sim.Probes.Add((AD2-Ct $camX 'Out'))
$sim.EndTime = 20                                  # MILLISECONDS
$sim.Start()                      # returns immediately even if the netlist is bad
Start-Sleep -Milliseconds 1500
# A rejected netlist does NOT throw: IsRunning stays true for ever and
# CurrentIteration stays at 0. A healthy run has CurrentIteration > 0 by now.
if ($sim.IsRunning -and $sim.CurrentIteration -le 0) {
    # stalled. Dismissing the box does not unblock it; restart AD2 and rebuild.
    & "$PSScriptRoot\suppress_dialogs.ps1" -Seconds 8
    throw 'netlist rejected - restart AD2 (see PITFALLS 19)'
}
while ($sim.IsRunning) { Start-Sleep -Milliseconds 300 }
$sim.SaveSimulatorData($csvPath)
$app.Document.SaveAs($ad2Path, $true)
```

- **At most 4 probes.** The 5th throws "The maximum number of probes has been
  reached".
- The CSV is `Time, Channel 1..N`, time in **seconds**, sampled at half the clock
  period (0.125 us at 4 MHz).
- Build, run and dump in **one session**. Re-adding probes after rebuilding CAMs
  silently loses channels.

## 8. Circuit-level rules the simulator enforces

These are structural checks, not numerical ones:

1. **Zero-delay feedback loop.** Every cycle in the CAM graph must contain a
   delay element. Integrators do **not** count.
2. **`AnadigmApex\Hold` is the only CAM that breaks a loop.** `GainHold` is a
   sampled gain but the checker does not treat it as a delay; neither does
   `Multiplier`'s `hold` option (`Off` / `Input X`, and `On` is not a valid
   choice there - only `TransferFunction` accepts `hold = On`). Budget one
   `Hold` per independent cycle.
3. **A loop through an even number of integrators is rejected** as zero-delay,
   while an odd number is accepted (verified: 1-integrator self loop and
   3-integrator ring pass, 2-integrator ring fails). Put a `Hold` on one branch.
4. **`SumIntegrator` inputs `in1` and `in2` are mandatory** - only `in3` can be
   `Off`. A node that genuinely needs one input must have its second pin tied to
   a 0 V source (an input IO cell plus a generator with `DCOffset = 2`).
5. Every CAM output that is wired must have a real source; an output IO cell in
   `Output` mode with nothing inside it is an error.

## 9. Clock and gain arithmetic

```powershell
$clk = $cam.Clocks.Item(0).ChipClock          # -> .Name, .Frequency (kHz)
```

The device invariant that matters for time:

```
K_min * T_clk = 0.01        (K in 1/us, T_clk in us)
```

so at 4 MHz the smallest usable integrator gain is `K = 0.04 1/us`, one clock is
`0.01` model time units, and `1/K = 25 us` is one model time unit. Choosing a
larger K only stretches the delay measured in model time - it never buys you a
finer time resolution than `0.01` model units.

## 10. Verification checklist

Never trust a run until you have all four:

1. every `AD2-SetPar` returned true **and** `Value == Realized`
2. the link count matches what you intended (log `n/total`)
3. `Simulator.IsRunning` went false **without** a caught exception
4. the dumped CSV has the expected channel count and a plausible time span

Then identify the system from data (least squares on the sampled derivatives)
before believing any dynamics you see. `scripts/verify_equations.py` does this.

## Files

```
scripts/ad2_lib.ps1            dot-source: retry, contacts, options, wiring,
                               AD2-Run with stall detection, AD2-DismissDialogs
scripts/probe.ps1              dump every CAM type / option / parameter of a doc
scripts/build_example.ps1      full worked build (10 CAM, 2 chips, cross-chip IO)
scripts/run_dump.ps1           open a doc, run, dump CSV
scripts/verify_equations.py    recover state equations by regression
scripts/catalog_dump.ps1       probe EVERY CAM of a library (49 on AN231E04, ~15 s)
scripts/suppress_dialogs.ps1   answer the modal boxes from a helper process
scripts/test_stall.ps1         regression test: valid / stalled / after-restart
scripts/watchdog.ps1           legacy: closes dialogs blindly (see PITFALLS 19)
reference/COM_API.md           verified API surface and object model
reference/CAM_CATALOG.md       ALL 49 AnadigmApex CAMs: contacts, exact option
                               strings, parameters, plus field notes
reference/PITFALLS.md          every trap, including the stall mechanism (19, 20)
```



