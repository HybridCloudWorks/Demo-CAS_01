#!/usr/bin/env bash
# validate.sh — build, lint, policy checks, and (optionally) what-if. NEVER deploys.
#
# Usage:
#   scripts/validate.sh                       # build + lint + policy checks
#   scripts/validate.sh --what-if <rg-name>   # ...plus a read-only what-if against an existing resource group
#
# Exit code is non-zero if any gate fails. Output is meant to be pasted into the PR as evidence.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA="$ROOT/infra"
MAIN="$INFRA/main.bicep"
PARAMS="$INFRA/dev.bicepparam"
OUT="$INFRA/main.json"
FAIL=0

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; }
section() { printf '\n== %s\n' "$1"; }

# ------------------------------------------------------------------ 0. tooling
section "Tooling"
if ! command -v az >/dev/null 2>&1; then
  fail "Azure CLI (az) not found. Install: https://aka.ms/installazurecli"
  exit 1
fi
if ! az bicep version >/dev/null 2>&1; then
  warn "Bicep CLI not installed for az — running 'az bicep install'"
  az bicep install >/dev/null 2>&1 || { fail "az bicep install failed"; exit 1; }
fi
pass "az $(az version --query '"azure-cli"' -o tsv 2>/dev/null) · bicep $(az bicep version 2>/dev/null | head -n1)"
HAVE_JQ=1; command -v jq >/dev/null 2>&1 || HAVE_JQ=0

# ------------------------------------------------------------------ 1. build
section "Build  (az bicep build --file infra/main.bicep)"
if az bicep build --file "$MAIN" --outfile "$OUT"; then
  pass "compiled → infra/main.json"
else
  fail "bicep build failed"
  exit 1
fi

# ------------------------------------------------------------------ 2. lint
section "Lint  (az bicep lint --file infra/main.bicep)"
LINT_OUT="$(az bicep lint --file "$MAIN" 2>&1)"
LINT_RC=$?
[ -n "$LINT_OUT" ] && printf '%s\n' "$LINT_OUT"
if [ $LINT_RC -ne 0 ] || grep -qiE ' error ' <<<"$LINT_OUT"; then
  fail "lint reported errors"
elif grep -qiE ' warning ' <<<"$LINT_OUT"; then
  warn "lint warnings present (listed above) — acceptable, but list them in the PR"
  pass "lint: no errors"
else
  pass "lint: clean"
fi

# ------------------------------------------------------------------ 3. secrets scan (source)
section "Secrets scan  (infra/**/*.bicep, *.bicepparam)"
# Literal values assigned to secret-looking names. Expressions ("${...}", params) are not literals.
SECRET_HITS="$(grep -rnE "(password|passwd|secret|connectionString|accountKey|sasToken|apiKey)[A-Za-z]*\s*[:=]\s*'[^\$'][^']*'" \
  "$INFRA" --include='*.bicep' --include='*.bicepparam' 2>/dev/null | grep -viE "keyVaultReference|@secure|description\(|//" || true)"
if [ -n "$SECRET_HITS" ]; then
  printf '%s\n' "$SECRET_HITS"
  fail "literal secret-like values found in source"
else
  pass "no literal secrets in Bicep source"
fi
if grep -rnE '@secure\(\)\s*$' -A1 "$INFRA" --include='*.bicep' 2>/dev/null | grep -qE 'param .* = '; then
  fail "@secure() parameter has a default value"
else
  pass "no @secure() parameters with defaults"
fi

# ------------------------------------------------------------------ 4. policy checks (compiled template)
section "Policy checks  (infra/main.json)"
if [ $HAVE_JQ -eq 0 ]; then
  warn "jq not found — policy checks skipped. Install jq or run scripts/validate.ps1."
else
  # All resources across nested module deployments.
  ALL='[.. | objects | select(has("type") and has("apiVersion"))]'
  res_count() { jq -r "$ALL | map(select(.type == \"$1\")) | length" "$OUT"; }
  # $1 type, $2 jq boolean expression on the resource, $3 label
  check() {
    local type="$1" expr="$2" label="$3" n bad
    n=$(res_count "$type")
    if [ "$n" = "0" ]; then fail "$label — no $type resource found"; return; fi
    bad=$(jq -r "$ALL | map(select(.type == \"$type\")) | map(select(($expr) | not)) | length" "$OUT")
    if [ "$bad" = "0" ]; then pass "$label"; else fail "$label ($bad of $n non-compliant)"; fi
  }
  # Property values may be ARM expressions (strings starting with '['); treat those as needing review, not failure.
  lit() { echo "(($1) == $2 or (($1) | tostring | startswith(\"[\")))"; }

  # Tags on every taggable primary resource
  for t in Microsoft.Web/serverfarms Microsoft.Web/sites Microsoft.KeyVault/vaults Microsoft.Storage/storageAccounts \
           Microsoft.Network/virtualNetworks Microsoft.Network/privateEndpoints Microsoft.OperationalInsights/workspaces Microsoft.Insights/components; do
    check "$t" 'has("tags")' "tags present · $t"
  done

  # Identity
  check Microsoft.Web/sites '(.identity.type // "") | test("SystemAssigned")' "App Service uses system-assigned identity"

  # Public access off for data services
  check Microsoft.KeyVault/vaults "$(lit '(.properties.publicNetworkAccess // "" | ascii_downcase)' '"disabled"')" "Key Vault publicNetworkAccess = Disabled"
  check Microsoft.KeyVault/vaults "$(lit '.properties.enableRbacAuthorization' 'true')" "Key Vault RBAC authorization enabled"
  check Microsoft.KeyVault/vaults "$(lit '.properties.enablePurgeProtection' 'true')" "Key Vault purge protection enabled"
  check Microsoft.Storage/storageAccounts "$(lit '(.properties.publicNetworkAccess // "" | ascii_downcase)' '"disabled"')" "Storage publicNetworkAccess = Disabled"
  check Microsoft.Storage/storageAccounts "$(lit '.properties.supportsHttpsTrafficOnly' 'true')" "Storage HTTPS only"
  check Microsoft.Storage/storageAccounts "$(lit '.properties.minimumTlsVersion' '"TLS1_2"')" "Storage minimum TLS 1.2"
  check Microsoft.Storage/storageAccounts "$(lit '.properties.allowBlobPublicAccess' 'false')" "Storage blob public access disabled"
  check Microsoft.Storage/storageAccounts "$(lit '.properties.allowSharedKeyAccess' 'false')" "Storage shared-key access disabled"

  # App Service hardening
  check Microsoft.Web/sites "$(lit '.properties.httpsOnly' 'true')" "App Service httpsOnly"
  check Microsoft.Web/sites "$(lit '.properties.siteConfig.minTlsVersion' '"1.2"')" "App Service minTlsVersion 1.2"
  check Microsoft.Web/sites "$(lit '.properties.siteConfig.ftpsState' '"Disabled"')" "App Service FTPS disabled"
  check Microsoft.Web/sites '(.properties.virtualNetworkSubnetId // "") != ""' "App Service VNet-integrated"

  # Private endpoints: one for vault, one for blob, each with a DNS zone group
  for gid in vault blob; do
    n=$(jq -r "$ALL | map(select(.type == \"Microsoft.Network/privateEndpoints\")) | map(select([.properties.privateLinkServiceConnections[]?.properties.groupIds[]?] | index(\"$gid\"))) | length" "$OUT")
    [ "$n" != "0" ] && pass "private endpoint for groupId=$gid" || fail "no private endpoint with groupId=$gid"
  done
  n=$(res_count Microsoft.Network/privateEndpoints/privateDnsZoneGroups)
  [ "$n" != "0" ] && pass "private DNS zone groups present ($n)" || fail "no privateDnsZoneGroups — private DNS will not resolve"

  # Role assignments must be scoped to a resource, not the resource group
  bad=$(jq -r "$ALL | map(select(.type == \"Microsoft.Authorization/roleAssignments\")) | map(select(has(\"scope\") | not)) | length" "$OUT")
  n=$(res_count Microsoft.Authorization/roleAssignments)
  if [ "$n" = "0" ]; then fail "no role assignments found (R6)"; elif [ "$bad" = "0" ]; then pass "role assignments scoped to a resource ($n)"; else fail "$bad role assignment(s) not scoped to a resource"; fi

  # Deployment commands must never appear in scripts
  if grep -rnE 'az deployment (group|sub|mg|tenant) create' "$ROOT/scripts" "$ROOT/.github" \
       --include='*.sh' --include='*.ps1' --include='*.yml' --include='*.yaml' 2>/dev/null | grep -v 'validate\.' ; then
    fail "deployment command found in scripts/ or .github/"
  else
    pass "no deployment commands in repo automation"
  fi
fi

# ------------------------------------------------------------------ 5. what-if (optional, read-only)
if [ "${1:-}" = "--what-if" ]; then
  RG="${2:-}"
  section "What-if  (read-only)  rg=$RG"
  if [ -z "$RG" ]; then fail "--what-if requires a resource group name"; else
    if az account show >/dev/null 2>&1; then
      az deployment group what-if --resource-group "$RG" --template-file "$MAIN" --parameters "$PARAMS" --no-pretty-print -o json \
        | jq -r '.changes[] | "\(.changeType)\t\(.resourceId | split("/") | .[-2:] | join("/"))"' 2>/dev/null || warn "what-if output could not be summarized (see above)"
      pass "what-if completed — review adds/changes/deletes above"
    else
      warn "not logged in (az login) — what-if skipped"
    fi
  fi
fi

# ------------------------------------------------------------------ summary
section "Result"
if [ $FAIL -eq 0 ]; then
  printf '  \033[32mALL GATES PASSED\033[0m — machine-verifiable checks only. Architect review still required.\n'
else
  printf '  \033[31mGATES FAILED\033[0m — fix the FAIL lines above and re-run.\n'
fi
exit $FAIL
