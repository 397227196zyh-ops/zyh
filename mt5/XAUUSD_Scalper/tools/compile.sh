#!/usr/bin/env bash
# Compile one MQL5 source with MetaEditor64.exe and read the generated .log.
#
# Usage: bash tools/compile.sh <relative MQL5 path, forward slashes>
# Example: bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_LoggerStub.mq5
set -euo pipefail

REL="${1:?missing relative MQL5 path}"
MT5_DIR="/c/Program Files/MetaTrader 5"
SRC_ABS="${MT5_DIR}/MQL5/${REL}"

if [[ ! -f "${SRC_ABS}" ]]; then
  echo "[compile] missing ${SRC_ABS}" >&2
  exit 1
fi

# MetaEditor emits <src>.log next to the source file.
rm -f "${SRC_ABS%.mq5}.log"

# Translate to a Windows path for MetaEditor
WIN_REL="$(echo "MQL5/${REL}" | sed 's|/|\\|g')"

cd "${MT5_DIR}"
./MetaEditor64.exe /compile:"${WIN_REL}" /log >/dev/null 2>&1 || true

LOG="${SRC_ABS%.mq5}.log"
if [[ -f "${LOG}" ]]; then
  iconv -f UTF-16LE -t UTF-8 "${LOG}" 2>/dev/null || cat "${LOG}"
else
  echo "[compile] no log produced for ${REL}"
fi

EX5="${SRC_ABS%.mq5}.ex5"
if [[ -f "${EX5}" ]]; then
  echo "[compile] ex5 OK: ${EX5}"
else
  echo "[compile] NO ex5 produced for ${REL}" >&2
  exit 2
fi
