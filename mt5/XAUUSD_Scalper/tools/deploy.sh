#!/usr/bin/env bash
# Sync XAUUSD_Scalper source tree from the docs git repo into the MT5
# portable data folder at C:\Program Files\MetaTrader 5\MQL5.
#
# Usage: bash tools/deploy.sh
set -euo pipefail

SRC_ROOT="/c/Users/Administrator/docs/mt5/XAUUSD_Scalper"
DST_ROOT="/c/Program Files/MetaTrader 5/MQL5"

copy_tree() {
  local sub="$1"                         # e.g. Include/Tests
  local src_dir="${SRC_ROOT}/${sub}"
  local first="${sub%%/*}"               # Include
  local rest="${sub#*/}"                 # Tests
  local dst_dir="${DST_ROOT}/${first}/XAUUSD_Scalper/${rest}"

  if [[ ! -d "${src_dir}" ]]; then
    return
  fi
  mkdir -p "${dst_dir}"
  cp -rT "${src_dir}" "${dst_dir}"
  echo "[deploy] ${src_dir} -> ${dst_dir}"
}

deploy_expert() {
  local src="${SRC_ROOT}/Experts"
  local dst="${DST_ROOT}/Experts/XAUUSD_Scalper"
  mkdir -p "${dst}"
  if compgen -G "${src}/*.mq5" > /dev/null; then
    cp -f "${src}"/*.mq5 "${dst}/"
    echo "[deploy] ${src}/*.mq5 -> ${dst}/"
  fi
}

copy_tree "Include/Tests"
copy_tree "Include/Analysis"
copy_tree "Include/Core"
copy_tree "Include/Data"
copy_tree "Scripts/Tests"
deploy_expert

echo "[deploy] OK"
