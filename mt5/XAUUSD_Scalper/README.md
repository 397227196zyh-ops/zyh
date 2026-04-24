# XAUUSD MT5 Scalper — Phase 1 (P1 foundation complete)

Implements sections 2, 3, 4, 7.1, 7.2 of
`docs/superpowers/specs/2026-04-24-xauusd-mt5-scalper-phase1-merged-design.md`.

## Deployment (portable MT5 install at `C:\Program Files\MetaTrader 5`)

A helper script copies the tracked source tree into the MT5 data folder:

```
bash tools/deploy.sh
```

It places each module under `MQL5/<kind>/XAUUSD_Scalper/...` so `#include
<XAUUSD_Scalper/...>` works without further path tweaking.

## Compiling from the command line

`tools/compile.sh` wraps `MetaEditor64.exe /compile`:

```
bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_TestRunner.mq5
bash tools/compile.sh Experts/XAUUSD_Scalper/XAUUSD_Scalper_EA.mq5
```

MetaEditor only writes a `.log` file when there are diagnostics. A run that
produces an `.ex5` and no log is a clean build.

## P1 green-gate checklist

All of the following must hold before starting P2:

- `Experts/XAUUSD_Scalper_EA.mq5` compiles with 0 errors and 0 warnings.
- `Scripts/Tests/Test_TestRunner.mq5` prints `passed=4 failed=0`.
- `Scripts/Tests/Test_LoggerStub.mq5` prints `passed=2 failed=0`.
- `Scripts/Tests/Test_TickCollector.mq5` prints `passed=4 failed=0`.
- `Scripts/Tests/Test_IndicatorManager.mq5` prints `passed=9 failed=0`.
- `Scripts/Tests/Test_MarketAnalyzer.mq5` prints `passed=6 failed=0`.
- `Scripts/Tests/Test_StrategyBase.mq5` prints `passed=4 failed=0`.
- `Scripts/Tests/Test_StrategyEMA.mq5` prints `passed=4 failed=0`.
- `Scripts/Tests/Test_StrategyBollinger.mq5` prints `passed=3 failed=0`.
- `Scripts/Tests/Test_StrategyRSI.mq5` prints `passed=4 failed=0`.
- EA attached to XAUUSD M1 prints `Init OK`, then at least one
  `[DBG] ema` / `[DBG] boll` / `[DBG] rsi` line, then `deinit` on removal.

## Not in P1

- Session filter, execution guard, trend confirm
- Order placement and risk manager
- Position manager (partial TP, breakeven, ATR trailing, timeout exit)
- Limited pyramiding
- Persistence (trade_history, decision_snapshots, execution_quality)
- Full logger with daily rotation
- Performance tracker, HTML report, dashboard
- Backtest control toggles for A/B harness

All of the above ship in plans P2, P3, P4.

## P2 status

In progress — adds `CSessionFilter`, `CMarketContext`, `CExecutionGuard`,
`CTrendConfirm`, and gated `OnTick` logging.

## Notes on virtual indicator getters

`CIndicatorManager` marks its price/indicator getters (`EMA`, `RSI`, `ATR`,
`ADX`, `BBUpper`, `BBLower`, `BBMiddle`, `PlusDI`, `MinusDI`, `EMA20_M5`,
`EMA50_M5`) as `virtual` so strategy harnesses under `Scripts/Tests` can
derive a `FakeIM` from it and inject scripted indicator values without going
through MT5 indicator handles.
