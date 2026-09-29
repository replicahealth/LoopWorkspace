# LoopWorkspace

The Loop app can be built using GitHub workflows in the cloud from a browser on any computer or using a Mac with Xcode.

* Non-developers may prefer the GitHub workflow method, which does not require a mac.
* Developers or Loopers who want full build control may prefer the local Mac/Xcode method.

## GitHub Build Instructions

The GitHub Build Instructions are at this [link](fastlane/testflight.md) and further expanded in [LoopDocs: Browser Build](https://loopkit.github.io/loopdocs/gh-actions/gh-overview/).

## Mac/Xcode Build Instructions

The rest of this README contains information needed for Mac/Xcode build. Additonal instructions are found in [LoopDocs: Mac/Xcode Build](https://loopkit.github.io/loopdocs/build/overview/).

### Clone

This repository uses git submodules to pull in the various workspace dependencies.

To clone this repo:

```
git clone --branch=<branch> --recurse-submodules https://github.com/LoopKit/LoopWorkspace
```

Replace `<branch>` with the initial LoopWorkspace repository branch you wish to checkout.

### Open

Change to the cloned directory and open the workspace in Xcode:

```
cd LoopWorkspace
xed .
```

### Input your development team

You should be able to build to a simulator without changing anything. But if you wish to build to a real device, you'll need a developer account, and you'll need to tell Xcode about your team id, which you can find at https://developer.apple.com/.

In this fork, all targets derive their signing team from the `LOOP_DEVELOPMENT_TEAM` build setting — no team ids are hardcoded in the project files. The recommended way to set it is a machine-level override file in your home directory, which git can never clobber or accidentally commit:

```
echo 'LOOP_DEVELOPMENT_TEAM = YOURTEAMID' > ~/LoopConfigOverride.xcconfig
```

This works because the tracked `LoopConfigOverride.xcconfig` at the workspace root starts with `#include? "../../LoopConfigOverride.xcconfig"`, which resolves to `~/LoopConfigOverride.xcconfig` when the workspace is cloned two levels below your home directory (e.g. `~/projects/LoopWorkspace`). If your clone lives elsewhere, adjust that include path or set `LOOP_DEVELOPMENT_TEAM` directly in the workspace-root file (upstream's method) — just don't commit your team id.

**Note:** the app's bundle identifier is derived from the team (`com.<TEAM>.loopkit.Loop`), so changing the team id changes the app identity. iOS will treat a build with a different team as a brand-new app — existing settings and pump/CGM pairings from a previous install will not carry over.

### Build

Select the "LoopWorkspace" scheme (not the "Loop" scheme) and Build, Run, or Test. The LoopWorkspace scheme is what builds all of the CGM, pump, and service plugins — building the "Loop" scheme alone produces an app containing only the simulator drivers.

The committed scheme includes an `OPENAI_API_KEY` environment variable that is empty and disabled. If you enable it locally with a real key for debugging (Edit Scheme → Run → Environment Variables), take care not to commit that change.

## TwinScaleNet Model Versions

The experimental TwinScaleNet dosing strategy carries a version, so any dose
in a patient's history can be traced to the code that produced it.

The identity is `TwinScaleNet<version>`, defined once in
`Loop/LoopCore/UnifiedDosingStrategy.swift` (`enum TwinScaleNetVersion`). It
appears in three places, all from that one definition:

- **Dose attribution / logs** — `TwinScaleNet1.0.0`. This is the
  `policyIdentifier` stored on every enacted dose and surfaced in the insulin
  delivery history.
- **The app menu** — `TwinScaleNet1.0.0 (experimental)`, on the Dosing
  Strategy settings screen.
- **Dose metadata** — `model_id` (`TwinScaleNet1.0.0`), `model_version`
  (`1.0.0`) and `model_base` (the checkpoint), plus the versioned name in the
  human-readable rationale string.

`version` covers the trained checkpoint *and* everything downstream that
changes what is delivered: features, TDD anchor, gain wrapper, shield, safety
backstops, dose rounding. **Two builds differing in version do not dose
identically.**

The checkpoint name is deliberately not part of the displayed identity, which
is kept short. It is recorded in the `model_base` metadata key and in the
Base model column below, so a version can always be traced to the checkpoint
it was built on.

Bumping: **major** for a new base checkpoint, **minor** for a change in dosing
logic on the same checkpoint, **patch** for a constant or tuning change.

Stored doses keep the identifier they were enacted under, so history spanning
a bump stays correctly attributed on both sides of it.

| Version | Base model | Date | Changes |
|---|---|---|---|
| `TwinScaleNet1.0.0` | `trainsplit_s2` | 2026-08-31 | First versioned build. Adopts the `trainsplit_s2_best` trunk checkpoint (gate PASS 2026-08-13), replacing stage08d `sh_s0h10`. TDD anchor rewritten to the training-time `w7` rule — 7-day trailing shrinkage toward the schedule prior, replacing `max(rolling-24h, basalTotal/0.55)`. Gain range widened to 0.50–2.00 for both the slider and the GAIN_FAST integrator. On the excursion this allows: a step moves `k` by at most +0.0060 (the +1.5 error cap binds at BG 275), so an unbroken run of maximal highs needs ~92 steps — about 7.6 h at the 5-minute cadence — to travel 1.45 → 2.00. The 3× hypoglycemia weight is a slope, not a per-step ceiling: its own cap would need BG ≤ −55 and never binds, giving −0.0030 at BG 70 and −0.0066 at BG 40. The reachable extremes are therefore close to symmetric (−0.0066 against +0.0060), not 3× apart. Gain slider gains a recommendation track and marker; the Adaptive Scaling Factor toggle now gates automatic updating only, and no longer forces the enacted gain to 1. |

### Pre-versioning history

Builds before `1.0.0` carry the unversioned attribution string
`TwinScaleNet (experimental)` and cannot be told apart from the dose record
alone. Doses attributed that way came from a build somewhere in the stage08d
`sh_s0h10` era; narrowing further requires the app version or build date.

### Deployment checkpoints

Each version actually installed on a device gets an annotated tag in **both**
repos, so the exact tree can be rebuilt later. The workspace tag pins every
submodule, which is what makes the reproduction exact:

```
git checkout twinscalenet-1.0.0-gain-chart
git submodule update --init --recursive
```

| Checkpoint | Installed | Loop commit | Dosing version | Notes |
|---|---|---|---|---|
| `twinscalenet-1.0.0-gain-chart` | 2026-09-28 | `e36cca84` | `TwinScaleNet1.0.0` | Current. Adds the gain-history record and the "Gain k" status chart (Loop PR #10). Doses identical to `twinscalenet-1.0.0`. Release configuration, `LoopWorkspace` scheme. |
| `twinscalenet-1.0.0` | 2026-09-16 | `b6ed107d` | `TwinScaleNet1.0.0` | First versioned build. Staged as the rollback for the checkpoint above; a `revert/twinscalenet-1.0.0` branch points at the same commit for convenience. |

The tag is the authority, because a branch can move and a tag cannot. A
checkpoint whose dosing version matches an earlier one differs only in
non-dosing code, so doses recorded under either are directly comparable.

A checkpoint reproduces **what shipped**, not what was later learned about it.
The 1.0.0 tag still carries an incorrect `-0.018` figure in the GAIN_FAST
comment; that is deliberate. The correction lives on the working branch.

### Adding a version

Bump `TwinScaleNetVersion.version` in the same commit as the dose-affecting
change, and add a row here referencing the Loop commit or PR. See `CLAUDE.md`
for what counts as dose-affecting.
