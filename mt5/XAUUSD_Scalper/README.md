# XAUUSD MT5 Scalper — Phase 1

MT5 Expert Advisor implementing the Phase 1 merged design documented in:

- `docs/superpowers/specs/2026-04-24-xauusd-mt5-scalper-phase1-merged-design.md`

## Folder structure

- `Experts/XAUUSD_Scalper_EA.mq5` — EA entry point
- `Include/Core/` — strategies, market analyzer (P1), session filter + execution guard + trend confirm + risk + position manager (later plans)
- `Include/Data/` — tick collector, indicator manager, persistence (later plan)
- `Include/Analysis/` — logging stub (P1), performance tracker + reporter (later plan)
- `Include/Tests/TestRunner.mqh` — minimal assertion helper
- `Scripts/Tests/` — harness scripts run manually in MT5 Strategy Tester Scripts

## How to build

1. Copy or symlink `mt5/XAUUSD_Scalper/` into `<MT5 terminal data folder>/MQL5/`.
2. Open `Experts/XAUUSD_Scalper_EA.mq5` in MetaEditor, press F7.
3. Open any `Scripts/Tests/Test_*.mq5`, press F7, then drag it onto an XAUUSD M1 chart.
