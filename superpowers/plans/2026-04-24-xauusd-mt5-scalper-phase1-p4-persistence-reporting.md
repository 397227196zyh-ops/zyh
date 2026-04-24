# XAUUSD MT5 Scalper Phase 1 — P4 Persistence, Analysis, Reporting, Dashboard Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every dispatched subagent prompt MUST include an explicit "NOT ALLOWED" fence forbidding off-plan files, deploys, or helper scripts; the controller verifies `git diff` after each return.

**Goal:** Land everything that makes phase 1 auditable and reviewable: disk persistence, a real rotating logger, the performance tracker, an HTML report generator, and an on-chart dashboard. Add A/B harness toggles for Guard / TrendConfirm / UnifiedExit to support the controlled backtest experiments called for in §12.2 of the spec.

**Architecture:** Data-layer persistence under `MQL5/Files/XAUUSD_Scalper/` with clearly scoped CSV/JSON writers (`CDataPersistence`, `CTradeHistory`, `CDecisionSnapshot`, `CExecutionQuality`). Analysis layer owns `CLogger` (replaces the P1 stub), `CPerformanceTracker`, `CReportGenerator`, `CBacktestAnalyzer`. UI layer provides `CDashboard`, `CChartDrawer`, `CVisualizer`. The EA keeps the same OnTick pipeline from P3 and fans out to these new consumers.

**Tech Stack:** MetaTrader 5 / MQL5, built-in `FileOpen` / `FileWriteString`, `ChartSetInteger` / `ObjectCreate` for on-chart UI, plain HTML + Chart.js generated as a single self-contained file in `Files/`.

---

## P4 Scope

P4 adds:

1. Disk layout under `MQL5/Files/XAUUSD_Scalper/{Logs,Reports}` plus `trade_history.csv`, `decision_snapshots.csv`, `execution_quality.csv`, `statistics.json`.
2. Full `CLogger` with daily rotation, 30-day cap, and per-category files (`main`, `trades`, `execution`, `market_events`, `guard`, `errors`).
3. `CDecisionSnapshot` + `CExecutionQuality` + `CTradeHistory` writers called from the existing pipeline (EA + `CExecutionEngine` + `CPositionManager`).
4. `CPerformanceTracker` populated from ledger + history, producing the 5 indicator groups demanded by the spec.
5. `CReportGenerator` emitting a single-file HTML under `Files/XAUUSD_Scalper/Reports/report-YYYYMMDD.html`.
6. `CDashboard` + `CChartDrawer` + `CVisualizer` on the active chart.
7. A/B harness toggles: `InpEnableGuard`, `InpEnableTrendConfirm`, `InpEnableUnifiedExit` (default `true`).

P4 does NOT: add cloud sync, external news feeds, multi-instrument code, or ML signals. Those are explicitly out of scope for phase 1.

P4 ends green when:

- Every `.mqh` / `.mq5` compiles via `tools/compile.sh` with `ex5 OK` and no log diagnostics.
- Every new harness `Test_*.mq5` prints `passed=N failed=0`.
- Running the EA on a demo XAUUSD account produces:
  - `MQL5/Files/XAUUSD_Scalper/Logs/main_YYYYMMDD.log` with `[INF]` lines.
  - `trade_history.csv` with at least one row after the first close.
  - `decision_snapshots.csv` with rows for each signal evaluation.
  - `execution_quality.csv` with one row per fill.
  - `Reports/report-YYYYMMDD.html` openable in a browser, showing equity curve, trades table, guard-rejection distribution, and trend-confirm impact bars.
  - On-chart dashboard panel with account, risk, guard, trend, and per-strategy stats.
- The three A/B toggles each flip the corresponding layer on/off without crashing the EA and are reflected in the gate / exit logs.

---

### Task 0: P4 branch checkpoint

**Files:**
- Modify: `mt5/XAUUSD_Scalper/README.md`

- [ ] **Step 1:** Append `## P4 status` section:

```markdown
## P4 status

In progress — adds real persistence, rotating logger, performance
tracker, HTML report, on-chart dashboard, and A/B harness toggles.
```

- [ ] **Step 2:** Commit.

```bash
git -C /c/Users/Administrator/docs add mt5/XAUUSD_Scalper/README.md
git -C /c/Users/Administrator/docs commit -m "docs(mt5): open P4 status section"
```

---

### Task 1: Rotating `CLogger`

Replace `CLoggerStub` call sites with a full `CLogger` that:

- Opens one `FileHandle` per category (`main`, `trades`, `execution`, `market_events`, `guard`, `errors`) under `MQL5/Files/XAUUSD_Scalper/Logs/`.
- Auto-rotates on day change using `TimeCurrent()` and keeps at most 30 daily files per category (`CleanupOldLogs(today)`).
- Keeps `Info/Warn/Error/Debug(tag, fmt, ...)` signatures so existing call sites at the EA and gates need no refactor beyond swapping the type.

**Files:**
- Create: `mt5/XAUUSD_Scalper/Include/Analysis/CLogger.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_Logger.mq5`
- Modify: call sites in `CExecutionEngine`, `CPositionManager`, EA to accept `CLogger &` instead of `CLoggerStub &`; keep `CLoggerStub.mqh` available for unit harnesses that don't want disk IO.

Harness asserts (`passed=5 failed=0`):

- Writing 4 levels produces 4 lines in the `main` file.
- Tag-based categories (`trades`, `execution`, `market_events`, `guard`, `errors`) route to the right file.
- Setting level to `WARN` suppresses `INFO` and `DEBUG` from all categories.
- Rotating by simulated date change creates a new file dated to the injected `now`.
- `CleanupOldLogs(today, /*keep*/ 30)` deletes entries older than 30 days.

Commit: `feat(mt5/analysis): add CLogger with per-category files and daily rotation`.

---

### Task 2: `CDecisionSnapshot` + `CExecutionQuality` + `CTradeHistory`

Three separate writers, each responsible for exactly one file.

**Files (create + harness):**
- `CDecisionSnapshot.mqh` — writes one CSV row per `EvalStrategy` call with: `time, strat, dir, session, guard_reason, trend_state, allowed, reason, spread, atr, adx, sl_distance, planned_lot, is_pyramid`.
- `CExecutionQuality.mqh` — one row per fill: `time, strat, side, requested_price, fill_price, slippage, retries, latency_ms, order_type (market|limit)`.
- `CTradeHistory.mqh` — one row per closed trade: `open_time, close_time, strat, dir, entry, exit, lots, pnl, commission, swap, market_state_on_open, liquidity_score_on_open, slippage, exec_ms, was_limit`.
- Matching harness scripts (each prints `passed=3 failed=0`).

Commit: `feat(mt5/data): add CDecisionSnapshot, CExecutionQuality, CTradeHistory CSV writers`.

---

### Task 3: `CPerformanceTracker`

Aggregates five indicator groups from ledger + history + per-strategy buffers:

1. Basic returns (total trades, wins/losses, net PnL, avg win / loss, max win / loss).
2. Signal quality (candidate, rejected-session, rejected-guard, rejected-abnormal, rejected-trend, filled).
3. Execution quality (avg slippage, reject rate, limit fill rate, limit timeout cancel rate, avg order latency).
4. Position management (partial-TP rate, beaten-out-after-breakeven rate, trailing-exit PnL share, timeout exits + avg PnL).
5. Pyramiding (add count, PnL contribution, max added drawdown, rejected-by-risk adds).

**Files:**
- Create: `mt5/XAUUSD_Scalper/Include/Analysis/CPerformanceTracker.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_PerformanceTracker.mq5`

Harness asserts (`passed=5 failed=0`, one per indicator group).

Commit: `feat(mt5/analysis): add CPerformanceTracker with 5 indicator groups`.

---

### Task 4: `CReportGenerator`

Reads `trade_history.csv`, `decision_snapshots.csv`, `execution_quality.csv`, calls `CPerformanceTracker`, and emits a single HTML file with inlined Chart.js `<script>` + data arrays.

**Files:**
- Create: `mt5/XAUUSD_Scalper/Include/Analysis/CReportGenerator.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_ReportGenerator.mq5`

Report must contain:

- Overview cards (net PnL, win rate, Sharpe, max drawdown, # trades, pyramids).
- Equity curve line chart.
- Drawdown area chart.
- Per-strategy bar comparison (PnL, win rate, payoff).
- Market state distribution pie.
- Trade scatter + hourly heatmap.
- Execution quality table (avg slippage, reject rate, limit fill %).
- Risk table (max DD %, current DD %, exposure %, Sharpe, Sortino).
- Detailed trades table (paginated with CSS only, no JS framework).
- Guard rejection bar chart by reason code.
- TrendConfirm impact bar chart (`with_trend` vs `without_trend`).

Harness asserts (`passed=3 failed=0`):

- Given a stubbed history CSV, the generator produces an HTML file whose size > 5 KB and contains specific marker strings (`"<title>XAUUSD Scalper Report"`, `"const EQUITY_DATA ="`, `"guard_reason_distribution"`).

Commit: `feat(mt5/analysis): add CReportGenerator producing self-contained HTML report`.

---

### Task 5: `CDashboard` + `CChartDrawer` + `CVisualizer`

On-chart UI. `CDashboard` renders compact / detailed / fullscreen layouts using `OBJ_LABEL` + `OBJ_RECTANGLE_LABEL`. `CChartDrawer` draws open/close arrows, market-state background rectangles, and anomaly event marks. `CVisualizer` coordinates the two + handles color rules (profit green / loss red, spread thresholds, liquidity tiers, state background colors, risk exposure tiers).

**Files:**
- Create: `mt5/XAUUSD_Scalper/Include/UI/CDashboard.mqh`
- Create: `mt5/XAUUSD_Scalper/Include/UI/CChartDrawer.mqh`
- Create: `mt5/XAUUSD_Scalper/Include/UI/CVisualizer.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_Dashboard_Smoke.mq5`

The smoke harness draws the dashboard on an empty chart and removes it, asserting zero `LastError` after create/remove cycle (`passed=3 failed=0`).

Commit: `feat(mt5/ui): add CDashboard/CChartDrawer/CVisualizer with compact/detailed/full layouts`.

---

### Task 6: EA wiring — persistence + reports + A/B toggles

**Files:**
- Modify: `mt5/XAUUSD_Scalper/Experts/XAUUSD_Scalper_EA.mq5`

Changes:

1. Replace `CLoggerStub g_log` with `CLogger g_log` and wire its `Init("XAUUSD_Scalper")` inside `OnInit`.
2. Instantiate `CDecisionSnapshot`, `CExecutionQuality`, `CTradeHistory`, `CPerformanceTracker`, `CReportGenerator`, `CDashboard`, `CChartDrawer`, `CVisualizer`.
3. In `EvalStrategy`, write a `CDecisionSnapshot` row right after the `LogGate` call.
4. In the `OnFill` callback from `CPositionManager`, write to `CExecutionQuality`.
5. In the `OnClose` callback, write to `CTradeHistory` and trigger `CPerformanceTracker.Update()`.
6. On timer every 60 s: `CDashboard.Render()` + `CReportGenerator.Rebuild()`.
7. New `input` toggles:

    ```mql5
    input bool InpEnableGuard         = true;
    input bool InpEnableTrendConfirm  = true;
    input bool InpEnableUnifiedExit   = true;
    ```

    When any toggle is `false`, bypass the corresponding layer and record the bypass in the snapshot's `reason` column (`"GUARD_BYPASS"`, `"TREND_BYPASS"`, `"EXIT_BYPASS"`).
8. On `OnDeinit`, flush every CSV handle and close the logger.

Compile with `bash tools/compile.sh Experts/XAUUSD_Scalper/XAUUSD_Scalper_EA.mq5`; expect `ex5 OK`.

Commit: `feat(mt5/ea): wire persistence, dashboard, report generator, and A/B toggles`.

---

### Task 7: P4 README green-gate

**Files:**
- Modify: `mt5/XAUUSD_Scalper/README.md`

Replace `## P4 status` block with:

```markdown
## P4 status

Complete. Adds:

- `CLogger` with 6 per-category daily-rotated files + 30-day retention.
- `CDecisionSnapshot`, `CExecutionQuality`, `CTradeHistory` CSV writers.
- `CPerformanceTracker` with 5 indicator groups (returns, signal
  quality, execution quality, position management, pyramiding).
- `CReportGenerator` producing a single-file HTML report with Chart.js.
- `CDashboard` / `CChartDrawer` / `CVisualizer` with 3 on-chart layouts.
- A/B harness toggles `InpEnableGuard`, `InpEnableTrendConfirm`,
  `InpEnableUnifiedExit`.

### P4 green-gate

All must hold to call phase 1 complete:

- Every `Test_*.mq5` from P1+P2+P3+P4 compiles `ex5 OK`.
- `Test_Logger`, `Test_DecisionSnapshot`, `Test_ExecutionQuality`,
  `Test_TradeHistory`, `Test_PerformanceTracker`, `Test_ReportGenerator`,
  `Test_Dashboard_Smoke` all print `passed=N failed=0`.
- Running the EA on demo XAUUSD for one session writes at least one row
  to each CSV, produces a readable HTML report with expected sections,
  and renders the on-chart dashboard without errors.
- Disabling any of the 3 A/B toggles changes the downstream logs and
  CSV columns consistently and does not crash the EA.

### Phase 1 done

All four sub-plans green → phase 1 merged design is fully implemented.
Next up: phase 2 goals from the spec's §13 (pluggable strategies,
microstructure features, news integration, adaptive parameters).
```

Commit: `docs(mt5): close P4 green-gate and declare phase 1 complete`.

---

## Self-Review

**Spec coverage:**

| Spec section | Covered in P4? | Where |
| --- | --- | --- |
| §7.3 persistence structure | yes | Task 2 |
| §7.4 decision snapshot schema | yes | Task 2 |
| §7.5 persistence strategy (live vs backtest) | yes | Task 1 & 2 |
| §8.1 performance tracker 5 indicator groups | yes | Task 3 |
| §8.2 CLogger with daily rotation | yes | Task 1 |
| §8.3 backtest / A/B toggles | yes | Task 6 |
| §8.4 HTML report | yes | Task 4 |
| §9 Dashboard + chart annotations | yes | Task 5 |

**Placeholder scan:** every CSV schema is listed field-by-field, every harness states its assert count, every Task lists exact file creates and required commit message.

**Type consistency:**

- `ENUM_GUARD_REASON`, `ENUM_TREND_STATE`, `ENUM_MARKET_STATE`, `ENUM_SIGNAL_DIRECTION` reused across persistence writers.
- `CPerformanceTracker` reads the same `CTradeHistory` schema produced in Task 2.
- `CReportGenerator` reads snapshot/execution CSVs without any alias renaming.
- `CLogger` keeps the `CLoggerStub` method signatures so upstream code from P1/P2/P3 doesn't need refactoring beyond a type swap.
- A/B toggles don't introduce new enums — they short-circuit existing layers.

No drift detected.
