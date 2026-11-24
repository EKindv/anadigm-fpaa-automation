# Changelog

All notable changes to this skill are recorded here. Versions follow
[SemVer](https://semver.org/): the minor number goes up when the verified CAM
inventory or the public helper functions change, the patch number for fixes.

## [1.0.0] - 2026-11-24

First public release. Verified against **AnadigmDesigner2 2.8.0.0 (AD20.exe)** on
**Windows 11**, **Windows PowerShell 5.1**, chip **AN231E04**.

### Added

- `SKILL.md` - agent entry point: five-step workflow, circuit-level rules,
  verification checklist.
- `reference/CAM_CATALOG.md` - **all 49 AnadigmApex CAMs**, probed through COM at
  runtime rather than copied from a manual: contacts, the exact option strings you
  must pass to `AD2-SetOpt`, and parameter defaults. Includes the measurement that
  all **50 `AnadigmVortex` CAMs are rejected** by AN231E04, so 49 is the complete
  usable set and not a subset.
- `reference/COM_API.md` - the object model that was actually observed.
- `reference/PITFALLS.md` - **23 traps**, each with symptom, cause and fix.
- `scripts/ad2_lib.ps1` - shared COM helpers: retry, contacts, options,
  parameters, wiring, cross-chip IO, generators, `AD2-Run` with stall detection,
  `AD2-DismissDialogs`.
- `scripts/catalog_dump.ps1` - enumerate every CAM of a library and dump it as
  Markdown (49 CAMs in about 15 s).
- `scripts/suppress_dialogs.ps1` - answers AD2's blocking modal boxes from a
  separate process, because the calling process is stuck inside the COM call.
- `scripts/verify_equations.py` - recovers the state equations a circuit actually
  implements, by smoothing, differentiating and fitting a sparse model.
- `scripts/test_stall.ps1` - regression test covering valid run, rejected netlist
  and recovery after restart.
- `scripts/build_example.ps1`, `scripts/run_dump.ps1`, `scripts/probe.ps1`,
  `scripts/watchdog.ps1` (legacy, superseded by `suppress_dialogs.ps1`).

### Fixed

The four findings that cost the most time:

- **A rejected netlist does not raise a COM error.** `IsRunning` reports `true`
  for ever and `CurrentIteration` stays at `0`, behind a modal box whose text is
  owner-drawn and therefore unreadable. `AD2-Run` now detects this in **1.5 s**
  instead of waiting out a 90 s timeout. Restarting AD2 recovers; a second
  `Start()` in the same session never does.
- **The "Not enough resources ... Do you want to keep these settings?" box blocks
  `Document.Open`** - measured at **111.89 s**. A helper process started before
  the call answers it: **Yes** loads the file as saved in **4.9 s**, **No** makes
  AD2 open `Set CAM Parameters` next and costs 31 s across four dialog rounds.
- **`Add-Type` treats a C# warning as an error and fails silently** when wrapped
  in `-ErrorAction SilentlyContinue`. One unused local variable was enough to
  make a dialog helper non-existent while every call was quietly swallowed.
- **A hidden AD2 exports only the time column.** `SaveSimulatorData` needs the
  window visible; there is no error either way.

### Known limits

- **Simulation only.** Nothing here was measured on a physical AN231E04 board.
- **No synthesiser.** The skill supplies the CAM inventory and the plumbing, not
  a compiler from equations to placements. Choosing a topology is still a human
  (or agent) design decision.
- **The catalogue is machine-specific.** `.cam` files in the installation are
  binary, so type names come from file names and everything else from COM. Re-run
  `catalog_dump.ps1` before trusting this file on a different AD2 build.
