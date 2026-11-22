# CAM catalogue (as probed from AnadigmApex 1.x)

Obtained with `scripts/probe.ps1 -Catalog`. Contacts are listed in the order
`Contacts.Item(i)` returns them, which is not alphabetical.

---

## `AnadigmApex\SumIntegrator`

Summing integrator, up to three input pins, **independent gain per pin**.

| contacts (with `in3` off) | contacts (with `in3` on) |
| --- | --- |
| `Input2`, `Input1`, `Out` | `Input2`, `Input1`, `Input3`, `Out` |

| option | choices | default |
| --- | --- | --- |
| `outp` | `Phase 1`, `Phase 2` | Phase 1 |
| `in1` | `Non-inverting`, `Inverting` | Non-inverting |
| `in2` | `Non-inverting`, `Inverting` | Non-inverting |
| `in3` | `Off`, `Non-inverting`, `Inverting` | Off |
| `ctrl` | `No Reset`, `Signal Ground`, `Dual Input`, `Variable Reference` | No Reset |

Parameters: `K1`, `K2` (and `K3` once `in3` is not `Off`). Default `4`
(= 4000000 1/s). Realisable range at 4 MHz: `0.04 .. 15.7`; at 16 MHz:
`0.16 .. 3.67`.

**`in1` and `in2` cannot be turned off.** A node that only needs one input must
tie the spare pin to a 0 V source.

---

## `AnadigmApex\Integrator`

Single-input integrator.

| contacts | `In`, `Out` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `pol` | `Non-inverting`, `Inverting` | Non-inverting |
| `isp` | `Phase 1`, `Phase 2` | Phase 1 |
| `ctrl` | `No Reset`, `Signal Ground`, `Dual Input`, `Variable Reference` | No Reset |

Parameter: `K` (default 4).

---

## `AnadigmApex\Hold`

Sample and hold. **The only CAM that satisfies the zero-delay-loop checker.**

| contacts | `In`, `Out` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `isp` | `Phase 1`, `Phase 2` | Phase 1 |

Adds exactly one clock of delay and outputs a value valid in both phases.

---

## `AnadigmApex\GainHold`

Gain plus sample-and-hold. Convenient as "a gain with one clock of delay", but
⚠️ **it does not count as a delay for the loop checker.**

| contacts | `In`, `Out` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `isp` | `Phase 1`, `Phase 2` | Phase 1 |

Parameter: `G` (default 1). Measured effective gain when used mid-chain is lower
than nominal (about 0.65x for `G = 0.2`) because the output is only refreshed
once per clock; calibrate it.

---

## `AnadigmApex\GainPolarity`

Gain whose sign is flipped by a control signal. Useful as a plain gain when
`ctrl = Signal Ground`.

| contacts | `Control`, `In`, `Invert`, `Out` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `ctrl` | `Signal Ground`, `Dual Input`, `Variable Reference` | Signal Ground |
| `inv` | `Control High`, `Control Low` | Control High |
| `outp` | `Phase 1`, `Phase 2` | Phase 1 |
| `type` | `Half Cycle`, `Low Pass Bilinear` | Half Cycle |

Parameter: `G` (default 1).

---

## `AnadigmApex\Multiplier`

Four-quadrant multiplier.

| contacts | `Y`, `X`, `Out` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `hold` | `Off`, `Input X` | Off |

Parameter: `M` (default 1). Output is `M * X * Y` (verified at `M = 1` and
`M = 2`). It is a **half-cycle CAM**: the output is only valid for half a clock,
which shows up as a 10-15 % loss in the effective gain of the branch it feeds.
Note `hold` has no `On` choice; `On` throws and is then silently ignored if you
do not check the return.

---

## `AnadigmApex\RectifierFilter`

Precision rectifier followed by a low-pass filter.

| contacts | `In`, `Out` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `rect` | `Full Wave`, `Positive Half Wave`, `Negative Half Wave` | Full Wave |
| `pol` | `Non-inverting`, `Inverting` | Non-inverting |

Parameters: `Fo` (corner frequency in kHz, default 40), `G` (default 1).

**Set `Fo` high enough or the filter round-off corrupts the rectified value.**
For a signal whose fundamental is around 10 kHz, `Fo = 400` was needed; at the
default 40 kHz the reconstructed `|x|` correlated only 0.65 with the true
absolute value, versus 0.997 at 400 kHz. The filter also injects a lag of
roughly `1/(2*pi*Fo)` which must be included in any delay budget.

---

## `AnadigmApex\RectifierHalf`

Half-wave rectifier that *does* expose an `outp` option, so its output phase can
be chosen.

| contacts | `In`, `Out` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `rect` | `Full Wave`, `Positive Half Wave`, `Negative Half Wave` | Full Wave |
| `pol` | `Non-inverting`, `Inverting` | Non-inverting |
| `outp` | `Phase 1`, `Phase 2` | Phase 1 |

Parameter: `G` (default 1). Output is valid for half a clock only.

---

## `AnadigmApex\SumFilter`

Two-input summing filter. Note the parameters are **filter** parameters, not
integrator gains.

| contacts | `Input2`, `Input1`, `Out` (plus `Input3` once `in3` is enabled) |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `outp` | `Phase 1`, `Phase 2` | Phase 1 |
| `in1`, `in2` | `Non-inverting`, `Inverting` | Non-inverting |
| `in3` | `Off`, `Non-inverting`, `Inverting` | Off |

Parameters: `Fo` (default 40), `G1`, `G2` (default 1 each). As with
`SumIntegrator`, `in1`/`in2` cannot be switched off.

---

## `AnadigmApex\TransferFunction`

Arbitrary lookup-table CAM - the way to build a nonlinearity such as `tanh`.

| contacts | `In`, `Out` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `hold` | `Off`, `On` | Off |

⚠️ This is the **only** CAM whose `hold` option accepts `On`. The `Multiplier`'s
`hold` offers `Off` / `Input X`, and writing `On` there throws and is then
ignored. If a note says "set hold = On to break the loop", it refers to this CAM.

The table itself is not reachable through the documented COM properties; write it
separately through the LUT editor.

---

## `AnadigmApex\Comparator`

| contacts | `In`, `Out` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `inputs` | `Signal Ground`, `Dual Input`, `Variable Reference` | Signal Ground |
| `isp` | `Phase 1`, `Phase 2` | Phase 1 |
| `pol` | `Non-inverted`, `Inverted` | Non-inverted |

Mind the spelling: comparators use `Non-inverted`/`Inverted`, integrators use
`Non-inverting`/`Inverting`. Passing the wrong word throws.

---

## Not available in this library

`AnadigmApex\SampleHold` - `Cams.Add` fails; use `Hold` or `GainHold`.
`AnadigmApex\Gain` - fails with `RPC_E_SERVERFAULT`; use `GainHold` or
`GainPolarity`.

## Warning: `.Type` may come back empty

On several CAM instances `cam.Type` returns an empty string even though the CAM
exists (its class shows as e.g. `AnadigmApex\Hold 1.0.2 (Sample and Hold)` in the
properties dialog). Identify CAMs by the `.Name` you assigned, and remember the
type string you passed to `Cams.Add`.

---

## IO cell

Nine entries per chip: `IOCell1..7` (analog, indices `0..5` and `8`),
`RAM_Transfer_Cell` (index 6), `Digital_IOCell` (index 7).

| contacts | `In_neg`, `In_pos`, `Out`, `Out_neg`, `Out_pos` |
| --- | --- |

| option | choices | default |
| --- | --- | --- |
| `mode` (option 0) | `Input`, `Output`, and two further modes | Input |
| `type` | `Bypass` and two further choices | Bypass |

- In `Input` mode the value enters the chip through the internal contact `Out`.
- In `Output` mode the CAM is driven through the internal contact `In`, and the
  signal leaves on `Out_pos` / `Out_neg`.
- An `Output` cell with nothing wired to `In` is a netlist error.
- One output contact may fan out to several destinations; two drivers on the same
  net is an error (`Cannot connect more than one output contact to the same
  equipotential`).

---

## What is not in the library

`AnadigmApex\Gain` does not exist - `Cams.Add` throws `RPC_E_SERVERFAULT`. Use
`GainHold` or `GainPolarity` instead.


