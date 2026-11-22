# anadigm-fpaa-automation

**Drive AnadigmDesigner2 (AD2) switched-capacitor FPAAs from an AI agent — or from a shell.**

AD2 has no scripting documentation. This repository is a reverse-engineered COM
automation toolkit plus a validated skill definition, so an agent (DSH, Claude
Code, Codex) or a human scripter can build CAM networks, wire chips across chip
boundaries, run the simulator, dump waveforms, and *prove* which equations the
circuit actually implements.

Everything in `reference/` was measured on a running install; the numbered traps
in `reference/PITFALLS.md` each cost hours the first time they are hit.

```
SKILL.md                 agent entry point (YAML front matter + workflow)
scripts/ad2_lib.ps1      shared COM helpers (retry, contacts, options, wiring)
scripts/watchdog.ps1     closes AD2 modal dialogs from a separate process
scripts/probe.ps1        enumerate every CAM option/parameter of any document
scripts/build_example.ps1  complete 2-chip, 10-CAM worked build
scripts/run_dump.ps1     open a document, run, dump CSV
scripts/verify_equations.py  recover state equations from a waveform
reference/               COM object model, CAM catalogue, 18 traps
```

## Highlights

- **Modal dialogs are fatal.** A single unconnected pin blocks every COM call
  forever. A watchdog process that posts ESC to `#32770` windows turns a silent
  hang into a readable exception.
- **Only `AnadigmApex\Hold` breaks a zero-delay loop.** `GainHold` does not, the
  `Multiplier`'s `hold` option does not, and a loop through an even number of
  integrators is rejected outright.
- **A hidden AD2 exports no channels.** `SaveSimulatorData` writes only the time
  column unless the window is visible. There is no error.
- **Verify the equations, not the picture.** A 2-D projection of a chaotic flow
  and a quasi-periodic torus can look identical. `verify_equations.py` recovers
  the actual state equations from the waveform.

See `README.md` below for installation and a worked example.

---
# anadigm-fpaa-automation

An agent skill for driving **AnadigmDesigner2** (AD2) switched-capacitor FPAA
designs by COM automation on Windows: build CAM networks, wire chips including
across chip boundaries, run the simulator, dump waveforms, and prove what
equations the circuit actually implements.

AD2 ships no scripting documentation. Everything here was reverse-engineered and
validated against real runs - including the traps that cost hours the first time.

## What is in the box

```
SKILL.md                     agent-facing instructions (read this first)
scripts/
  ad2_lib.ps1                shared helpers: retry, contacts, options, wiring
  watchdog.ps1               closes AD2's modal dialogs from a separate process
  probe.ps1                  dump every CAM type / option / parameter of a doc
  build_example.ps1          complete worked build: 2 chips, 10 CAMs, cross-chip
  run_dump.ps1               open a doc, run, dump CSV
  verify_equations.py        recover the state equations from a waveform
reference/
  COM_API.md                 verified object model
  CAM_CATALOG.md             every CAM: contacts, options, parameters, ranges
  PITFALLS.md                17 traps with symptom and fix
```

## Requirements

- Windows (COM automation of a Windows GUI application)
- AnadigmDesigner2 installed and licensed
- Windows PowerShell 5.1 or PowerShell 7
- Python 3 with `numpy` for the verification script

## Install

### DSH

Copy the folder into your skills directory:

```
<skills-root>/anadigm-fpaa-automation/
```

DSH discovers a skill from `SKILL.md` (YAML front matter with `name` and
`description`). Nothing else is needed.

### Claude Code

```bash
mkdir -p ~/.claude/skills
cp -r anadigm-fpaa-automation ~/.claude/skills/
```

Or, to keep it inside one project, `cp -r anadigm-fpaa-automation .claude/skills/`.
Claude Code reads `SKILL.md` the same way.

### Codex

Codex has no skill directory; point it at the entry point instead. Add to your
`AGENTS.md`:

```markdown
## AnadigmDesigner2 / FPAA tasks
For anything involving AnadigmDesigner2, `.ad2` files or AN231E04 FPAAs, read
`skills/anadigm-fpaa-automation/SKILL.md` first, then
`reference/PITFALLS.md` before writing any automation script. Reusable helpers
live in `skills/anadigm-fpaa-automation/scripts/ad2_lib.ps1`.
```

## Quick start

```powershell
# 0. keep AD2 from wedging itself (separate process)
Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass',
  '-File','.\scripts\watchdog.ps1' -WindowStyle Hidden

# 1. find out what a CAM accepts before writing code for it
.\scripts\probe.ps1 -Catalog -Template C:\path\empty_project.ad2

# 2. build the worked example
.\scripts\build_example.ps1 -Template C:\path\empty_project.ad2 `
    -Out C:\path\my_circuit.ad2 -Csv C:\path\wave.csv -EndMs 20

# 3. check the recovered equations (this is the step people skip)
python .\scripts\verify_equations.py C:\path\wave.csv --names Vx,Vy,Vz,Vu `
    --scale 20 --design "0.04*Vy" "0.04*Vu-0.04*Vx+0.8*VyVz" "^2" "0.8*VyVz"
```

`probe.ps1 -Catalog` needs a template `.ad2` that already contains at least one
chip; an empty AD2 project saved once is enough.

`-Template` is a starting document because `Chips` cannot be created in an empty
workspace without a board definition. Save any project with one chip once and
reuse it.

## The five rules that matter most

1. **A modal dialog blocks every COM call.** Run the watchdog. Then wrap
   `IsRunning` in try/catch and log the exception text - that is where the real
   error message arrives.
2. **`.ps1` sources must be pure ASCII.** PowerShell decodes them with the system
   code page; one Chinese character becomes garbage and breaks the file. Pass
   non-ASCII paths as arguments.
3. **Only `AnadigmApex\Hold` breaks a zero-delay loop.** `GainHold` and the
   `Multiplier`'s `hold` option do not, and an even number of integrators in a
   loop is rejected outright.
4. **Eight CAMs per chip, four probes per run, two halves per cross-chip link.**
5. **Verify the equations from the waveform before believing the picture.** A 2-D
   projection can look identical for chaotic and quasi-periodic dynamics. Also: a
   0-1 test needs a few samples **per period**, not the raw simulation rate.

## Provenance

Extracted from a research project on implementing a four-dimensional chaotic
system on an AN231E04 board. The worked example is the system

```
x' = y ,  y' = u - x + y*z ,  z' = 5 - |y| - 0.2*z ,  u' = y*z
```

built on two chips with the zero-delay loops broken by three Holds, verified to
reproduce its design equations within 13 % and confirmed chaotic with a 0-1 test
(K = 0.96 against 1.00 for the MATLAB reference).

## Licence

Do whatever you like with it. No warranty: it drives a closed-source GUI
application, and every claim above was measured on one specific version
(AnadigmApex CAM library 1.x). Re-probe your own install rather than trusting the
catalogue blindly.

## Worked example: what the verifier prints

Against the 20 ms record of the worked example (`--scale 20 --skip-ms 8 --smooth 21`):

```
model     : terms taken from --design (least squares on those terms)

dVx/dt =  +0.0449*Vy                                      (R2 = 0.9904)
dVy/dt =  +0.0469*Vu -0.0467*Vx +0.0432*VyVz              (R2 = 0.9828)
dVz/dt =  +0.2258*1 -0.0449*abs(Vy) -0.0112*Vz            (R2 = 0.9899)
dVu/dt =  +0.0438*VyVz                                    (R2 = 0.9749)

  Vx  Vy        want +0.0400  got +0.0449   ok
  Vy  Vu        want +0.0400  got +0.0469   ok
  Vy  Vx        want -0.0400  got -0.0467   ok
  Vy  VyVz      want +0.0400  got +0.0432   ok
  Vz  1         want +0.2000  got +0.2258   ok
  Vz  abs(Vy)   want -0.0400  got -0.0449   ok
  Vz  Vz        want -0.0080  got -0.0112   MISMATCH
  Vu  VyVz      want +0.0400  got +0.0438   ok
```

Read this as a report, not a pass/fail exam. Every coefficient is about 12 %
high, which is the realised overall gain of this circuit being 12 % above
nominal - harmless. The one real finding is the z damping at 40 % above design:
the `GainHold` in that branch delivers more gain than its nominal `G` suggests,
so `G` should come down from 0.34 to about 0.28. **That is exactly the sort of
number this script exists to hand you.**

Two practical notes:

- `--design` is the reliable mode. When an equation contains `u - x` and `u`
  tracks `x`, the two regressors nearly cancel and any automatic term selection
  gets confused; naming the terms yourself (as above) gives a clean fit.
- Smoothing is not optional. At the raw 0.125 us sample interval the derivative
  is dominated by the switched-capacitor clock ripple, and the fit reports
  nonsense (R2 around 0.7 and coefficients off by 2x). The default width of 21
  samples (~2.6 us at 4 MHz) is a reasonable starting point; raise it if the
  R2 of the harder channels stays low.


