# parse_stability.ps1 — Extract key metrics from MT5 Tester HTML reports (UTF-16LE)
# and output a formatted summary table.
#
# Usage: powershell -File tools/stability/parse_stability.ps1
# Reads all stab_*.htm from the MT5 root directory.

$mt5 = "C:\Program Files\MetaTrader 5"
$files = Get-ChildItem "$mt5\stab_*.htm" -ErrorAction SilentlyContinue | Sort-Object Name

if ($files.Count -eq 0) {
    Write-Host "No stab_*.htm reports found in $mt5"
    exit 1
}

# Header
"{0,-22} {1,7} {2,10} {3,10} {4,7} {5,8} {6,8}" -f "Variant","Trades","NET","MaxDD","DD%","PF","Sharpe"
"{0,-22} {1,7} {2,10} {3,10} {4,7} {5,8} {6,8}" -f ("-------","------","--------","--------","----","------","------")

foreach ($f in $files) {
    $name = $f.BaseName
    $raw = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::Unicode)
    $html = $raw -replace "`r`n","`n" -replace "`n"," "

    function Extract($label) {
        if ($html -match "${label}.*?<b>([^<]+)</b>") {
            return $Matches[1].Trim() -replace '\s',''
        }
        return "N/A"
    }

    $net    = Extract "总净盈利"
    $maxdd  = Extract "最大结余亏损"
    $trades = Extract "交易总计"
    $pf     = Extract "盈利因子"
    $sharpe = Extract "夏普比率"

    $dd_pct = "N/A"
    if ($maxdd -match '\(([\d.]+)%\)') {
        $dd_pct = $Matches[1] + "%"
        $maxdd = ($maxdd -split '\(')[0].Trim()
    }

    "{0,-22} {1,7} {2,10} {3,10} {4,7} {5,8} {6,8}" -f $name,$trades,$net,$maxdd,$dd_pct,$pf,$sharpe
}
