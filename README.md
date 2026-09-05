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

- **Dose attribution / logs** — `TwinScaleNet2.0`. This is the
  `policyIdentifier` stored on every enacted dose and surfaced in the insulin
  delivery history.
- **The app menu** — `TwinScaleNet2.0 (experimental)`, on the Dosing
  Strategy settings screen.
- **Dose metadata** — `model_id` (`TwinScaleNet2.0`), `model_version`
  (`2.0`) and `model_base` (the checkpoint), plus the versioned name in the
  human-readable rationale string.

`version` covers the trained checkpoint *and* everything downstream that
changes what is delivered: features, TDD anchor, gain wrapper, shield, safety
backstops, dose rounding. **Two builds differing in version do not dose
identically.**

The checkpoint name is deliberately not part of the displayed identity, which
is kept short. It is recorded in the `model_base` metadata key and in the
Base model column below, so a version can always be traced to the checkpoint
it was built on.

Versions have two components, `major.minor`: **major** for a new base
checkpoint, **minor** for anything else that changes what gets delivered.

Note the scheme changed at 2.0. `TwinScaleNet1.0.0` below is written as it was
recorded, because that is the string stored on doses enacted under it; it is
not retroactively renamed.

Stored doses keep the identifier they were enacted under, so history spanning
a bump stays correctly attributed on both sides of it.

| Version | Base model | Date | Changes |
|---|---|---|---|
| `TwinScaleNet2.0` | `seq_hl0.3_k112h70w7_s0_full` | 2026-09-05 | **New base checkpoint: AdaptivePolicy.** The action head keeps the 14-feature shape and appends an 8-dim recurrent latent (22 inputs); a `GRUCell(5,8)` folds an hourly summary — mean BG offset, clamped hypo and hyper pressure, mean factor, mean dose/base ratio — into that latent. **GAIN_FAST is inert**: the model was trained with the gain wrapper off (`base * factor * 1.0`) because the latent carries that adaptation. The gain slider becomes an overall dose multiplier defaulting to 1.00, the on-device equivalent of the frontier sweeps' reference-dose knob. Trained on the `k112h70` objective with `tdd=w7`, matching the anchor the app computes. **Candidate, not gate-certified** — evaluated on the sequence-simulation surface, not `decide_capped`; one seed; `sensor: off`. Loop PR #8. |
| `TwinScaleNet1.0.0` | `trainsplit_s2` | 2026-08-31 | First versioned build. Adopts the `trainsplit_s2_best` trunk checkpoint (gate PASS 2026-08-13), replacing stage08d `sh_s0h10`. TDD anchor rewritten to the training-time `w7` rule — 7-day trailing shrinkage toward the schedule prior, replacing `max(rolling-24h, basalTotal/0.55)`. Gain range widened to 0.50–2.00 for both the slider and the GAIN_FAST integrator. Gain slider gains a recommendation track and marker; the Adaptive Scaling Factor toggle now gates automatic updating only, and no longer forces the enacted gain to 1. |

### Pre-versioning history

Builds before `1.0.0` carry the unversioned attribution string
`TwinScaleNet (experimental)` and cannot be told apart from the dose record
alone. Doses attributed that way came from a build somewhere in the stage08d
`sh_s0h10` era; narrowing further requires the app version or build date.

### Adding a version

Bump `TwinScaleNetVersion.version` in the same commit as the dose-affecting
change, and add a row here referencing the Loop commit or PR. See `CLAUDE.md`
for what counts as dose-affecting.
