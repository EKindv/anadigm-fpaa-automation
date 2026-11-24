
# CAM catalogue - every CAM the AN231E04 can host

Generated from the live COM object model, not from the datasheets: each type below
was really added to a chip and interrogated. **Option strings are exact** - pass
them verbatim to `AD2-SetOpt`, because a wrong spelling fails silently.

## Scope

| library | CAMs | works on AN231E04? |
| --- | --- | --- |
| `AnadigmApex` | **49** | **yes - this is the whole list** |
| `AnadigmVortex` | 50 | no: every one returns "is not compatible with chip FPAA1" |
| `AnadigmApexSE` | 5 | not tested |

So for this hardware, 49 is not a subset - it is everything. If a CAM is not in
this file it cannot be placed on an AN231E04.

## Regenerate this file on any machine

```powershell
# 1. list the type names from the installed library
$lib = 'C:\Program Files (x86)\Anadigm\AnadigmDesigner2\Libraries\AnadigmApex'
$names = (Get-ChildItem $lib -Filter *.cam | ForEach-Object { $_.BaseName }) -join ','
# 2. add every one to a scratch chip and dump its surface (about 15 s)
powershell -File scripts\catalog_dump.ps1 -Template <any ad2 with one chip> `
    -Namespace AnadigmApex -Only $names -OutFile raw.md
```

The `.cam` files in the installation are binary, so the type names come from the
file names and everything else from COM. Do not trust a printed manual over the
dump: this AD2 build already disagrees with itself in places (`Comparator` uses
`Inverted` where the integrators use `Inverting`).

## Index

| CAM | in | out | options | params |
| --- | --- | --- | --- | --- |

| `ADC-SAR` | In | Out | 1 | 0 |
| `Comparator` | In | Out | 5 | 0 |
| `DelayLine` | In | Out | 2 | 1 |
| `DeltaSigmaMod` | In | Out | 1 | 0 |
| `Differentiator` | In | Out | 2 | 1 |
| `Divider` | Y, X | Out | 1 | 1 |
| `FilterBilinear` | In | Out | 4 | 2 |
| `FilterBiquad` | In | Out | 4 | 3 |
| `FilterDCBlockLP` | In | Out | 4 | 3 |
| `FilterLowFreqBilinear` | SumNode, In | Out | 3 | 3 |
| `FilterVoltageControlled` | In | Out | 3 | 1 |
| `GainHalf` | In | Out | 2 | 1 |
| `GainHold` | In | Out | 1 | 1 |
| `GainInv` | In | Out | 0 | 1 |
| `GainLimiter` | In | Out | 0 | 2 |
| `GainPolarity` | In, Invert | Out | 4 | 1 |
| `GainSwitch` | Input2, Input1, Select | Out | 4 | 2 |
| `GainVoltageControlled` | In | Out | 4 | 1 |
| `Hold` | In | Out | 1 | 0 |
| `HoldVoltageControlled` | In, Sample | Out | 4 | 0 |
| `Integrator` | In | Out | 3 | 1 |
| `IntegratorHold` | In, Integrate | Out | 4 | 1 |
| `Multiplier` | Y, X | Out | 1 | 1 |
| `MultiplierFilterLowFreq` | SumNode, Y, X | Out | 2 | 3 |
| `OscillatorSawSqr` | Sawtooth |  | 2 | 2 |
| `OscillatorSine` |  | Out | 0 | 2 |
| `OscillatorTriSqr` | Square |  | 2 | 4 |
| `PeakDetect` | In | Out | 4 | 2 |
| `PeakDetect2` | In | Out | 4 | 1 |
| `PeakDetectExt` | SumNode, In | Out | 3 | 3 |
| `PeriodicWave` |  | Out | 4 | 1 |
| `RectifierFilter` | In | Out | 2 | 2 |
| `RectifierHalf` | In | Out | 3 | 1 |
| `RectifierHold` | In | Out | 2 | 1 |
| `RM2FilterBiquadSwitch` | In | Out | 1 | 3 |
| `SquareRoot` | In | Out | 0 | 0 |
| `SumBiquad` | Input2, Input1 | Out | 3 | 4 |
| `SumDiff` | Input2, Input1 | Out | 5 | 2 |
| `SumFilter` | Input2, Input1 | Out | 4 | 3 |
| `SumIntegrator` | Input2, Input1 | Out | 5 | 2 |
| `SumInv` | Input2, Input1 | Out | 1 | 2 |
| `TransferFunction` | In | Out | 1 | 0 |
| `Transimpedance` | In | Out | 1 | 1 |
| `Voltage` |  | Out | 1 | 0 |
| `xDeltaSigmaMod` | In | Out | 3 | 0 |
| `xFilterBiquadLow` | In | Out | 3 | 3 |
| `xOscillatorSineLow` |  | Out | 0 | 2 |
| `xVCO` | In |  | 0 | 2 |
| `ZeroCross` | In | Out | 4 | 0 |

---

## Every CAM, in full

_Each entry was produced by clearing the chip, adding that one CAM and reading it back._

## `AnadigmApex\ADC-SAR`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| isp | Phase 1 | Phase 1 / Phase 2 |

## `AnadigmApex\Comparator`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| inputs | Signal Ground | Signal Ground / Dual Input / Variable Reference |
| isp | Phase 1 | Phase 1 / Phase 2 |
| pol | Non-inverted | Non-inverted / Inverted |
| hyst | 0 mV | 0 mV / 10 mV |
| synch | None | None / Phase 1 / Phase 2 |

## `AnadigmApex\DelayLine`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| isp | Phase 1 | Phase 1 / Phase 2 |
| hold | Off | Off / On |

| parameter | default | realized |
| --- | --- | --- |
| Delay | 50 | 50 |

## `AnadigmApex\DeltaSigmaMod`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| isp | Phase 1 | Phase 1 / Phase 2 |

## `AnadigmApex\Differentiator`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| hold | On | On / Off |
| isp | Phase 1 | Phase 1 / Phase 2 |

| parameter | default | realized |
| --- | --- | --- |
| K | 0.25 | 0.25 |

## `AnadigmApex\Divider`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Y, X |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| hold | Off | Off / Input X |

| parameter | default | realized |
| --- | --- | --- |
| D | 1 | 1 |

## `AnadigmApex\FilterBilinear`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| filt | Low Pass | Low Pass / High Pass / All Pass / Pole and Zero |
| isp | Phase 1 | Phase 1 / Phase 2 |
| pol | Inverting | Inverting / Non-inverting |
| xlow | Minimum Resources | Minimum Resources / Low Corner Frequency |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 40 | 40 |
| G | 1 | 1 |

## `AnadigmApex\FilterBiquad`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| filt | Low Pass | Low Pass / High Pass / Band Pass / Band Stop / Pole and Zero |
| topo | Automatic | Automatic / Type I / Type II |
| isp | Phase 1 | Phase 1 / Phase 2 |
| pol | Inverting | Inverting / Non-inverting |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 40 | 40 |
| G | 1 | 1 |
| Q | 0.707 | 0.707 |

## `AnadigmApex\FilterDCBlockLP`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| capOrF | Corner Frequency | Corner Frequency / External Cap Value |
| pol | Non-inverting | Non-inverting / Inverting |
| isp | Phase 1 | Phase 1 / Phase 2 |
| lpOpt | Off | Off / On |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 0.8 | 0.8 |
| G | 1 | 1 |
| extC | 11.6 | 11.6 |

## `AnadigmApex\FilterLowFreqBilinear`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | SumNode, In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| capOrF | Corner Frequency | Corner Frequency / External Cap Value |
| pol | Non-inverting | Non-inverting / Inverting |
| isp | Phase 1 | Phase 1 / Phase 2 |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 0.1 | 0.1 |
| G | 1 | 1 |
| extC | 3.97 | 3.97 |

## `AnadigmApex\FilterVoltageControlled`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |
| other | Ctrl(Type=0) |

| option | selected | choices (exact text) |
| --- | --- | --- |
| filt | Low Pass | Low Pass / High Pass / All Pass |
| order | 1st | 1st / 2nd (Linkwitz-Riley) |
| isp | Phase 1 | Phase 1 / Phase 2 |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 80 | 83.2 |

## `AnadigmApex\GainHalf`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| pol | Non-inverting | Non-inverting / Inverting |
| isp | Phase 1 | Phase 1 / Phase 2 |

| parameter | default | realized |
| --- | --- | --- |
| G | 1 | 1 |

## `AnadigmApex\GainHold`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| isp | Phase 1 | Phase 1 / Phase 2 |

| parameter | default | realized |
| --- | --- | --- |
| G | 1 | 1 |

## `AnadigmApex\GainInv`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| parameter | default | realized |
| --- | --- | --- |
| G | 1 | 1 |

## `AnadigmApex\GainLimiter`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| parameter | default | realized |
| --- | --- | --- |
| G | 1 | 1 |
| VL | 1 | 1 |

## `AnadigmApex\GainPolarity`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In, Invert |
| out | Out |
| other | Control(Type=0) |

| option | selected | choices (exact text) |
| --- | --- | --- |
| ctrl | Signal Ground | Signal Ground / Dual Input / Variable Reference |
| inv | Control High | Control High / Control Low |
| outp | Phase 1 | Phase 1 / Phase 2 |
| type | Half Cycle | Half Cycle / Low Pass Bilinear |

| parameter | default | realized |
| --- | --- | --- |
| G | 1 | 1 |

## `AnadigmApex\GainSwitch`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Input2, Input1, Select |
| out | Out |
| other | Control(Type=0) |

| option | selected | choices (exact text) |
| --- | --- | --- |
| ctrl | Signal Ground | Signal Ground / Dual Input / Variable Reference |
| inv | Control High | Control High / Control Low |
| outp | Phase 1 | Phase 1 / Phase 2 |
| type | Half Cycle | Half Cycle / Low Pass Bilinear |

| parameter | default | realized |
| --- | --- | --- |
| G1 | 1 | 1 |
| G2 | 1 | 1 |

## `AnadigmApex\GainVoltageControlled`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |
| other | Control(Type=0) |

| option | selected | choices (exact text) |
| --- | --- | --- |
| pol | Non-inverting | Non-inverting / Inverting |
| hold | Off | Off / On |
| setcap | Manually | Manually / Automatically (slow) |
| stage | Single | Single / Cascaded |

| parameter | default | realized |
| --- | --- | --- |
| capval | 20 | 20 |

## `AnadigmApex\Hold`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| isp | Phase 1 | Phase 1 / Phase 2 |

## `AnadigmApex\HoldVoltageControlled`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In, Sample |
| out | Out |
| other | Control(Type=0) |

| option | selected | choices (exact text) |
| --- | --- | --- |
| mode | Sample/Hold | Sample/Hold / Pause/Run |
| ctrl | Signal Ground | Signal Ground / Dual Input / Variable Reference |
| inv | Control High | Control High / Control Low |
| isp | Phase 1 | Phase 1 / Phase 2 |

## `AnadigmApex\Integrator`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| pol | Non-inverting | Non-inverting / Inverting |
| isp | Phase 1 | Phase 1 / Phase 2 |
| ctrl | No Reset | No Reset / Signal Ground / Dual Input / Variable Reference |

| parameter | default | realized |
| --- | --- | --- |
| K | 4 | 4 |

## `AnadigmApex\IntegratorHold`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In, Integrate |
| out | Out |
| other | Control(Type=0) |

| option | selected | choices (exact text) |
| --- | --- | --- |
| pol | Non-inverting | Non-inverting / Inverting |
| isp | Phase 1 | Phase 1 / Phase 2 |
| ctrl | Signal Ground | Signal Ground / Dual Input / Variable Reference |
| res | Control High | Control High / Control Low |

| parameter | default | realized |
| --- | --- | --- |
| K | 4 | 4 |

## `AnadigmApex\Multiplier`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Y, X |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| hold | Off | Off / Input X |

| parameter | default | realized |
| --- | --- | --- |
| M | 1 | 1 |

## `AnadigmApex\MultiplierFilterLowFreq`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | SumNode, Y, X |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| capOrF | Corner Frequency | Corner Frequency / External Cap Value |
| hold | Off | Off / Input X |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 0.1 | 0.1 |
| M | 1 | 1 |
| extC | 16.9 | 16.9 |

## `AnadigmApex\OscillatorSawSqr`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Sawtooth |
| out | - |
| other | Pulse(Type=1) |

| option | selected | choices (exact text) |
| --- | --- | --- |
| sqr | Off | Off / On |
| pol | Rising | Rising / Falling |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 40 | 40 |
| peak | 2 | 2 |

## `AnadigmApex\OscillatorSine`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | - |
| out | Out |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 80 | 80 |
| A | 2.6 | 2.59 |

## `AnadigmApex\OscillatorTriSqr`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Square |
| out | - |
| other | Digital(Type=1), Triangle(Type=1) |

| option | selected | choices (exact text) |
| --- | --- | --- |
| pol | Triangle Rising | Triangle Rising / Triangle Falling |
| wave | Triangle Wave | Triangle Wave / Square Wave |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 40 | 40 |
| top | 2 | 2.02 |
| bottom | -2 | -2.02 |
| Duty | 50 | 50 |

## `AnadigmApex\PeakDetect`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| decay | Linear | Linear / Exponential |
| pol | Positive Peak | Positive Peak / Negative Peak |
| isp | Phase 1 | Phase 1 / Phase 2 |
| ctrl | No Reset | No Reset / Signal Ground / Dual Input / Variable Reference |

| parameter | default | realized |
| --- | --- | --- |
| Rp | 100 | 100 |
| Rn | 5 | 5 |

## `AnadigmApex\PeakDetect2`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| pol | Positive Peak | Positive Peak / Negative Peak |
| decaystop | Signal Ground | Signal Ground / Reference Voltage |
| isp | Phase 1 | Phase 1 / Phase 2 |
| gaindelay | One Phase (Min.Resources) | One Phase (Min.Resources) / None (Rapidly_Varying_Input) |

| parameter | default | realized |
| --- | --- | --- |
| Tau | 6.5 | 6.5 |

## `AnadigmApex\PeakDetectExt`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | SumNode, In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| decay | Linear | Linear / Exponential |
| pol | Positive Peak | Positive Peak / Negative Peak |
| isp | Phase 1 | Phase 1 / Phase 2 |

| parameter | default | realized |
| --- | --- | --- |
| extC | 5 | 0 |
| Rp | 20 | 20 |
| Rn | 1 | 1.01 |

## `AnadigmApex\PeriodicWave`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | - |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| outp | Phase 1 | Phase 1 / Phase 2 |
| hold | Off | Off / On |
| dual | Off | Off / On |
| rst | Off | Off / On |

| parameter | default | realized |
| --- | --- | --- |
| ResetCount | 255 | 255 |

## `AnadigmApex\RectifierFilter`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| rect | Full Wave | Full Wave / Positive Half Wave / Negative Half Wave |
| pol | Non-inverting | Non-inverting / Inverting |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 40 | 40 |
| G | 1 | 1 |

## `AnadigmApex\RectifierHalf`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| rect | Full Wave | Full Wave / Positive Half Wave / Negative Half Wave |
| pol | Non-inverting | Non-inverting / Inverting |
| outp | Phase 1 | Phase 1 / Phase 2 |

| parameter | default | realized |
| --- | --- | --- |
| G | 1 | 1 |

## `AnadigmApex\RectifierHold`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| rect | Positive Half Wave | Positive Half Wave / Negative Half Wave |
| isp | Phase 1 | Phase 1 / Phase 2 |

| parameter | default | realized |
| --- | --- | --- |
| G | 1 | 1 |

## `AnadigmApex\RM2FilterBiquadSwitch`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| CAB | Bottom (CABs00,10) | Bottom (CABs00,10) / Top (CABs01,11) |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 40 | 40 |
| G | 1 | 1 |
| Q | 0.707 | 0.707 |

## `AnadigmApex\SquareRoot`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

## `AnadigmApex\SumBiquad`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Input2, Input1 |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| filt1 | Low Pass | Low Pass / High Pass / Band Pass |
| filt2 | Low Pass | Low Pass |
| pol2 | Non-inverting | Non-inverting / Inverting |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 40 | 40 |
| G | 1 | 1 |
| G2 | 1 | 1 |
| Q | 0.707 | 0.707 |

## `AnadigmApex\SumDiff`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Input2, Input1 |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| outp | Phase 1 | Phase 1 / Phase 2 |
| in1 | Non-inverting | Non-inverting / Inverting |
| in2 | Non-inverting | Non-inverting / Inverting |
| in3 | Off | Off / Non-inverting / Inverting |
| in4 | Off | Off / Non-inverting / Inverting |

| parameter | default | realized |
| --- | --- | --- |
| G1 | 1 | 1 |
| G2 | 1 | 1 |

## `AnadigmApex\SumFilter`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Input2, Input1 |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| outp | Phase 1 | Phase 1 / Phase 2 |
| in1 | Non-inverting | Non-inverting / Inverting |
| in2 | Non-inverting | Non-inverting / Inverting |
| in3 | Off | Off / Non-inverting / Inverting |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 40 | 40 |
| G1 | 1 | 1 |
| G2 | 1 | 1 |

## `AnadigmApex\SumIntegrator`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Input2, Input1 |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| outp | Phase 1 | Phase 1 / Phase 2 |
| in1 | Non-inverting | Non-inverting / Inverting |
| in2 | Non-inverting | Non-inverting / Inverting |
| in3 | Off | Off / Non-inverting / Inverting |
| ctrl | No Reset | No Reset / Signal Ground / Dual Input / Variable Reference |

| parameter | default | realized |
| --- | --- | --- |
| K1 | 4 | 4 |
| K2 | 4 | 4 |

## `AnadigmApex\SumInv`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | Input2, Input1 |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| in3 | Off | Off / On |

| parameter | default | realized |
| --- | --- | --- |
| G1 | 1 | 1 |
| G2 | 1 | 1 |

## `AnadigmApex\TransferFunction`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| hold | Off | Off / On |

## `AnadigmApex\Transimpedance`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| outp | Phase 1 | Phase 1 / Phase 2 |

| parameter | default | realized |
| --- | --- | --- |
| z | 0.015 | 0.015 |

## `AnadigmApex\Voltage`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | - |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| pol | Positive (+2V) | Positive (+2V) / Negative (-2V) |

## `AnadigmApex\xDeltaSigmaMod`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| pol | Non-inverting | Non-inverting / Inverting |
| isp | Phase 1 | Phase 1 / Phase 2 |
| extref | Off | Off / On |

## `AnadigmApex\xFilterBiquadLow`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| filt | Low Pass | Low Pass / High Pass / Band Pass / Band Stop |
| isp | Phase 1 | Phase 1 / Phase 2 |
| pol | Inverting | Inverting / Non-inverting |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 40 | 40 |
| G | 1 | 1 |
| Q | 0.707 | 0.707 |

## `AnadigmApex\xOscillatorSineLow`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | - |
| out | Out |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 80 | 80 |
| A | 3.6 | 3.6 |

## `AnadigmApex\xVCO`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | - |
| other | A2out(Type=1), COMPout(Type=1) |

| parameter | default | realized |
| --- | --- | --- |
| Fo | 20 | 20 |
| dF | 5 | 5 |

## `AnadigmApex\ZeroCross`

_occupies 1 CAM slot(s)_

| | contacts |
| --- | --- |
| in | In |
| out | Out |

| option | selected | choices (exact text) |
| --- | --- | --- |
| inputs | Signal Ground | Signal Ground / Dual Input / Variable Reference |
| isp | Phase 1 | Phase 1 / Phase 2 |
| pol | Non-inverted | Non-inverted / Inverted |
| hyst | 0 mV | 0 mV / 10 mV |

---

probed 49 types: 49 added, 0 rejected

## Notes earned the hard way

These are behaviours the dump above cannot show, all verified on AN231E04.

**Limits**
- A chip holds **8 CAMs** (4 CABs x 2). The 9th `Cams.Add` throws
  `Not enough resources in chip FPAA1 ...`.
- Usable signal swing is about **+/-1.4 V** around mid-rail, single 3.3 V supply.
  The AD2 simulator happily models +/-3 V, so a design that clips in hardware can
  look fine in simulation.

**`SumIntegrator`** - the workhorse
- `in1` and `in2` are **mandatory**; only `in3` may be `Off`. Setting `in2` to
  `Off` yields `OPTFAIL`. To leave an input unused, tie it to a 0 V source.
- `K1`, `K2`, `K3` are **independent per-pin gains**, so a product term needs no
  extra gain CAM: set `K3 = K*S` and feed the multiplier straight in.
- Output is inverted (`-sum`), which is why real circuits end up with an even
  number of integrators per loop.

**`Multiplier`**
- Output is `X*Y/2` (that factor of two is easy to miss when budgeting headroom).
- `hold` accepts only `Off` / `Input X`. It does **not** accept `On` -
  `TransferFunction.hold` is the one that does.
- A multiplier does **not** break a zero-delay loop.

**Zero-delay loops**
- The checker is structural: integrators do not count, and a loop through an
  **even** number of integrators is rejected while an **odd** number is accepted.
- `AnadigmApex\Hold` is the only CAM that breaks a loop. `GainHold` does not,
  and neither does the multiplier's `hold` option. Verified by elimination.

**Half-cycle CAMs lose gain**
Measured on real waveforms: a half-cycle product branch realises about `0.86x` of
its nominal gain and `GainHold` about `0.65x`. Compensate in `K` rather than
trusting the nominal values. `Comparator` spells polarity `Non-inverted /
Inverted` while the integrators spell it `Non-inverting / Inverting` - a copy
-paste between them silently does nothing.

**Inside-chip signal sources**
`OscillatorSine`, `OscillatorTriSqr`, `OscillatorSawSqr`, `PeriodicWave` and
`xVCO` mean a self-contained oscillator needs no external generator; `DelayLine`
and `Voltage` cover delay and DC bias.

**Filtering and envelope building blocks**
`FilterBiquad`, `SumBiquad`, `FilterBilinear`, `FilterLowFreqBilinear`,
`FilterDCBlockLP`, `FilterVoltageControlled`; envelope work has `RectifierHalf`,
`RectifierFilter`, `RectifierHold`, `PeakDetect`, `PeakDetect2`, `PeakDetectExt`.
`SquareRoot`, `Divider`, `Transimpedance`, `Comparator`, `ZeroCross`, `ADC-SAR`
and `DeltaSigmaMod` round out the non-linear and mixed-signal side.

---

_Generated 2026-11-24 by `scripts/catalog_dump.ps1`. Re-run it before trusting this file on a different AD2 build._
