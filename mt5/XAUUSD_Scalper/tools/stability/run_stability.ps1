# run_stability.ps1 — Run all 30 stability backtests sequentially.
# MT5 terminal64.exe forks: the launcher exits immediately while the real
# terminal runs in a separate process. We poll for the terminal64 process
# to disappear after each run.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\stability\run_stability.ps1
# Prereq: MT5 terminal must be CLOSED.

$ErrorActionPreference = "Stop"
$mt5      = "C:\Program Files\MetaTrader 5"
$tools    = "C:\Users\Administrator\docs\mt5\XAUUSD_Scalper\tools"
$stabDir  = "$tools\stability"
$testerProfile = "$mt5\MQL5\Profiles\Tester\XAUUSD_Scalper"

# 1. Deploy .set files
Write-Host "[stability] Deploying .set files..."
Get-ChildItem "$stabDir\stab_*.set" | ForEach-Object {
    Copy-Item $_.FullName "$testerProfile\$($_.Name)" -Force
}
Write-Host "[stability] Deployed .set files to $testerProfile"

# 2. Collect ini list
$inis = Get-ChildItem "$stabDir\stab_*.ini" | Sort-Object Name
$total = $inis.Count
Write-Host "[stability] Running $total backtests..."

$results = @()

for ($i = 0; $i -lt $total; $i++) {
    $ini = $inis[$i]
    $name = $ini.BaseName
    $n = $i + 1

    Write-Host "[$n/$total] $name ..."

    # Write ini to MT5 root with flat ExpertParameters path
    $content = (Get-Content $ini.FullName -Raw) -replace 'ExpertParameters=.*', "ExpertParameters=XAUUSD_Scalper\$name.set"
    $iniDst = "$mt5\$name.ini"
    [System.IO.File]::WriteAllText($iniDst, $content, [System.Text.Encoding]::ASCII)

    # Remove old report if exists
    $reportPath = "$mt5\$name.htm"
    if (Test-Path $reportPath) { Remove-Item $reportPath -Force }

    # Launch terminal
    Start-Process -FilePath "$mt5\terminal64.exe" -ArgumentList "/config:$iniDst"

    # Wait for terminal64 process to appear (up to 15s)
    $appeared = $false
    for ($w = 0; $w -lt 30; $w++) {
        Start-Sleep -Milliseconds 500
        if (Get-Process terminal64 -ErrorAction SilentlyContinue) {
            $appeared = $true
            break
        }
    }

    if (-not $appeared) {
        Write-Host "  WARNING: terminal64 never appeared for $name"
        continue
    }

    # Poll until terminal64 exits (up to 30 min)
    $timeout = 1800
    $elapsed = 0
    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 5
        $elapsed += 5
        if (-not (Get-Process terminal64 -ErrorAction SilentlyContinue)) {
            break
        }
        if ($elapsed % 60 -eq 0) {
            Write-Host "  ... waiting ($elapsed s)"
        }
    }

    if ($elapsed -ge $timeout) {
        Write-Host "  WARNING: timeout after ${timeout}s, killing"
        Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 3
    }

    # Extra wait for file flush
    Start-Sleep -Seconds 3

    # Check report
    if (Test-Path $reportPath) {
        $html = [System.IO.File]::ReadAllText($reportPath, [System.Text.Encoding]::Unicode)
        $flat = $html -replace "`r`n"," " -replace "`n"," "

        function ExtractMetric($label) {
            if ($flat -match "${label}.*?<b>([^<]+)</b>") {
                return $Matches[1].Trim() -replace '\s',''
            }
            return "N/A"
        }

        $net    = ExtractMetric "总净盈利"
        $maxdd  = ExtractMetric "最大结余亏损"
        $trades = ExtractMetric "交易总计"
        $pf     = ExtractMetric "盈利因子"
        $sharpe = ExtractMetric "夏普比率"

        $dd_pct = "N/A"
        if ($maxdd -match '\(([\d.]+)%\)') {
            $dd_pct = $Matches[1] + "%"
            $maxdd = ($maxdd -split '\(')[0].Trim()
        }

        Write-Host "  NET=$net  MaxDD=$maxdd ($dd_pct)  Trades=$trades  PF=$pf  Sharpe=$sharpe"
        $results += "$name`t$trades`t$net`t$maxdd`t$dd_pct`t$pf`t$sharpe"
    } else {
        Write-Host "  WARNING: no report for $name"
        $results += "$name`tN/A`tN/A`tN/A`tN/A`tN/A`tN/A"
    }

    # Cleanup temp ini
    Remove-Item $iniDst -Force -ErrorAction SilentlyContinue
}

# Write summary
$summaryPath = "$stabDir\stability_results.tsv"
$header = "Variant`tTrades`tNET`tMaxDD`tDD%`tPF`tSharpe"
($header, $results) | Out-File -FilePath $summaryPath -Encoding utf8
Write-Host ""
Write-Host "[stability] Done. Summary saved to $summaryPath"
Write-Host ""
Write-Host $header
$results | ForEach-Object { Write-Host $_ }
