# SmartZap Reusable Workflow Hardening Design

## Objective

Make the forked Go and Yarn reusable workflows safe for SmartZap consumers to pin by a full commit SHA, while preserving the upstream pipeline structure and avoiding assumptions that conflict with SmartZap's socketless self-hosted runner.

## Design

The Go and Yarn workflow graphs will resolve every repository-owned composite action through GitHub's `$/path` same-revision syntax. This removes mutable `rios0rios0/pipelines@main` execution from the two consumer paths without rewriting unrelated language pipelines. A contract test will enumerate both reachable graphs and fail if a mutable repository-owned reference returns.

The basic-checks composite will accept a boolean-like `changelog_check` input. Go and Yarn expose the same workflow-call input and pass it through; its default remains enabled for backward compatibility, while SmartZap callers can disable it during initial adoption. The rebase check remains mandatory.

The JavaScript Knip composite will accept `node_version`; Yarn will pass its existing workflow input through, eliminating the hard-coded Node 20 runtime. Existing defaults remain compatible for other consumers.

## Validation

Tests must first demonstrate failures for mutable transitive references, changelog opt-out, and Node-version forwarding. After implementation, the focused tests and the repository's full `make test` suite must pass. A fork pull request then provides the GitHub Actions parser/runtime canary before any backend or frontend caller adopts its merge SHA.

## Scope boundaries

- Harden only the action graph reachable from `.github/workflows/go.yaml` and `.github/workflows/yarn.yaml`.
- Do not enable Docker-backed database jobs or container jobs on SmartZap's socketless runner.
- Do not remove changelog enforcement globally; add an explicit backward-compatible opt-out.
- Do not migrate SmartZap consumer repositories until the fork PR is merged and its exact SHA is known.
