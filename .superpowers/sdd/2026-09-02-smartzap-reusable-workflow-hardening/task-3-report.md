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

## Review round 1

The stale-reference selectors now parse the relevant workflow job and require
the exact action reference before inspecting its input mapping. Yarn's format
and Knip checks require their exact `$/...` actions; Go's CodeQL check requires
its exact `$/...` action plus the `go_version_file` forwarding. The JavaScript
format contract preserves npm's unchanged explicit `@main` expectation rather
than weakening it while updating Yarn's local-reference expectation.

## CodeRabbit autofix round

The same-revision policy now permits only `$/...` for repository-owned Go/Yarn
edges. The hardening, supply-chain, and workflow-composition contracts reject
remote tag, branch, SHA, and unqualified selectors as well as local `./...`
paths; fixtures prove each rejected shape. The hardening contract also asserts
the backward-compatible defaults: workflow `changelog_check: true`, composite
`changelog_check: 'true'`, and Knip `node_version: '20'`.

The plan now states this exact policy rather than describing only `@main` as
disallowed.

## Concern

The `$/...` action-reference syntax requires the Task 4 GitHub runtime canary;
local contracts verify the wiring and closure but cannot execute a reusable
workflow on GitHub.
