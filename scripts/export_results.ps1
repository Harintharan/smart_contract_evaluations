<#
.SYNOPSIS
Exports Forge test results to a CSV under results/.

.DESCRIPTION
Runs `forge test -vv`, captures the raw output, parses PASS/FAIL lines
along with gas usage and suite name, and writes a timestamped CSV file.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Join-Path $PSScriptRoot '..'
Set-Location $Root

New-Item -ItemType Directory -Force -Path 'results' | Out-Null

$tsLog = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$rawFile = Join-Path 'results' ("forge-test-{0}.log" -f $tsLog)
$csvFile = Join-Path 'results' ("test_results_{0}.csv" -f $tsLog)

# Run tests and capture output
& forge test -vv | Tee-Object -FilePath $rawFile | Out-Null

$runTs = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$rows = New-Object System.Collections.Generic.List[object]
$suite = ''

Get-Content -Path $rawFile | ForEach-Object {
    $line = $_

    # Match suite header: Ran X tests for <suite>
    $mSuite = [regex]::Match($line, '^Ran\s+\d+\s+tests\s+for\s+(.+)$')
    if ($mSuite.Success) {
        $suite = $mSuite.Groups[1].Value
        return
    }

    # Match test result: [PASS] testName() (gas: 12345)
    $mTest = [regex]::Match($line, '^\[(PASS|FAIL)\]\s+([^\s]+).*?(?:\(gas:\s*(\d+)\))?')
    if ($mTest.Success) {
        $status = $mTest.Groups[1].Value
        $test = $mTest.Groups[2].Value
        $gas = if ($mTest.Groups[3].Success) { $mTest.Groups[3].Value } else { '' }
        $rows.Add([pscustomobject]@{
            timestamp = $runTs
            suite      = $suite
            test       = $test
            status     = $status
            gas        = $gas
        }) | Out-Null
    }
}

$rows | Export-Csv -Path $csvFile -NoTypeInformation
Write-Host ("CSV written: {0}" -f $csvFile)

