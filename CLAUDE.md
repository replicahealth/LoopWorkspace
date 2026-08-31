# LoopWorkspace

Superproject for the Loop app. Application code lives in the `Loop/`
submodule; the workspace repo carries the Xcode workspace, the shared scheme,
and the submodule pointers.

## TwinScaleNet model versioning

The TwinScaleNet dosing model has a version, and it is how a dose in a
patient's history is tied back to the code that produced it. Treat it as a
record key, not a label.

**Source of truth:** `Loop/LoopCore/UnifiedDosingStrategy.swift`, in
`enum TwinScaleNetVersion`:

- `baseModel` — the trained checkpoint, e.g. `trainsplit_s2`
- `version` — an integer covering the checkpoint *and* every piece of dosing
  logic downstream of it

Both flow into one string, `qualifiedName`, which is simultaneously the
attribution stored on every enacted dose (`AutomaticDoseRecommendation
.policyIdentifier`), the strategy name shown on the settings screen, and the
`model_base` / `model_version` / `model_id` keys in dose metadata. There is
one definition; do not add a second.

### When to bump

Bump `version` in the **same commit** as any change that could make the app
deliver a different dose for identical inputs:

- the CoreML model or its exported weights
- the observation/feature builder, or feature normalisation
- the TDD anchor
- the GAIN_FAST wrapper: bounds, learning rate, deadband, target, or how the
  slider and integrator interact
- the shield, the IOB headroom backstop, the hard suspend, or dose rounding
- the baseline dose formula, or the action→factor mapping

Do **not** bump for changes that cannot alter a dose: UI copy and layout,
logging and diagnostics, comments, tests, refactors that preserve behaviour.
If you are unsure whether a change is dose-affecting, bump — a spurious
version costs a README row, a missing one silently merges two behaviours
under one identifier and makes the affected doses unattributable.

Reset `version` to 1 when `baseModel` changes; the pair identifies a build.

### Every bump needs a README row

`README.md` in this repo has a **TwinScaleNet Model Versions** table. Adding
the row is part of the bump, not follow-up work. Record what changed and why,
in terms of dosing behaviour rather than code structure — the table is read
later by someone asking why a dose from three months ago looks the way it
does.

Because the constant lives in the `Loop` submodule and the table lives here,
a bump usually spans two commits in two repos. Reference the Loop commit or
PR in the README row so they can be lined up.

## Conventions

- Never commit the Xcode-regenerated `Package.resolved` files; they churn on
  pin and whitespace with no authored change.
- The `LoopWorkspace` scheme must build every `.loopplugin` target. An install
  whose plugin set does not cover the paired devices drops those pairings on
  launch — on the pump side, a wasted pod.
