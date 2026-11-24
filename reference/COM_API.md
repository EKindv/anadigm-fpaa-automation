# Verified COM surface of AnadigmDesigner2

Everything below was confirmed against real runs. There is no vendor
documentation; this is what the object model actually exposes.

## Entry point

```powershell
$app = New-Object -ComObject "AnadigmDesigner2.Application"
```

Out-of-process server, one `AD20` process per `CreateObject`. There is no
singleton behaviour, so a second call gives a second independent editor.

| member | notes |
| --- | --- |
| `$app.Visible` | **false by default** when started through COM. Keep it `true`: a hidden instance still simulates, but `SaveSimulatorData` then writes only the time column (see PITFALLS 18). |
| `$app.Document.Open(path, 0, $false, $false)` | flags are unused in practice; the object model answers only after the load finishes, so poll afterwards. |
| `$app.Document.SaveAs(path, $true)` | the second argument is overwrite. |
| `$app.Document.Oscilloscope` | not exposed. |
| `$app.Workspace` | -> `.Chips` |
| `$app.Simulator` | -> `.Probes`, `.SignalGenerators`, `.StartTime`, `.EndTime`, `.TimeStep`, `.Iterations`, `.CurrentIteration`, `.IsRunning`, `.Start()`, `.SaveSimulatorData(path)` |
| `$app.Quit()` | exists but does **not** reliably terminate the process. Use `Stop-Process`. |

`Simulator.EndTime` is in **milliseconds**. `IsRunning` throws a COM exception
carrying the simulator's error text when the netlist is invalid, which is the
only way to read those messages from a script.

## Workspace geometry

```powershell
$app.Workspace.Chips            # collection
$app.Workspace.Chips.Add(9)     # 9 = AN231E04; returns the new chip
$chip.Cams                      # collection: .Add(typeName), .Item(i), .Count
$chip.IOCells                   # collection: 9 entries, .Item(i)
$chip.Clocks                    # collection of available clocks
```

- **Type id** for `Chips.Add`: `9` = AN231E04 (4 CABs, 8 op-amps, 8 CAM slots).
- **8 CAMs per chip maximum.** The ninth `Cams.Add` throws.
- **`Cams.DeleteAll()` silently does nothing.** Delete backwards by index.
- `Cams.Add(typeName)` takes a string like `"AnadigmApex\SumIntegrator"` and
  appends; the new CAM is `Cams.Item(Cams.Count - 1)`. Assign `.Name` yourself.
- IO cell index map: `0..5` and `8` are analog `IOCell1..7`; `6` is
  `RAM_Transfer_Cell`; `7` is `Digital_IOCell`. Only the analog cells can be
  switched to `Output`.

## CAM object

| member | notes |
| --- | --- |
| `.Name` | free-form instance name, settable |
| `.Type` | e.g. `AnadigmApex\SumIntegrator` |
| `.Options` | `.Count`, `.Item(i)` -> option |
| `.Parameters` | `.Count`, `.Item(i)` -> parameter |
| `.Contacts` | `.Count`, `.Item(i)` -> contact, has `.Name`, `.ConnectWire(other)` |
| `.Clocks` | `.Item(0).ChipClock` -> clock object with `.Name`, `.Frequency` (kHz) |
| `.Delete()` | removes it |

### Option object

`.Name`, `.SelectedChoice` (assignable string), `.Choices` (collection).
Choice entries are COM objects, not strings: read them with `[string]$choice`
or `$choice.Name`.

Assigning an invalid `SelectedChoice` throws; assigning a valid one that the CAM
does not apply fails silently, so always read the value back if it matters.

### Parameter object

`.Name`, `.Value` (assignable double), `.Realized` (what the switched-capacitor
network can actually build). No `MinValue` / `MaxValue` is exposed.

**Compare `.Value` with `.Realized`.** AD2 quantises gains to realisable ratios;
a 10 %+ mismatch means your coefficient will not be what the maths assumed.

## Contacts

`ConnectWire` on an output contact takes the *other* contact:

```powershell
(contactA).ConnectWire(contactB)
```

Cross-chip wiring is refused (`Cannot wire across chip boundaries`). Route
through IO cells, and connect **both** `Out_pos -> In_pos` and
`Out_neg -> In_neg`.

## Simulator probes and data

- **At most 4 probes.** The fifth throws `The maximum number of probes has been
  reached`.
- `Probes.Add(contact)` takes a CAM contact, not an IO cell.
- `SaveSimulatorData(path)` writes CSV: `Time, Channel 1..N`, time in **seconds**,
  sampled at half the clock period.
- Probes added after a CAM rebuild can be lost; build, run and dump in one
  session.

## Signal generators

```powershell
$g = $app.Simulator.SignalGenerators.Add(contact, typeIndex)
```

`contact` is normally `(IO cell contact 'In_neg')`. **Always keep the return
value**: `SignalGenerators.Item(Count-1)` is not reliably the generator you just
added once there is more than one, and you will overwrite the wrong source.

Properties: `Type`, `WaveForm`, `Phase`, `Frequency`, `Amplitude`, `DCOffset`,
`CommonModeOffset`, `DifferentialOffset`, `DutyCycle`, `PulseDelay`,
`PulsePeriod`, `PulseWidth`, `WaveFormFile`, `PrimaryContact`.

Measured voltage mapping for the default (sine) type:

```
V_out = (DCOffset - 2)/2 + (Amplitude/2) * sin(2*pi*Frequency*t)
```

so a DC of V volts is `DCOffset = 2 + 2V`, `Amplitude = 0`. Verified: with
`K = 0.04 1/us`, `DCOffset = 2.7142857` on an integrator input ramps at exactly
`0.01429 V/us`, i.e. `V_in = 0.35714 V`.

## Clock and gain arithmetic

`$cam.Clocks.Item(0).ChipClock.Frequency` reports kHz. Default is Clock 0 at
4000 kHz; the chip also offers higher clocks (Clock 4 = 16000 kHz), selectable
per CAM with `$cam.Clocks.Item(0).ChipClock = $otherClock`.

The device invariant to design around:

```
K_min * T_clk = 0.01        (K in 1/us, T_clk in us)
```

At 4 MHz: `K_min = 0.04`, one clock = `0.01` model time units = 0.25 us, and
`1/K = 25 us` is one model time unit. Parameter headings `K1..K3` on a
`SumIntegrator` are **per input pin**, which lets one pin carry a different
weight - very useful for product terms, because it removes the need for a gain
CAM.

## Things that are NOT exposed

- No way to set integrator initial conditions.
- No reset / restart primitive other than re-downloading the configuration.
- No access to the oscilloscope window.
- No batch or headless flag: the GUI window exists even when `Visible = $false`.
- The simulator is **single threaded**; there is nothing to tune.

