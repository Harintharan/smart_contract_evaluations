<#
.SYNOPSIS
Runs Forge coverage and saves summary and LCOV to results/ with timestamp.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Join-Path $PSScriptRoot '..'
Set-Location $Root

New-Item -ItemType Directory -Force -Path 'results' | Out-Null

$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$summaryFile = Join-Path 'results' ("coverage_{0}.txt" -f $ts)
$lcovFile    = Join-Path 'results' ("coverage_{0}.lcov" -f $ts)

# Coverage summary
forge coverage --report summary | Tee-Object -FilePath $summaryFile | Out-Null

# LCOV output
forge coverage --report lcov | Set-Content -Path $lcovFile

Write-Host ("Coverage summary: {0}" -f $summaryFile)
Write-Host ("Coverage LCOV:   {0}" -f $lcovFile)

