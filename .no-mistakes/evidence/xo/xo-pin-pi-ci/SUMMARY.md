# Pi pin validation — branch `xo/xo-pin-pi-ci` (979373e)

Every row below was produced by running the real CI install step (extracted
verbatim from `.github/workflows/ci.yml` with the workflow-level `env` it
declares) into an isolated `npm` prefix, then running the two named tests
against that install. The host's global Pi install was never touched.

## Version sweep — both named tests per Pi build

| Pi version | how CI reaches it | `xo-calm-pi-extension` | `xo-pi-branch-extension` |
|---|---|---|---|
| 1.0.2 | base commit fa3d0d6, **unpinned** install resolves this | FAIL — `grep disappeared from /export calm.html HTML while calm mode was on` | FAIL — `Calm-off ToolExecutionComponent rendering differs from Pi stock` |
| 0.99.2 | newest pre-1.0 candidate | pass | FAIL — stock-parity case |
| 0.99.1 | candidate (not listed in the commit message) | pass | FAIL — stock-parity case |
| 0.99.0 | candidate | pass | FAIL — stock-parity case |
| **0.87.1** | **this change's pin** | **pass (13 cases)** | **pass (42 cases)** |

npm publishes nothing between 0.87.1 and 0.99.0, so 0.87.1 is the newest
version on which both tests pass — the commit's claim holds, and the pin is on
the pre-1.0 line rather than latest.

## Single owner

`.github/workflows/ci.yml` has exactly two Pi install sites
(`tests-portable-parallel-1`, `tests-portable-serial`). Both now interpolate
`$XO_PI_PACKAGE_VERSION`; `0.87.1` appears once in the file, at the `env`
definition. Neither job nor step re-declares the variable, so the effective
value at both sites is `0.87.1`. Running each site's script separately
installed 0.87.1 in both cases.

## Lane reality check

`bin/xo-test-run.sh --list --lane portable-serial` is the lane that carries
both named tests, and that job is one of the two install sites. Emulating that
job end to end — install step, then the tests discovering Pi through their
default `npm root -g` path with no `XO_PI_PACKAGE_DIR` override — finished
`total=2 failed=0 skipped_gate=0`.

Neither pass was vacuous: `xo-pi-branch-extension.test.sh` skips its
stock-parity case below Pi 0.84.4, and at 0.87.1 the case ran and reported
`ok - xo_branch_outcomes hides through ToolExecutionComponent while Calm-off
and HTML export stay stock`.

## Guard probe

With the `env` block absent, the install step aborts on `set -u`
(`XO_PI_PACKAGE_VERSION: unbound variable`, exit 1) and installs nothing —
it cannot silently fall back to latest. With the value edited to an empty
string it does silently install latest (1.0.2); that needs a deliberate bad
edit to the YAML, but the step does not catch it.

## Files

- `ci-install-sites-resolve-pin.txt` — both install sites resolving 0.87.1
- `ci-install-base-unpinned-resolves-latest.txt` — base commit resolving 1.0.2
- `pi-1.0.2-unpinned-named-tests-fail.txt` — the reported red, reproduced
- `pi-0.87.1-pinned-named-tests.txt`, `pi-0.87.1-branch-extension-full.txt` — green on the pin
- `pi-0.99x-candidates-still-fail.txt` — the pin boundary
- `ci-serial-lane-e2e-pinned.txt` — the serial lane end to end
- `ci-install-pin-missing-guard.txt` — guard probe
- `pin-scope-statements.txt` — the pin comment and the commit's scoping paragraphs
