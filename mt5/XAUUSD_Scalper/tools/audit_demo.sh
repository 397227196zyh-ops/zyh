#!/usr/bin/env bash
# Audit Phase 1 EA demo run artefacts. Reads CSVs + logs + HTML and emits a
# PASS/FAIL table aligned with docs/superpowers/specs/2026-04-25-phase1-demo-acceptance.md
#
# Usage: bash tools/audit_demo.sh [files_root]
#   files_root default: C:/Program Files/MetaTrader 5/MQL5/Files/XAUUSD_Scalper
set -euo pipefail

FILES_ROOT="${1:-/c/Program Files/MetaTrader 5/MQL5/Files/XAUUSD_Scalper}"
LOGS="${FILES_ROOT}/Logs"
REPORTS="${FILES_ROOT}/Reports"

pass=()
fail=()
warn=()

record_pass() { pass+=("$1"); echo "[PASS] $1"; }
record_fail() { fail+=("$1"); echo "[FAIL] $1"; }
record_warn() { warn+=("$1"); echo "[WARN] $1"; }

section() { echo ""; echo "=== $1 ==="; }

today="$(date +%Y%m%d)"

section "Artefact locations"
echo "files_root = ${FILES_ROOT}"
for d in "${FILES_ROOT}" "${LOGS}" "${REPORTS}"; do
  if [[ -d "${d}" ]]; then echo "  found dir: ${d}"; else echo "  missing dir: ${d}"; fi
done
for f in \
  "${FILES_ROOT}/decision_snapshots.csv" \
  "${FILES_ROOT}/execution_quality.csv" \
  "${FILES_ROOT}/trade_history.csv" ; do
  if [[ -f "${f}" ]]; then echo "  found: ${f} ($(wc -c <"${f}") bytes)"; else echo "  missing: ${f}"; fi
done

DEC="${FILES_ROOT}/decision_snapshots.csv"
EXEC="${FILES_ROOT}/execution_quality.csv"
HIST="${FILES_ROOT}/trade_history.csv"
MAIN_LOG="${LOGS}/main_${today}.log"
GUARD_LOG="${LOGS}/guard_${today}.log"

section "Condition 1 — EA compiles + Init OK"
if [[ -f "${MAIN_LOG}" ]] && grep -q "Init OK" "${MAIN_LOG}"; then
  record_pass "1  init line present in ${MAIN_LOG}"
else
  record_fail "1  missing Init OK in ${MAIN_LOG}"
fi

section "Condition 2 — three strategies active"
if [[ -f "${DEC}" ]]; then
  dec_lines=$(awk -F, 'NR>1 && $7==1 {print $2}' "${DEC}" | sort -u | wc -l)
  if [[ "${dec_lines}" -ge 2 ]]; then
    record_pass "2  ${dec_lines} distinct strategies produced allowed=1 rows"
  else
    record_fail "2  only ${dec_lines} distinct strategies with allowed=1 (need ≥ 2)"
  fi
else
  record_fail "2  decision_snapshots.csv missing"
fi

section "Condition 3 — only London / NY sessions let orders through"
if [[ -f "${DEC}" ]]; then
  bad=$(awk -F, 'NR>1 && $7==1 && $4==0' "${DEC}" | wc -l)
  if [[ "${bad}" -eq 0 ]]; then
    record_pass "3  no allowed=1 row with session=0"
  else
    record_fail "3  ${bad} allowed=1 rows outside session"
  fi
else
  record_fail "3  decision_snapshots.csv missing"
fi

section "Condition 4 — ExecutionGuard rejected something"
if [[ -f "${GUARD_LOG}" ]] && grep -qE "guard=[1-9]|COOLDOWN|SPREAD|ABNORMAL|DAILY|CONSEC|SESSION" "${GUARD_LOG}"; then
  record_pass "4  guard log contains non-zero rejects"
else
  record_warn "4  no guard rejections yet (may be normal on calm market)"
fi

section "Condition 5 — TrendConfirm shaped signal flow"
if [[ -f "${DEC}" ]]; then
  trend_rej=$(awk -F, 'NR>1 && $8=="TREND"' "${DEC}" | wc -l)
  if [[ "${trend_rej}" -ge 1 ]]; then
    record_pass "5  ${trend_rej} rows rejected with reason=TREND"
  else
    record_warn "5  no TREND rejections — run may have been all neutral"
  fi
else
  record_fail "5  decision_snapshots.csv missing"
fi

section "Condition 6 — unified exit actually ran"
if [[ -f "${MAIN_LOG}" ]] && grep -Eqi "partial|breakeven|trailing|timeout" "${MAIN_LOG}"; then
  record_pass "6  exit-stage markers found in main log"
else
  record_warn "6  no exit-stage markers — may be OK if no trade reached +1R"
fi

section "Condition 7 — limited pyramiding within caps"
if [[ -f "${HIST}" ]]; then
  record_warn "7  manual check: total theoretical max loss ≤ 5% equity"
  head -n 1 "${HIST}" || true
  tail -n 5 "${HIST}" || true
else
  record_fail "7  trade_history.csv missing"
fi

section "Condition 8 — base risk anchor 0.5%"
if [[ -f "${DEC}" ]]; then
  record_warn "8  planned_lot × sl_distance must be ≤ equity × 0.5% × 1.01"
  awk -F, 'NR>1 && $7==1 {printf "    strat=%s planned_lot=%s sl_distance=%s\n", $2,$13,$12}' "${DEC}" | head -n 5
else
  record_fail "8  decision_snapshots.csv missing"
fi

section "Condition 9 — abnormal market auto-pause"
if [[ -f "${DEC}" ]] && grep -q "ABNORMAL_MARKET" "${DEC}"; then
  record_pass "9  at least one ABNORMAL_MARKET rejection present"
else
  record_warn "9  no ABNORMAL_MARKET rejections — may be OK on calm session"
fi

section "Condition 10 — CSVs and logs populated"
for f in "${DEC}" "${EXEC}" "${HIST}" "${MAIN_LOG}" "${GUARD_LOG}"; do
  if [[ -s "${f}" ]]; then record_pass "10 ${f} non-empty"; else record_fail "10 ${f} missing or empty"; fi
done

section "Condition 11 — reason coverage"
if [[ -f "${DEC}" ]]; then
  for r in SESSION GUARD TREND NO_SIGNAL PASS; do
    if awk -F, -v r="$r" 'NR>1 && index($8,r){found=1} END{exit !found}' "${DEC}"; then
      record_pass "11 reason=${r} appears"
    else
      record_warn "11 reason=${r} missing"
    fi
  done
else
  record_fail "11 decision_snapshots.csv missing"
fi

section "Condition 12 — dashboard / chart annotations"
record_warn "12 manual: verify dashboard + open/close arrows by screenshot"

section "HTML report"
report="${REPORTS}/report-${today}.html"
if [[ -f "${report}" ]]; then
  sz=$(wc -c <"${report}")
  if [[ "${sz}" -ge 5120 ]]; then
    record_pass "HTML report ${report} (${sz} bytes, > 5KB)"
  else
    record_warn "HTML report ${report} only ${sz} bytes (< 5KB)"
  fi
else
  record_warn "HTML report for today not yet emitted: ${report}"
fi

echo ""
echo "=== Summary ==="
printf "PASS=%d  FAIL=%d  WARN=%d\n" "${#pass[@]}" "${#fail[@]}" "${#warn[@]}"
if [[ "${#fail[@]}" -gt 0 ]]; then exit 1; fi
exit 0
