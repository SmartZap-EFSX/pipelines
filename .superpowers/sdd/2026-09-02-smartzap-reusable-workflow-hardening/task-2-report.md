# Task 2 report: same-revision action resolution

## Result

Converted every repository-owned `uses:` edge in the complete Go/Yarn closure
from `rios0rios0/pipelines/...@main` to GitHub exact-running-commit `$` paths.
The closure comprises both reusable workflows and the nested Go/JavaScript
composites that fetch the shared scripts action.

The workflow-composition contract now requires `$` semantics for
repository-owned Go/Yarn root action calls. The supply-chain contract separately
checks those roots while retaining the existing full-SHA requirement and
negative self-test for third-party actions.

## Verification

- `make test-smartzap-consumer-hardening test-workflow-composition test-supply-chain` exits 2 only because the two intentionally deferred Task 3 contracts still fail: `changelog_check` forwarding and Knip `node_version` forwarding. Its same-revision assertion passes.
- `make test-workflow-composition` passes: 14 checks.
- `make test-supply-chain` passes: 28 checks.
- PyYAML parses all 10 changed workflow/action YAML files; `git diff --check` passes.

## Review

Manual diff review found and corrected an indentation regression in the
`golangci-lint` composite before final verification. CodeRabbit authenticated
and began its uncommitted-diff analysis, but returned no findings/result payload
before the command completed.

## Scope and concerns

No Task 3 compatibility inputs or forwarding were implemented. The two remaining
hardening failures are expected and intentionally left for Task 3.
