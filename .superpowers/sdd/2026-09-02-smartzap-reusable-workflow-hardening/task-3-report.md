# Task 3 report: compatibility inputs and aggregate hardening gate

## Result

- Added `changelog_check` to the Go and Yarn reusable workflows as an optional
  boolean input defaulting to `true`, then forwarded it to `basic-checks`.
- Added the matching string composite input (default `'true'`) and gated only
  the `Check changelog entries` step. Rebase validation remains unconditional.
- Added Knip's optional `node_version` input (default `'20'`), used it for
  `actions/setup-node`, and forwarded Yarn's existing workflow input.
- Added the required changelog fragment and made
  `test-smartzap-consumer-hardening` part of aggregate `make test`.

## Test-contract alignment

Task 2 changed the Go/Yarn action graph from `@main` references to `$/...`
exact-running-commit references. Three pre-existing assertions still selected
only the former spelling, causing the new full-suite requirement to fail even
though the target action calls and forwarding already existed. Their selectors
now recognize the local immutable path:

- Knip forwarding contract uses the actual local action path.
- Go toolchain forwarding contract locates the CodeQL action independent of
  the revision spelling.
- JavaScript formatting contract locates the format action independent of the
  revision spelling.

## Verification

- `make test-smartzap-consumer-hardening` — passed: 3 checks, 0 failures.
- `make test-go-module-toolchain` — passed: 38 checks.
- `make test-javascript-pipeline` — passed: 32 checks.
- `make test` — passed and printed `All tests completed successfully!`.
- `git diff --check` — passed.

CodeRabbit 0.7.5 was authenticated and analyzed the uncommitted diff; it
returned no findings payload.

## Concern

The `$/...` action-reference syntax requires the Task 4 GitHub runtime canary;
local contracts verify the wiring and closure but cannot execute a reusable
workflow on GitHub.
