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

- `version` — two-component version, e.g. `2.0`, covering the trained checkpoint
  *and* every piece of dosing logic downstream of it
- `baseModel` — which checkpoint that version was built on, e.g.
  `trainsplit_s2`. Recorded, not displayed.

Two names derive from it, and there is one definition of each:

- `logName` → `TwinScaleNet2.0`. The attribution stored on every enacted
  dose (`AutomaticDoseRecommendation.policyIdentifier`), the `model_id` dose
  metadata key, and the identity in the rationale string.
- `menuName` → `TwinScaleNet2.0 (experimental)`. The strategy name on the
  settings screen.

`baseModel` does not appear in either name — it reaches the record through the
`model_base` metadata key and the README table. Do not add a second definition
of any of this.

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

Which component to bump — the version has two, `major.minor`:

- **major** (`3.0`) — a new base checkpoint. Also update `baseModel`.
- **minor** (`2.1`) — anything else that changes what gets delivered on the
  same checkpoint: the TDD anchor, the feature builder, a safety backstop, a
  constant or tuning change.

There is no patch component. A dose-affecting change is a dose-affecting
change; splitting them into "structural" and "tuning" invited an argument at
every bump about which one a change was, and the answer never altered what
anyone needed to know from the version.

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
