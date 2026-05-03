#!/usr/bin/env bash
# Generate parameter-stability .set + .ini files for v4b single-parameter perturbation.
# Each variant changes ONE parameter from the v4b baseline; the rest stay identical.
set -euo pipefail

TOOLS="$(cd "$(dirname "$0")" && pwd)"
BASE="$TOOLS/live_ensemble_m5.set"
OUTDIR="$TOOLS/stability"
mkdir -p "$OUTDIR"

# --- helper: clone base .set, override one param, write to $OUTDIR ---
gen_set() {
  local name="$1" param="$2" value="$3"
  local out="$OUTDIR/stab_${name}.set"
  # Replace the line starting with $param= (or append if missing)
  if grep -q "^${param}=" "$BASE"; then
    sed "s/^${param}=.*/${param}=${value}/" "$BASE" > "$out"
  else
    cp "$BASE" "$out"
    echo "${param}=${value}" >> "$out"
  fi
}

# --- helper: generate matching .ini ---
gen_ini() {
  local name="$1"
  local out="$OUTDIR/stab_${name}.ini"
  cat > "$out" <<EOF
[Tester]
Expert=XAUUSD_Scalper\\XAUUSD_Scalper_EA
ExpertParameters=XAUUSD_Scalper\\stability\\stab_${name}.set
Symbol=XAUUSD
Period=M5
Deposit=1000
Currency=USD
Leverage=1:500
Spread=-1
ExecutionMode=1
Model=0
FromDate=2025.05.01
ToDate=2026.04.30
ForwardMode=0
Optimization=0
OptimizationCriterion=0
Report=stab_${name}
ReplaceReport=1
ShutdownTerminal=1
EOF
}

# --- grid definitions: param  label-prefix  values (space-separated) ---
# InpEMASlMult (baseline 1.5)
for v in 1.2 1.3 1.4 1.5 1.6 1.7 1.8; do
  gen_set "sl_${v}" InpEMASlMult "$v"
  gen_ini "sl_${v}"
done

# InpEMATpMult (baseline 1.2)
for v in 0.9 1.0 1.1 1.2 1.3 1.4 1.5; do
  gen_set "tp_${v}" InpEMATpMult "$v"
  gen_ini "tp_${v}"
done

# InpConsecLossLimit (baseline 3)
for v in 2 3 4 5; do
  gen_set "cl_${v}" InpConsecLossLimit "$v"
  gen_ini "cl_${v}"
done

# InpLonEndHour (baseline 17)
for v in 15 16 17 18; do
  gen_set "lon_${v}" InpLonEndHour "$v"
  gen_ini "lon_${v}"
done

# InpTrendingADX (baseline 25)
for v in 20 25 30; do
  gen_set "adx_${v}" InpTrendingADX "$v"
  gen_ini "adx_${v}"
done

# InpMaxHoldBars (baseline 60)
for v in 40 50 60 70 80; do
  gen_set "hold_${v}" InpMaxHoldBars "$v"
  gen_ini "hold_${v}"
done

echo "Generated $(ls "$OUTDIR"/*.set | wc -l) .set files and $(ls "$OUTDIR"/*.ini | wc -l) .ini files in $OUTDIR/"
