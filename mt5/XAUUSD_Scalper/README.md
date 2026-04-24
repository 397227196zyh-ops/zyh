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

Complete. Adds:

- `CSessionFilter` — London/NY weekday windows with Saturday/Sunday block.
- `CMarketContext` — rolling ATR average (default window 50) plus a
  breakout counter over the last 20 samples.
- `CExecutionGuard` — spread / stops / cooldown / daily-loss /
  consec-loss / abnormal-market / session-closed rejection with explicit
  `ENUM_GUARD_REASON` codes.
- `CTrendConfirm` — M5 trend state (`TREND_BULLISH`, `TREND_BEARISH`,
  `TREND_NEUTRAL`) and per-strategy allow rules (EMA allows neutral,
  BOLL requires same-direction trend, RSI rejects counter-trend and
  requires proximity to M5 EMA20 in same-direction trend).
- Gated `OnTick` logging: one `[INF] gate | strat=... dir=...
  session=... guard=... trend=... allowed=... reason=...` line per
  strategy per tick.

### P2 green-gate

All must hold before starting P3:

- `bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_SessionFilter.mq5`  → `ex5 OK` (covered).
- `bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_MarketContext.mq5`  → `ex5 OK` (covered).
- `bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_ExecutionGuard.mq5` → `ex5 OK` (covered).
- `bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_TrendConfirm.mq5`   → `ex5 OK` (covered).
- `bash tools/compile.sh Experts/XAUUSD_Scalper/XAUUSD_Scalper_EA.mq5`         → `ex5 OK` (covered).
- EA attached to XAUUSD M1 emits `[INF] gate | ...` for each of
  EMA/BOLL/RSI with machine-readable `guard=`, `trend=`, `allowed=` fields.

### Not yet in P2

- Order placement, risk manager, Kelly with base-risk anchor
- Position manager (partial TP, breakeven, ATR trailing, timeout exit)
- Limited pyramiding
- Persistence and reporting

## P3 status

Complete. Adds:

- `CTradeLedger` — in-memory per-strategy wins/losses/consec/daily loss,
  no disk IO yet (ships in P4).
- `CRiskManager` — 0.5 % base risk anchor × half-Kelly adjuster with a
  hard 5 % total open-risk cap. Rejects with explicit reasons
  (`NON_POSITIVE_KELLY`, `INVALID_SL`, `BELOW_MIN_LOT`, `TOTAL_RISK_CAP`).
- `CExecutionEngine` — `CTrade` wrapper with retryable error handling,
  market + limit support, slippage tracking, and a dry-run switch so the
  unit harness can exercise it without touching the broker.
- `CPositionManager` — 4-stage unified exit: partial TP 50 % at +1.0 R,
  breakeven+buffer, ATR trailing, timeout exit after `max_hold_bars`.
  Limited pyramiding: ≤ 2 adds per campaign, gated on +0.5 R, rejected
  on `MARKET_ABNORMAL`, trend flip, and distance < `pyramid_min_distance`.
- EA wiring: gated signals compute lots via `CRiskManager`, place market
  or limit orders via `CExecutionEngine`, and hand fills to
  `CPositionManager`, which ticks the exit state machine.

### P3 green-gate

All hold before starting P4:

- `bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_TradeLedger.mq5` → `ex5 OK`.
- `bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_RiskManager.mq5` → `ex5 OK`.
- `bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_ExecutionEngine_Smoke.mq5` → `ex5 OK`.
- `bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_PositionManager.mq5` → `ex5 OK`.
- `bash tools/compile.sh Experts/XAUUSD_Scalper/XAUUSD_Scalper_EA.mq5` → `ex5 OK`.
- `AllTestsEA` in the Strategy Tester prints `passed=95 failed=0`
  (P1 34 + P2 26 + P3 35).

### Not yet in P3

- Persistence: `trade_history.csv`, `decision_snapshots.csv`, `statistics.json`
- Full `CLogger` with daily rotation
- `CPerformanceTracker`, HTML report, `CDashboard`
- A/B harness toggles for Guard / TrendConfirm / UnifiedExit

## Notes on virtual indicator getters

`CIndicatorManager` marks its price/indicator getters (`EMA`, `RSI`, `ATR`,
`ADX`, `BBUpper`, `BBLower`, `BBMiddle`, `PlusDI`, `MinusDI`, `EMA20_M5`,
`EMA50_M5`) as `virtual` so strategy harnesses under `Scripts/Tests` can
derive a `FakeIM` from it and inject scripted indicator values without going
through MT5 indicator handles.
