<#
.SYNOPSIS
  validate.ps1 — build, lint, policy checks, and (optionally) what-if. NEVER deploys.
.EXAMPLE
  ./scripts/validate.ps1
  ./scripts/validate.ps1 -WhatIf -ResourceGroup rg-casapi-dev
#>
[CmdletBinding()]
param(
  [switch]$WhatIf,
  [string]$ResourceGroup
)

$ErrorActionPreference = 'Continue'
$Root  = Resolve-Path (Join-Path $PSScriptRoot '..')
$Main  = Join-Path $Root 'infra/main.bicep'
$Prm   = Join-Path $Root 'infra/dev.bicepparam'
$Out   = Join-Path $Root 'infra/main.json'
$script:Fail = $false

function Pass($m) { Write-Host "  PASS  $m" -ForegroundColor Green }
function Fail($m) { Write-Host "  FAIL  $m" -ForegroundColor Red; $script:Fail = $true }
function Warn($m) { Write-Host "  WARN  $m" -ForegroundColor Yellow }
function Section($m) { Write-Host "`n== $m" }

# ---------------------------------------------------------------- 0. tooling
Section 'Tooling'
if (-not (Get-Command az -ErrorAction SilentlyContinue)) { Fail 'Azure CLI (az) not found. https://aka.ms/installazurecli'; exit 1 }
az bicep version *> $null
if ($LASTEXITCODE -ne 0) { Warn "Installing Bicep CLI (az bicep install)"; az bicep install *> $null }
Pass "az bicep $(az bicep version 2>$null | Select-Object -First 1)"

# ---------------------------------------------------------------- 1. build
Section 'Build  (az bicep build --file infra/main.bicep)'
az bicep build --file $Main --outfile $Out
if ($LASTEXITCODE -ne 0) { Fail 'bicep build failed'; exit 1 } else { Pass 'compiled → infra/main.json' }

# ---------------------------------------------------------------- 2. lint
Section 'Lint  (az bicep lint --file infra/main.bicep)'
$lint = az bicep lint --file $Main 2>&1 | Out-String
if ($lint.Trim()) { Write-Host $lint }
if ($LASTEXITCODE -ne 0 -or $lint -match ' error ') { Fail 'lint reported errors' }
elseif ($lint -match ' warning ') { Warn 'lint warnings present — list them in the PR'; Pass 'lint: no errors' }
else { Pass 'lint: clean' }

# ---------------------------------------------------------------- 3. secrets scan
Section 'Secrets scan  (infra/**/*.bicep, *.bicepparam)'
$files = Get-ChildItem (Join-Path $Root 'infra') -Recurse -Include *.bicep, *.bicepparam
$hits = $files | Select-String -Pattern "(password|passwd|secret|connectionString|accountKey|sasToken|apiKey)[A-Za-z]*\s*[:=]\s*'[^\$'][^']*'" |
        Where-Object { $_.Line -notmatch 'keyVaultReference|@secure|description\(|//' }
if ($hits) { $hits | ForEach-Object { Write-Host "  $($_.Path):$($_.LineNumber): $($_.Line.Trim())" }; Fail 'literal secret-like values found in source' }
else { Pass 'no literal secrets in Bicep source' }

# ---------------------------------------------------------------- 4. policy checks
Section 'Policy checks  (infra/main.json)'
$raw = Get-Content $Out -Raw
$tpl = if ($PSVersionTable.PSVersion.Major -ge 7) { $raw | ConvertFrom-Json -Depth 100 } else { $raw | ConvertFrom-Json }

function Get-AllResources($node) {
  # Recursively collect every object with type + apiVersion (walks nested module deployments).
  if ($null -eq $node) { return }
  if ($node -is [System.Collections.IEnumerable] -and $node -isnot [string]) { foreach ($i in $node) { Get-AllResources $i }; return }
  if ($node -is [pscustomobject]) {
    if ($node.PSObject.Properties['type'] -and $node.PSObject.Properties['apiVersion']) { $node }
    foreach ($p in $node.PSObject.Properties) { Get-AllResources $p.Value }
  }
}
$all = @(Get-AllResources $tpl)
function OfType($t) { @($all | Where-Object { $_.type -eq $t }) }
function IsExpr($v) { ($v -is [string]) -and $v.StartsWith('[') }
function Check($type, [scriptblock]$test, $label) {
  $rs = OfType $type
  if ($rs.Count -eq 0) { Fail "$label — no $type resource found"; return }
  $bad = @($rs | Where-Object { -not (& $test $_) }).Count
  if ($bad -eq 0) { Pass $label } else { Fail "$label ($bad of $($rs.Count) non-compliant)" }
}
function Lit($v, $expected) { (IsExpr $v) -or ($v -eq $expected) -or ("$v".ToLower() -eq "$expected".ToLower()) }

foreach ($t in 'Microsoft.Web/serverfarms','Microsoft.Web/sites','Microsoft.KeyVault/vaults','Microsoft.Storage/storageAccounts',
               'Microsoft.Network/virtualNetworks','Microsoft.Network/privateEndpoints','Microsoft.OperationalInsights/workspaces','Microsoft.Insights/components') {
  Check $t { param($r) $null -ne $r.PSObject.Properties['tags'] } "tags present · $t"
}
Check 'Microsoft.Web/sites' { param($r) "$($r.identity.type)" -match 'SystemAssigned' } 'App Service uses system-assigned identity'
Check 'Microsoft.KeyVault/vaults' { param($r) Lit $r.properties.publicNetworkAccess 'Disabled' } 'Key Vault publicNetworkAccess = Disabled'
Check 'Microsoft.KeyVault/vaults' { param($r) Lit $r.properties.enableRbacAuthorization $true } 'Key Vault RBAC authorization enabled'
Check 'Microsoft.KeyVault/vaults' { param($r) Lit $r.properties.enablePurgeProtection $true } 'Key Vault purge protection enabled'
Check 'Microsoft.Storage/storageAccounts' { param($r) Lit $r.properties.publicNetworkAccess 'Disabled' } 'Storage publicNetworkAccess = Disabled'
Check 'Microsoft.Storage/storageAccounts' { param($r) Lit $r.properties.supportsHttpsTrafficOnly $true } 'Storage HTTPS only'
Check 'Microsoft.Storage/storageAccounts' { param($r) Lit $r.properties.minimumTlsVersion 'TLS1_2' } 'Storage minimum TLS 1.2'
Check 'Microsoft.Storage/storageAccounts' { param($r) Lit $r.properties.allowBlobPublicAccess $false } 'Storage blob public access disabled'
Check 'Microsoft.Storage/storageAccounts' { param($r) Lit $r.properties.allowSharedKeyAccess $false } 'Storage shared-key access disabled'
Check 'Microsoft.Web/sites' { param($r) Lit $r.properties.httpsOnly $true } 'App Service httpsOnly'
Check 'Microsoft.Web/sites' { param($r) Lit $r.properties.siteConfig.minTlsVersion '1.2' } 'App Service minTlsVersion 1.2'
Check 'Microsoft.Web/sites' { param($r) Lit $r.properties.siteConfig.ftpsState 'Disabled' } 'App Service FTPS disabled'
Check 'Microsoft.Web/sites' { param($r) -not [string]::IsNullOrEmpty($r.properties.virtualNetworkSubnetId) } 'App Service VNet-integrated'

foreach ($gid in 'vault','blob') {
  $pe = @(OfType 'Microsoft.Network/privateEndpoints' | Where-Object { @($_.properties.privateLinkServiceConnections | ForEach-Object { $_.properties.groupIds }) -contains $gid })
  if ($pe.Count -gt 0) { Pass "private endpoint for groupId=$gid" } else { Fail "no private endpoint with groupId=$gid" }
}
$zg = OfType 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups'
if ($zg.Count -gt 0) { Pass "private DNS zone groups present ($($zg.Count))" } else { Fail 'no privateDnsZoneGroups — private DNS will not resolve' }

$ra = OfType 'Microsoft.Authorization/roleAssignments'
$raBad = @($ra | Where-Object { $null -eq $_.PSObject.Properties['scope'] }).Count
if ($ra.Count -eq 0) { Fail 'no role assignments found (R6)' } elseif ($raBad -eq 0) { Pass "role assignments scoped to a resource ($($ra.Count))" } else { Fail "$raBad role assignment(s) not scoped to a resource" }

$deploy = Get-ChildItem (Join-Path $Root 'scripts'), (Join-Path $Root '.github') -Recurse -File -Include *.sh, *.ps1, *.yml, *.yaml |
          Where-Object { $_.Name -notlike 'validate.*' } |
          Select-String -Pattern 'az deployment (group|sub|mg|tenant) create'
if ($deploy) { Fail 'deployment command found in scripts/ or .github/' } else { Pass 'no deployment commands in repo automation' }

# ---------------------------------------------------------------- 5. what-if (optional)
if ($WhatIf) {
  Section "What-if  (read-only)  rg=$ResourceGroup"
  if (-not $ResourceGroup) { Fail '-WhatIf requires -ResourceGroup' }
  else {
    az account show *> $null
    if ($LASTEXITCODE -eq 0) {
      az deployment group what-if --resource-group $ResourceGroup --template-file $Main --parameters $Prm
      Pass 'what-if completed — review adds/changes/deletes above'
    } else { Warn 'not logged in (az login) — what-if skipped' }
  }
}

# ---------------------------------------------------------------- summary
Section 'Result'
if (-not $script:Fail) { Write-Host '  ALL GATES PASSED — machine-verifiable checks only. Architect review still required.' -ForegroundColor Green; exit 0 }
else { Write-Host '  GATES FAILED — fix the FAIL lines above and re-run.' -ForegroundColor Red; exit 1 }
