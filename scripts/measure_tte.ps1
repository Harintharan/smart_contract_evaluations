<#
.SYNOPSIS
Measures Time-to-Exposure (TTE) for the baseline invariant.

.DESCRIPTION
Runs the invariant contract `Invariants` which includes
`invariant_Baseline_Fails_On_Attacker_Update` and measures wall-clock
time until the first failure (forge exits non-zero).

Outputs a CSV in results/forge_tte_results_<timestamp>.csv with columns:
timestamp,test_name,elapsed_seconds,status,run_count
#>

param(
  [int]$Runs = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Join-Path $PSScriptRoot '..'
Set-Location $Root

New-Item -ItemType Directory -Force -Path 'results' | Out-Null

$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$csvFile = Join-Path 'results' ("forge_tte_results_{0}.csv" -f $ts)

$testName = 'Invariants::invariant_Baseline_Fails_On_Attacker_Update'

# Write header
"timestamp,test_name,elapsed_seconds,status,run_count" | Out-File -FilePath $csvFile -Encoding utf8

for ($i = 1; $i -le $Runs; $i++) {
    Write-Host ("Run {0}/{1}: executing invariants..." -f $i, $Runs)

    $start = [DateTimeOffset]::UtcNow
    $status = 'PASS'
    # Measure-Command for wall-clock time
    $m = Measure-Command {
        & forge test --match-contract Invariants -vv *> $null
        $global:__exitcode = $LASTEXITCODE
    }
    if ($global:__exitcode -ne 0) { $status = 'FAIL' }
    $elapsed = [Math]::Round($m.TotalSeconds, 3)
    $tsRow = $start.ToString('yyyy-MM-ddTHH:mm:ssZ')

    Write-Host ("TTE seconds: {0} | Status: {1}" -f $elapsed, $status)
    "${tsRow},${testName},${elapsed},${status},${i}" | Add-Content -Path $csvFile -Encoding utf8
}

Write-Host ("CSV written: {0}" -f $csvFile)
