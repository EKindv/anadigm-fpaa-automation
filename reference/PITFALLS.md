# Traps, with symptom and fix

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

