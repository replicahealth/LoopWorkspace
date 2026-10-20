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

Two submodules back the Tandem t:slim X2 pump plugin: `TandemKit` (public,
faBolus-app) and `TandemLoopKit` (private, replicahealth). They are wired in
exactly like every other device kit: a submodule entry, a project reference in
the workspace, and a `LoopWorkspace` scheme entry for the `.loopplugin`. As
with the private `LibreLoop` submodule, the recursive clone needs read access
to the private repo; ask for it if the clone stops there. Loop itself is
unchanged by the plugin and discovers pump drivers from the plugins in the
bundle at launch, so builds paired to an Omnipod or any other pump dose
exactly as before, and the Tandem driver only runs once a t:slim X2 is paired
from the pump settings screen.

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

- **Dose attribution / logs** — `TwinScaleNet2.0.1`. This is the
  `policyIdentifier` stored on every enacted dose and surfaced in the insulin
  delivery history.
- **The app menu** — `TwinScaleNet2.0.0 (experimental)`, on the Dosing
  Strategy settings screen.
- **Dose metadata** — `model_id` (`TwinScaleNet2.0.1`), `model_version`
  (`2.0.1`) and `model_base` (the checkpoint), plus the versioned name in the
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
| `TwinScaleNet2.0.1` | `post_flat_hyb_w1024_s2` | 2026-10-20 | Seed swap on the same arm: seed 2 of the "clone + post-training, 1024" group replaces seed 1. Seed 1 had been chosen on replay validation Magni (3.88 against seed 2's 4.00), but on the simulator dose sweep (30 subjects × 3 sim seeds × 10 days, ×0.6 to ×3.0 on the model's own output) it is the worst of the three seeds and seed 2 the best: at matched TIR 77.1 % the TBR is 0.030 % for seed 2, 0.054 % for seed 0 and 0.092 % for seed 1, and at its own ×1.0 dose seed 2 reaches TIR 81.3 % / TBR 0.19 % against seed 1's 80.7 % / 0.58 % (subject-paired: TBR −0.39 pp [−0.88, −0.03], TIR +0.56 pp, not significant). Not the locked test. Checkpoint `checkpoints/lineage_width/consol_chain/post_flat_hyb_w1024_s2_best.pt` (sha256 `0cc1e909…`), renamed copy `checkpoints/twinscalenet/TwinScaleNet2.0.1.pt` with its manifest; `TwinScaleNet2.0.0.json` is marked superseded. Architecture, inputs, window layout, CoreML export (FP32 via `InsulinRL/export_twinscalenet_flat.py`, parity with the PyTorch checkpoint to 1e-7 on the probes, pinned by the tests) and everything downstream of the head are unchanged from 2.0.0. Patch rather than major: same architecture, corpus and recipe, only the training seed differs. Loop PR [#11](https://github.com/replicahealth/LoopReplicaIntegration/pull/11). |
| `TwinScaleNet2.0.0` | `post_flat_hyb_w1024_s1` | 2026-10-18 | New base checkpoint, from InsulinRL-hybrid's clone-vs-post-training width study (`experiments/aid_meta/lineage_width.py`, write-up `LINEAGE_WIDTH.html`, 2026-10-14/16): the "clone + post-training, 1024" arm, seed 1 of 3, chosen as the seed with the lowest validation Magni (3.88 at step 3,000; seeds 0 and 2 reached 4.03 and 4.00). A 14→1024→1024→1 head built from random weights by behaviour cloning (30k steps), consolidation (12k, anchor 0.5) and the twin recipe, on the `pubtrain+privext` corpus. Architecturally new for the app: besides the same 14 features the head now reads the raw 3×48 lag window (CGM, insulin, carbs, newest first, normalised as the features are; a missing CGM lag reads as the current glucose), so a dose depends on the shape of the last 4 h rather than only its summary statistics. Simulator (30 subjects × 3 sim seeds × 10 days, the three model seeds pooled, each arm at its own ×1.0 dose): TIR 82.17 %, TBR 0.487 %, Magni 3.891, against the step-0 trunk's 72.27 / 0.395 / 5.518; at matched TIR 76.36 % the TBR is 0.053 against the trunk's 1.183. Not the locked test. Everything downstream of the head — TDD anchor, GAIN_FAST bounds and rate, shield, IOB headroom, hard suspend, rounding — is unchanged from 1.0.0. Like `trainsplit_s2`, this checkpoint was trained against a per-patient global TDD (the corpus fits' `global_tdd`, both in cloning and in the twin rollouts), not the `w7` window the app anchors on; the 1.0.0 decision to keep the windowed anchor as the better estimate of that long-run mean stands. Unknown insulin history is still read as on-schedule delivery in both the features and the window, where the Python's trace-start pad is zero insulin. CoreML export is FP32 via `InsulinRL/export_twinscalenet_flat.py` (parity with the PyTorch checkpoint to 3e-8 on the probe inputs). Loop PR [#11](https://github.com/replicahealth/LoopReplicaIntegration/pull/11) (`c9ae8e8d`). |
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
| `twinscalenet-2.0.0-tandem-minbolus` | 2026-10-20 | `c9ae8e8d` | `TwinScaleNet2.0.0` | Current. Same Loop code as `twinscalenet-2.0.0`; TandemLoopKit `f9bc14b` carries basal debt and pays it as one bolus once it reaches a minimum micro-bolus (settings screen, default 0.3 U), because the worn X2 raised no-delivery alarms about daily under 0.05–0.15 U micro-boluses. Deferred windows are booked at the floor, so IOB is unchanged in total; delivery lags Loop's rate by up to 0.3 U ÷ the gap over the floor. Threshold recorded in `HKDevice.model`. Loop dosing recommendations unchanged. Release configuration, `LoopWorkspace` scheme, iPhone 13 Pro. |
| `twinscalenet-2.0.0` | 2026-10-19 | `c9ae8e8d` | `TwinScaleNet2.0.0` | First install of the 2.0.0 head (clone + post-training w1024 flat-hybrid, raw 3×48 window input; Loop PR #11). Workspace tree otherwise identical to `tandem-soak-4`: TandemLoopKit plugin, Release configuration, `LoopWorkspace` scheme, iPhone 13 Pro. 15 plugins in the bundle; CGM (`LibreLoopCGMManager`) and pump (`Tandem`) state verified intact after the install. |
| `twinscalenet-1.0.0-tandem-soak-4` | 2026-10-13 | `e36cca84` | `TwinScaleNet1.0.0` | A Loop bolus (phone or watch) now pre-empts a basal micro-bolus in flight instead of being refused as busy; the cut-short micro-bolus is booked at its delivered amount and the rest refunded to the next window. Loop code unchanged; no dosing change. |
| `twinscalenet-1.0.0-tandem-soak-3` | 2026-10-09 | `e36cca84` | `TwinScaleNet1.0.0` | Adds the native-rate timeline: a window closed after a disconnection is booked at the rates the pump logged. No dosing change. |
| `twinscalenet-1.0.0-tandem-soak-2` | 2026-10-08 | `e36cca84` | `TwinScaleNet1.0.0` | Same as below plus the Tandem reconnect fix: the driver re-arms Bluetooth reconnection after TandemKit's ladder gives up. No dosing change. |
| `twinscalenet-1.0.0-tandem-soak` | 2026-10-07 | `e36cca84` | `TwinScaleNet1.0.0` | Same Loop code as the gain-chart checkpoint; adds the TandemLoopKit plugin (t:slim X2, micro-bolus basal) for the saline soak. Doses identical for Omnipod; Tandem doses attributed by `HKDevice.model`. Release configuration, `LoopWorkspace` scheme, iPhone 13 Pro. |
| `twinscalenet-1.0.0-gain-chart` | 2026-09-28 | `e36cca84` | `TwinScaleNet1.0.0` | Adds the gain-history record and the "Gain k" status chart (Loop PR #10). Doses identical to `twinscalenet-1.0.0`. Release configuration, `LoopWorkspace` scheme. |
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
