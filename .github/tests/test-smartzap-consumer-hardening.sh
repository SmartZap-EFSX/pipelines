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
  local found=()
  local file
  for file in "${files[@]}"; do
    [[ -f "$ROOT/$file" ]] || { echo "missing manifest file: $file" >&2; return 1; }
    while IFS= read -r line; do
      found+=("$file:$line")
    done < <(grep -nE "rios0rios0/pipelines/[^'\"[:space:]]+@main([[:space:]]|['\"]|$)" "$ROOT/$file" || true)
  done
  ((${#found[@]} == 0)) || { printf '%s\n' "${found[@]}" >&2; return 1; }
}

workflow_contracts() {
  python3 - "$ROOT/.github/workflows/go.yaml" "$ROOT/.github/workflows/yarn.yaml" "$ROOT/github/global/stages/10-code-check/basic-checks/action.yaml" <<'PY'
import re
import sys

go, yarn, basic = (open(path, encoding="utf-8").read() for path in sys.argv[1:])

def workflow_has_input(text, name):
    # Inputs must be declared below workflow_call.inputs, not merely mentioned
    # in a job expression or a comment.
    match = re.search(r"(?ms)^    inputs:\n(.*?)(?=^    secrets:|^jobs:)", text)
    return bool(match and re.search(rf"(?m)^      {re.escape(name)}:\s*$", match.group(1)))

def basic_forwards(text, name):
    step = re.search(r"(?ms)^      - uses: ['\"]?[^\n]*basic-checks[^\n]*\n(.*?)(?=^      - |^    [A-Za-z0-9_-]+:|\Z)", text)
    return bool(step and re.search(rf"(?m)^          {re.escape(name)}:\s*['\"]?\$\{{\{{\s*inputs\.{re.escape(name)}\s*\}}\}}", step.group(1)))

assert workflow_has_input(go, "changelog_check"), "go.yaml does not declare changelog_check"
assert workflow_has_input(yarn, "changelog_check"), "yarn.yaml does not declare changelog_check"
assert basic_forwards(go, "changelog_check"), "go.yaml does not forward changelog_check to basic-checks"
assert basic_forwards(yarn, "changelog_check"), "yarn.yaml does not forward changelog_check to basic-checks"
PY
}

knip_contracts() {
  python3 - "$ROOT/.github/workflows/yarn.yaml" "$ROOT/github/javascript/stages/10-code-check/knip/action.yaml" <<'PY'
import re
import sys

yarn, knip = (open(path, encoding="utf-8").read() for path in sys.argv[1:])

inputs = re.search(r"(?ms)^inputs:\n(.*?)(?=^runs:)", knip)
assert inputs and re.search(r"(?m)^  node_version:\s*$", inputs.group(1)), "knip does not declare node_version"
setup = re.search(r"(?ms)- name: ['\"]?Setup Node\.js.*?(?=^    - |\Z)", knip)
assert setup and re.search(r"(?m)^        node-version:\s*['\"]?\$\{\{\s*inputs\.node_version\s*\}\}", setup.group(0)), "knip setup-node does not use inputs.node_version"
call = re.search(r"(?ms)^      - uses: ['\"]?[^\n]*/javascript/stages/10-code-check/knip[^\n]*\n(.*?)(?=^      - |^    [A-Za-z0-9_-]+:|\Z)", yarn)
assert call and re.search(r"(?m)^          node_version:\s*['\"]?\$\{\{\s*inputs\.node_version\s*\}\}", call.group(1)), "yarn does not forward node_version to knip"
PY
}

echo "SmartZap consumer hardening contracts"
check "same-revision references" no_mutable_references
check "changelog_check forwarding" workflow_contracts
check "Knip node_version forwarding" knip_contracts
echo "Passed: $passed; Failed: $failed"
((failed == 0))
