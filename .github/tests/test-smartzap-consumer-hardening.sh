#!/usr/bin/env bash
set -euo pipefail

# Contract tests for the Go and Yarn reusable workflows.  The manifest is
# deliberately explicit: it is the audited transitive set of files reachable
# from those workflows, including every composite action they call.  Keeping
# the set here makes adding a new nested action a visible review change rather
# than allowing a graph-walker bug to make the check silently pass.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
passed=0
failed=0

check() {
  local name="$1"
  shift
  if "$@"; then
    echo -e "${GREEN}PASS: $name${NC}"
    passed=$((passed + 1))
  else
    echo -e "${RED}FAIL: $name${NC}"
    failed=$((failed + 1))
  fi
}

no_mutable_references() {
  local files=(
    .github/workflows/go.yaml
    .github/workflows/yarn.yaml
    github/global/stages/10-code-check/basic-checks/action.yaml
    github/golang/stages/10-code-check/golangci-lint/action.yaml
    github/golang/stages/10-code-check/openapi-sync/action.yaml
    github/golang/stages/10-code-check/cross-compile/action.yaml
    github/global/stages/20-security/codeql/action.yaml
    github/global/stages/20-security/semgrep/action.yaml
    github/global/stages/20-security/gitleaks/action.yaml
    github/global/stages/20-security/hadolint/action.yaml
    github/golang/stages/20-security/govulncheck/action.yaml
    github/golang/stages/30-tests/all/action.yaml
    github/global/abstracts/scripts-repo/action.yaml
    github/javascript/stages/10-code-check/format/action.yaml
    github/javascript/stages/10-code-check/knip/action.yaml
  )
  python3 - "$ROOT" "${files[@]}" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = set(sys.argv[2:])
uses = re.compile(r"^\s*-?\s*uses:\s*['\"]?([^'\"\s]+)")

def resolve_reference(reference):
    if reference.startswith("rios0rios0/pipelines/"):
        target, _, revision = reference.partition("@")
        return target.removeprefix("rios0rios0/pipelines/"), revision
    if reference.startswith("$/"):
        return reference.removeprefix("$/"), ""
    return None

def validate_closure(base, audited):
    failures = []
    for relative in audited:
        path = base / relative
        if not path.is_file():
            failures.append(f"missing manifest file: {relative}")
            continue
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = uses.match(line)
            if not match:
                continue
            resolved = resolve_reference(match.group(1))
            if resolved is None:
                continue
            target, revision = resolved
            if revision == "main":
                failures.append(f"{relative}:{line_number}: mutable @main reference")
            # Every repository-owned edge must point at an audited manifest entry.
            # This keeps the explicit manifest authoritative while making a newly
            # nested composite impossible to add without extending the audit.
            candidate = target if target.endswith((".yaml", ".yml")) else f"{target}/action.yaml"
            if candidate not in audited:
                failures.append(f"{relative}:{line_number}: reachable file absent from manifest: {candidate}")
    return failures

# Self-test the exact production validator against a fixture: this is the form
# Task 2 uses for same-revision references, and an unmanifested nested action
# must be rejected by the same closure logic used below.
import tempfile
with tempfile.TemporaryDirectory() as directory:
    fixture = Path(directory)
    (fixture / "root").mkdir()
    (fixture / "root/action.yaml").write_text("- uses: '$/github/new/action'\n", encoding="utf-8")
    fixture_failures = validate_closure(fixture, {"root/action.yaml"})
    assert any("reachable file absent from manifest: github/new/action/action.yaml" in failure for failure in fixture_failures), fixture_failures

failures = validate_closure(root, manifest)

if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)
PY
}

workflow_contracts() {
  python3 - "$ROOT/.github/workflows/go.yaml" "$ROOT/.github/workflows/yarn.yaml" "$ROOT/github/global/stages/10-code-check/basic-checks/action.yaml" <<'PY'
import sys
import yaml

go, yarn, basic = (yaml.safe_load(open(path, encoding="utf-8")) for path in sys.argv[1:])

def workflow_inputs(document):
    # PyYAML's YAML 1.1 loader resolves the `on` key to True.
    trigger = document.get(True, document.get("on", {}))
    return trigger.get("workflow_call", {}).get("inputs", {})

def basic_forwards(document, name):
    for step in document["jobs"]["code_check-basic_checks"]["steps"]:
        if "basic-checks" in step.get("uses", ""):
            return step.get("with", {}).get(name) == f"${{{{ inputs.{name} }}}}"
    return False

assert "changelog_check" in workflow_inputs(go), "go.yaml does not declare changelog_check"
assert "changelog_check" in workflow_inputs(yarn), "yarn.yaml does not declare changelog_check"
assert basic_forwards(go, "changelog_check"), "go.yaml does not forward changelog_check to basic-checks"
assert basic_forwards(yarn, "changelog_check"), "yarn.yaml does not forward changelog_check to basic-checks"
PY
}

knip_contracts() {
  python3 - "$ROOT/.github/workflows/yarn.yaml" "$ROOT/github/javascript/stages/10-code-check/knip/action.yaml" <<'PY'
import sys
import yaml

yarn, knip = (yaml.safe_load(open(path, encoding="utf-8")) for path in sys.argv[1:])

assert "node_version" in knip.get("inputs", {}), "knip does not declare node_version"
setup = next((step for step in knip["runs"]["steps"] if step.get("uses", "").startswith("actions/setup-node@")), None)
assert setup and setup.get("with", {}).get("node-version") == "${{ inputs.node_version }}", "knip setup-node does not use inputs.node_version"
call = next((step for step in yarn["jobs"]["code_check-quality_knip"]["steps"] if step.get("uses", "").endswith("/javascript/stages/10-code-check/knip")), None)
assert call and call.get("with", {}).get("node_version") == "${{ inputs.node_version }}", "yarn does not forward node_version to knip"
PY
}

echo "SmartZap consumer hardening contracts"
check "same-revision references" no_mutable_references
check "changelog_check forwarding" workflow_contracts
check "Knip node_version forwarding" knip_contracts
echo "Passed: $passed; Failed: $failed"
((failed == 0))
