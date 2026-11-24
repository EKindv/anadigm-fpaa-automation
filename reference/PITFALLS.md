# Traps, with symptom and fix

> **Correction, measured 2026-11-22.** Trap 1 below records the first diagnosis
> and its numbers are right, but the mechanism is not: closing the modal box does
> **not** unblock anything, and the API never throws. The fully characterised
> behaviour is trap 19 - read that one first. The reliable signal is
> `Simulator.CurrentIteration == 0`, not the dialog.

Ordered by how much time they cost. Every one of these was hit for real.

---

## 1. A modal dialog hangs the whole script

**Symptom** `Simulator.Start()` never returns; the process is stuck; nothing is
logged; CPU idle.

**Cause** AD2 raises a *modal* dialog for every netlist error. While it is up the
automation server answers nothing, so your COM call blocks forever instead of
throwing.

**Fix** Run `scripts/watchdog.ps1` in a separate process. It enumerates windows of
class `#32770` belonging to `AD20` and posts ESC + `WM_CLOSE` every 400 ms.
Then **wrap `IsRunning`** - once the dialog is dismissed the pending call throws
and the exception message contains the real error text:

```powershell
try { $running = $sim.IsRunning } catch { Log $_.Exception.Message; break }
```

---

## 2. `.ps1` files must be pure ASCII

**Symptom** A cryptic parse error like `Unexpected token '}'`, or a file path that
comes back as mojibake (`鏂囨。` instead of `文档`), or `Unable to open circuit with
the specified path`.

**Cause** Windows PowerShell reads script files using the system ANSI code page
(GBK on a Chinese system) unless the file has a UTF-8 BOM. Any non-ASCII byte in
an ASCII-intended file is decoded as garbage, which can consume the closing quote
and corrupt the rest of the file.

**Fix** Keep `.ps1` sources ASCII-only and pass non-ASCII paths as **arguments**.
If you must have a BOM, write the file with one deliberately.

---

## 3. `SignalGenerators.Item(Count-1)` is the wrong generator

**Symptom** You set up two DC sources; one node ramps correctly, another sits at
0 V (or both behave identically). The readback of the parameter you set looks
right because you set it on the wrong object.

**Fix** Use the **return value** of `SignalGenerators.Add(...)`. Never index the
collection afterwards to find "the one I just made".

---

## 4. `GainHold` does not break a zero-delay loop

**Symptom** `Simulation Error: This circuit contains a loop which is not
simulating ... zero-delay feedback loop`. The listed CAMs include the ones you
thought were protected.

**Cause** The loop checker is **structural**. Integrators do not count as delays,
and `GainHold` - despite being a sampled gain - is not accepted either. Neither is
the `Multiplier`'s `hold` option.

**Fix** Put an `AnadigmApex\Hold` in every independent cycle. Budget one Hold per
cycle; they are the only reliable breaker.

---

## 5. A loop through an even number of integrators is rejected

**Symptom** A perfectly sensible two-integrator feedback pair
(`x` drives `y`, `y` drives `x`) is reported as a zero-delay loop, while a
three-integrator ring is accepted.

**Cause** Verified behaviour: 1-integrator self loops pass, 3-integrator rings
pass, 2-integrator rings fail. The checker appears to count phase parity rather
than loop-gain.

**Fix** Insert a `Hold` on one branch of the even-length loop. It costs one clock
of delay, so check the delay budget.

---

## 6. `SumIntegrator` pins `in1` and `in2` cannot be disabled

**Symptom** `Input Contact Node "Input2" from CAM "x" is not connected to any
Input Sources.` Setting `in2` to `Off` fails (`in2` only offers
`Non-inverting`/`Inverting`).

**Fix** Tie the spare pin to a real 0 V source: an input IO cell plus a generator
with `DCOffset = 2.0`. One such cell can feed several CAMs (fan-out is allowed).

---

## 7. The all-zero state is a dead point

**Symptom** The simulation runs without error but every state stays at 0 V
(except possibly one) forever.

**Cause** If the circuit's `x = y = u = 0` manifold is invariant, starting from a
freshly reset chip leaves the system on it. Real hardware escapes because of
op-amp offsets; the ideal simulator does not.

**Fix** Add a tiny startup excitation - a generator with a small amplitude and a
frequency well above the dynamics (e.g. 20 mVpp at 500 kHz) - and document that
the real chip needs none.

---

## 8. Options fail silently

**Symptom** `SetOpt` "succeeds" but the CAM behaves as before.

**Cause** An invalid `SelectedChoice` string throws, but a valid string that the
CAM does not apply is swallowed. Common mistake: `Multiplier.hold = 'On'` when the
only choices are `Off` and `Input X`.

**Fix** Read the option back, or check the return value of your helper. Enumerate
the allowed choice texts with `probe.ps1` instead of guessing.

---

## 9. Maximum four probes

**Symptom** `The maximum number of probes has been reached` on the fifth
`Probes.Add`.

**Fix** Probe only what you need, or run twice with different probe sets. Note
that re-adding probes after a CAM rebuild can lose channels, so do not rebuild
between changing probes and dumping.

---

## 10. Nominal gain is not realised gain

**Symptom** The equations you recover from the data have coefficients 10-35 %
below the ones you programmed, and the dynamics do not match the MATLAB reference.

**Cause** Half-cycle CAMs (`Multiplier`, rectifiers) hold their output for only
half a clock, so the branch feeding an integrator sees an effective gain below the
nominal value. `GainHold` is worse: about 0.65x at `G = 0.2`.

**Fix** Calibrate. Run once, regress the realised coefficients out of the data,
and adjust the programmed values by the measured ratio. In the worked example the
product pin gain went `0.80 -> 0.92` and the damping `0.20 -> 0.34` to land on the
design values.

---

## 11. The rectifier filter must be fast enough

**Symptom** The rectified `|x|` looks wrong; the reconstructed signal is a smoothed
version of the true absolute value, so the dynamics are qualitatively different.

**Cause** `RectifierFilter.Fo` defaults to 40 kHz. For a signal whose fundamental
is around 10 kHz that is far too slow.

**Fix** Raise `Fo` to roughly 40x the signal fundamental (400 kHz worked) and
remember the filter introduces a lag of about `1/(2*pi*Fo)` that belongs in the
delay budget.

---

## 12. The simulator is single threaded

**Symptom** 8 ms of simulated time takes ~22 s and the process uses exactly one
core on a 20-thread CPU.

**Fix** Nothing to tune - it is one thread by design. Parallel `AD20` instances
give about 1.3x, not 2x, and cost RAM plus dialog risk. The real lever is
`EndTime`, which the cost scales linearly with. Reuse one session for parameter
sweeps instead of rebuilding.

---

## 13. `Cams.DeleteAll()` is a no-op

**Symptom** `Cams.Count` is unchanged after calling it, and the next `Add` fails
because the chip is "full".

**Fix** `for ($i = $cam.Cams.Count - 1; $i -ge 0; $i--) { $Cams.Item($i).Delete() }`

---

## 14. Cross-chip wiring needs IO cells and both halves

**Symptom** `Cannot wire across chip boundaries`, or a cross-chip signal arrives
as half amplitude / floating.

**Fix** Route through an output IO cell on the source chip and an input IO cell on
the destination chip, and wire **both** `Out_pos -> In_pos` and
`Out_neg -> In_neg`. One pair per signal.

---

## 15. `Quit()` does not kill the process

**Symptom** `AD20` processes accumulate; later runs attach to a stale instance or
fight over dialogs.

**Fix** `Get-Process AD20 | Stop-Process -Force` before and after every session.

---

## 16. Reading the choice texts

**Symptom** Iterating `option.Choices` prints `System.__ComObject`.

**Fix** `[string]$choice` or `$choice.Name` gives the text.

---

## 17. Verify the equations, not just the picture

**Symptom** The phase portrait looks exactly like the reference figure, so you
conclude the circuit is right.

**Cause** A two-dimensional projection of a four-dimensional flow can look
identical for very different dynamics - and a quasi-periodic torus also produces a
"tangle" that looks chaotic.

**Fix** Run `scripts/verify_equations.py` first (do the recovered coefficients
match the design?), then a chaos test with controls. For the 0-1 test the sampling
rate matters: it must be a few points **per period**, not the raw simulation rate.
Feeding it data oversampled by two orders of magnitude gives `K ~ 0` even for
Lorenz.

---

## 18. A hidden AD2 exports only the time column

**Symptom** The run completes (`IsRunning` goes false, no exception), the CSV is
written with the right number of rows, but it has a single column: `Time`. No
channels at all.

**Cause** `SaveSimulatorData` only exports channels while the editor window is
**visible**. Setting `$app.Visible = $false` to run "headless" silently drops
every channel - there is no error.

**Fix** Keep the window visible whenever you intend to dump data:

```powershell
$app = New-Object -ComObject "AnadigmDesigner2.Application"
$app.Visible = $true          # required for SaveSimulatorData to emit channels
```

This is the one place where hiding the window costs you data rather than time.
`scripts/ad2_lib.ps1` therefore opens visible by default and takes `-Hidden` only
for runs whose output you do not need.

Related, and equally silent: a document is only fully bound on its **second**
`Start()` call after opening, so a short warm-up run before the real one is
cheap insurance.

---

## 19. A rejected netlist STALLS - it does not raise an error (supersedes trap 1)

**Symptom** `Simulator.Start()` returns at once. `Simulator.IsRunning` then
reports `true` for ever. No COM exception is ever thrown, no waveform is produced,
and a modal `Simulation Error` box sits on screen. A script that waits for
`IsRunning` to go false hangs until its own timeout - 90 s in our first runner.

**Measured behaviour** (each row was tested, not assumed):

| attempt | what actually happens |
| --- | --- |
| close the box (ESC, `WM_CLOSE`, or click OK) | box disappears, AD2 re-raises it immediately; nothing unblocks |
| tick *"Don't show this message again"* then OK | suppresses the box for the rest of **that process only**; it comes back after a restart |
| call `Start()` a second time in the same session | **never recovers** (waited 60 s) |
| read the message text out of the dialog | impossible - the text is owner-drawn; the only child controls are the two buttons |
| look at `Simulator.CurrentIteration` | **0 for ever** on a rejected netlist; **> 0 within the first clock** on a healthy run |
| kill AD20, reopen the document, run again | **recovers completely** |

**Fix: detect, do not cure.** `AD2-Run` samples `CurrentIteration` 1.5 s after
`Start()` and returns `'stalled'` instead of waiting out the timeout, which turns
a 90 s hang into a 1.5 s unambiguous failure:

```powershell
$sim.EndTime = $EndMs
$sim.Start()
Start-Sleep -Milliseconds 1500
$running = $sim.IsRunning
if ($running -and $sim.CurrentIteration -le 0) { return 'stalled' }
```

Recovery sequence:

```powershell
$r = AD2-Run -App $app -EndMs 20
if ($r -eq 'stalled') {
    $null = AD2-DismissDialogs     # makes the UI usable again, ticks "Don't show"
    AD2-Close $app                 # a second Start in this session will NOT work
    $app = AD2-Open -Path $doc     # fresh process, then rebuild and retry
}
```

`AD2-DismissDialogs` clicks the box (ticking the checkbox first) so you can see
the schematic again; `suppress_dialogs.ps1` is the same thing as a standalone
tool. Neither of them unblocks the simulator - only the restart does.

**Prevention beats all of this.** The two causes we hit most often are covered by
traps 6 and 20.

---

## 20. Reusing a saved document leaves IO cells in Output mode with no driver

**Symptom** After opening an existing `.ad2`, clearing its CAMs and building a new
circuit, the run stalls. Nothing you connected looks wrong.

**Cause** The IO cells keep the modes they had when the file was saved. A cell
left in `Output` mode with nothing wired to its internal `In` contact is a netlist
error in its own right ("Output contact ... is driving a wire while its input
contacts are not connected to Voltage sources"), and it is invisible in the CAM
list.

**Fix** After clearing, put every IO cell you are not using back into a safe
state, or start from a template whose IO cells are all `Input`. When in doubt,
open the saved document in the GUI once and look at the IO cells before scripting
against it.

---

## 21. Resource exhaustion is the ONE error AD2 reports cleanly

**Symptom** (the good case) `Cams.Add` throws, in about 0.2 s:

```
Not enough resources in chip FPAA1 for CAM AnadigmApex\SumIntegrator
```

That is the most legible message AD2 ever produces. Do not swallow it.

**Trap** A blanket retry wrapper hides it: 15 retries turned a 0.2 s, perfectly
readable rejection into a 7 s wait followed by a vague `FAIL add holdP`.
`AD2-AddCam` now recognises `Not enough resources` / `not a valid` and returns
`$null` immediately, logging the real message and the CAM count.

**Numbers** A chip takes at most **8 CAMs** (4 CABs x 2). The 9th always fails.
If you need more, use a second chip and cross-chip IO pairs (trap 14), or move a
gain function into a per-pin `K` (see `reference/CAM_CATALOG.md`,
`SumIntegrator`).

**Not the same error class as trap 19.** A design that is *over-resourced on
load* - a saved file that was legal when written - does not fail at `Add`; it
fails at `Start`, which is the silent stall of trap 19. Detect that one with
`CurrentIteration`.

---

## Safety note for trap 19: the 1.5 s check cannot kill a long run

Measured on an 8 ms simulation that took **33.5 s** of wall clock:

```
t=0.2s   iteration=3
t=1.2s   iteration=3027
t=15.0s  iteration=32814
t=31.9s  iteration=63558
t=33.5s  finished, counter back to 0
```

The counter climbs monotonically from the very first clock, so by the 1.5 s check
a healthy run is already in the thousands. Only a run frozen at exactly 0 is
reported as `stalled`.

---

## 22. The resource dialog BLOCKS `Document.Open` - answer it from another process

**Symptom** Opening a saved design that does not fit its chip hangs the script for
minutes. In the GUI a modal box is waiting:

```
AnadigmDesigner(R)2
Not enough resources available in chip "FPAA1" to accommodate this configuration
of CAM "mult". ... Do you want to keep these settings?      [Yes] [No]
```

Measured: `Document.Open` took **111.89 s** because a human eventually clicked it.

**Why a watchdog that only closes things never helped** Two separate mistakes:

1. The dialog's title is `AnadigmDesigner(R)2` - the registered-trademark character
   reads back as `?`. A dismissal helper that skips titles containing
   "AnadigmDesigner" (to protect the main frame) skips this dialog too. Match on
   the window class `#32770` instead; the main frame is never a `#32770`.
2. The box is raised while `Document.Open` is still on the stack, so the calling
   process is inside the COM call and cannot answer anything. The helper must
   already be running **before** `Open` is called.

**Answer YES, not No.** Verified behaviour:

| answer | what happens |
| --- | --- |
| **Yes** | the saved settings are kept, `Open` returns, the document loads as-saved (**4.9 s total**) |
| No | AD2 reopens a blocking `Set CAM Parameters` dialog for that CAM; the load went through four dialog rounds and took 31 s |

`Yes` therefore means "load the file as it is", which is exactly what automation
wants. Use `No` only when you deliberately want AD2 to back out of the saved
placement.

**Fix** `AD2-Open` starts `suppress_dialogs.ps1` as a hidden child process before
touching COM, and kills it afterwards:

```powershell
$helper = Start-Process powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass',
          '-File', $hp, '-Seconds', '120', '-LogFile', $hlog) -PassThru -WindowStyle Hidden
Start-Sleep -Milliseconds 700
$app.Document.Open($Path, 0, $false, $false)
Stop-Process -Id $helper.Id -Force
```

The helper answers: `Simulation Error` -> tick "Don't show" + OK; any other
`#32770` with Yes/No -> **Yes**; any other `#32770` with only OK -> OK. It never
touches `Oscilloscope ...` or `Set CAM Parameters`.

---

## 23. `Add-Type` treats a C# *warning* as an error, and it fails silently

This one cost hours: a dialog-dismissal helper compiled to nothing and every call
threw "unable to find type", which a `try/catch` around the call swallowed as an
empty result.

**Symptom** Reflection-heavy helper does nothing at all. No error text anywhere.

**Cause** `Add-Type` compiles with warnings-as-errors. A single unused local
variable (`string what;` assigned but never read, CS0219) is enough:

```
error CS0219: variable 'what' is assigned but its value is never used
```

With `-ErrorAction SilentlyContinue` on the `Add-Type` call, the failure is
invisible and `[MyType]` simply does not exist afterwards.

**Fix** Never pass `-ErrorAction SilentlyContinue` to `Add-Type`, and smoke-test a
new helper standalone before wiring it into a pipeline:

```powershell
try { Add-Type -TypeDefinition $code -ErrorAction Stop; 'COMPILE OK' }
catch { 'COMPILE FAILED: ' + $_.Exception.Message }
```
