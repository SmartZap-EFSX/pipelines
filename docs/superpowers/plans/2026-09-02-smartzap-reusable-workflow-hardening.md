# SmartZap Reusable Workflow Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a fork commit whose Go and Yarn reusable workflows execute only same-revision repository-owned actions and are compatible with SmartZap's Node and changelog policies.

**Architecture:** Preserve the upstream workflows and introduce three narrow compatibility seams: same-revision `$/` action resolution, a forwarded changelog opt-out, and forwarded Node version for Knip. Shell contract tests statically traverse the relevant workflow/action files so regressions fail before a consumer executes them.

**Tech Stack:** GitHub Actions reusable workflows, composite actions, Bash contract tests, GNU Make

**Spec:** `docs/superpowers/specs/2026-09-02-smartzap-reusable-workflow-hardening-design.md`

## Global Constraints

- Consumer workflows will pin the final fork commit by its full 40-character SHA.
- The Go/Yarn reachable graphs must contain no `rios0rios0/pipelines/...@main` references.
- Existing behavior remains the default for consumers that omit new inputs.
- SmartZap's runner remains socketless; this change does not introduce Docker requirements.

---

### Task 1: Add failing hardening contract tests

**Files:**
- Create: `.github/tests/test-smartzap-consumer-hardening.sh`
- Modify: `Makefile`

**Interfaces:**
- Consumes: `.github/workflows/go.yaml`, `.github/workflows/yarn.yaml`, and the composite actions they reference.
- Produces: `make test-smartzap-consumer-hardening`, a regression gate for same-revision references and input forwarding.

- [ ] **Step 1: Write tests that assert no mutable `rios0rios0/pipelines@main` remains in the Go/Yarn reachable files.**
- [ ] **Step 2: Assert `changelog_check` is declared by both workflows and forwarded to basic-checks.**
- [ ] **Step 3: Assert Knip declares `node_version`, uses it in setup-node, and Yarn forwards its workflow value.**
- [ ] **Step 4: Add the focused target to `Makefile` and run it.**

Run: `make test-smartzap-consumer-hardening`
Expected: FAIL on all three missing contracts.

- [ ] **Step 5: Commit the red tests.**

### Task 2: Implement same-revision action resolution

**Files:**
- Modify: `.github/workflows/go.yaml`
- Modify: `.github/workflows/yarn.yaml`
- Modify: all Go/Yarn-reachable composites reported by Task 1
- Modify: `.github/tests/test-workflow-composition.sh`
- Modify: `.github/tests/test-supply-chain.sh`

**Interfaces:**
- Consumes: GitHub's `$/path` same-revision action syntax already used by the Yarn Semgrep job.
- Produces: fully same-revision Go/Yarn action graphs.

- [ ] **Step 1: Replace repository-owned `@main` uses in the reachable graph with `$/path`.**
- [ ] **Step 2: Update generic repository tests so `$/path` is accepted and required for these two graphs without weakening third-party SHA pinning.**
- [ ] **Step 3: Run the focused hardening, workflow-composition, and supply-chain tests.**

Run: `make test-smartzap-consumer-hardening test-workflow-composition test-supply-chain`
Expected: same-revision assertions PASS; changelog and Node forwarding assertions still FAIL until Task 3.

- [ ] **Step 4: Commit the same-revision migration.**

### Task 3: Add compatibility inputs and verify the fork

**Files:**
- Modify: `github/global/stages/10-code-check/basic-checks/action.yaml`
- Modify: `github/javascript/stages/10-code-check/knip/action.yaml`
- Modify: `.github/workflows/go.yaml`
- Modify: `.github/workflows/yarn.yaml`
- Create: `.changes/unreleased/Fixed-20260902-010000.yaml`

**Interfaces:**
- Produces: workflow input `changelog_check: boolean = true`; composite input `changelog_check: string = 'true'`; Knip input `node_version: string = '20'` forwarded from Yarn.

- [ ] **Step 1: Gate only the changelog step on `inputs.changelog_check == 'true'`; leave rebase validation unconditional.**
- [ ] **Step 2: Declare and forward `changelog_check` in both reusable workflows with default `true`.**
- [ ] **Step 3: Declare Knip's `node_version`, use it in setup-node, and forward Yarn's `node_version`.**
- [ ] **Step 4: Add a changelog fragment describing immutable consumer execution and compatibility inputs.**
- [ ] **Step 5: Run the focused test and observe it pass.**

Run: `make test-smartzap-consumer-hardening`
Expected: PASS.

- [ ] **Step 6: Run the full suite.**

Run: `make test`
Expected: PASS with `All tests completed successfully!`.

- [ ] **Step 7: Commit the compatibility implementation and documentation.**

### Task 4: Publish and canary the hardening PR

**Files:**
- No additional source files expected.

**Interfaces:**
- Produces: a reviewed SmartZap fork PR and, after green checks, an immutable merge SHA for backend/frontend callers.

- [ ] **Step 1: Push `fix/SZE-8-pin-reusable-components`.**
- [ ] **Step 2: Open a PR explaining the threat model, compatibility defaults, and tests.**
- [ ] **Step 3: Wait for GitHub Actions and CodeRabbit; resolve every technically valid finding.**
- [ ] **Step 4: Merge only when all required checks are green.**
- [ ] **Step 5: Record the merge SHA for consumer migration.**
