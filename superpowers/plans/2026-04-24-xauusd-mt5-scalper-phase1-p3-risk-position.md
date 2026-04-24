# XAUUSD MT5 Scalper Phase 1 — P3 Risk / Position / Execution Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every dispatched subagent prompt MUST include an explicit "NOT ALLOWED" fence forbidding off-plan files, deploys, or helper scripts; the controller verifies `git diff` after each return.

**Goal:** Add the risk manager, the real execution engine (market + pending orders), the unified position manager (partial TP → breakeven → ATR trailing → timeout), and limited pyramiding. After P3 the EA actually places and manages live trades on XAUUSD, but persistence, reporting, and dashboard are still deferred to P4.

**Architecture:** Four pure MQL5 classes plus updated EA wiring. `CRiskManager` enforces the 0.5 % base-risk anchor and the 5 % total-open-risk cap with Kelly-as-an-adjuster. `CExecutionEngine` chooses between market and limit orders based on market state and performs retry / partial-fill handling. `CPositionManager` tracks each open position, applies the 4-stage unified exit, and decides when pyramiding is allowed (≤ 2 adds, first add at +0.5 R, no pyramiding after abnormal market or after trend flip). `CTradeLedger` aggregates per-strategy and global state the risk manager needs (daily loss %, consec losses, last fail time) and replaces the placeholder feed P2 used.

**Tech Stack:** MetaTrader 5 / MQL5, `MqlTradeRequest` / `OrderSend` via `CTrade`, reusing `CTestRunner` for deterministic unit harnesses.

---

## P3 Scope

P3 adds:

1. `CTradeLedger` — in-memory per-strategy stats fed into the risk manager each tick (no disk IO yet).
2. `CRiskManager` — computes lot size from `(base_risk_anchor, kelly_fraction, sl_distance)` and enforces hard caps.
3. `CExecutionEngine` — wraps `CTrade` with retry, partial-fill handling, pending order timeout, and per-attempt slippage reporting.
4. `CPositionManager` — tracks live positions by magic, performs partial TP / breakeven / ATR trailing / timeout exit, and vets pyramiding proposals.
5. EA wiring that calls the execution engine when the full gate stack passes, registers the fill with the position manager, and lets the position manager do its `Update()` each tick.

P3 does NOT: persist decisions or trades to disk, produce dashboard / HTML reports, add the remaining A/B harness toggles. Those ship in P4.

P3 ends green when:

- Every `.mqh` / `.mq5` compiles via `tools/compile.sh` with `ex5 OK` and no log diagnostics.
- Every new harness `Test_*.mq5` prints `passed=N failed=0` for its N asserts.
- On a demo XAUUSD M1 chart, the EA places a market or limit order after a signal passes all gates, logs the fill, moves stops through the 4 exit stages, and never places more than 2 pyramid adds on a single trade campaign.

---

### Task 0: P3 branch checkpoint

**Files:**
- Modify: `mt5/XAUUSD_Scalper/README.md`

- [ ] **Step 1:** Append `## P3 status` section:

```markdown
## P3 status

In progress — adds `CTradeLedger`, `CRiskManager`, `CExecutionEngine`,
`CPositionManager`, and live order placement with unified exit and
limited pyramiding.
```

- [ ] **Step 2:** Commit.

```bash
git -C /c/Users/Administrator/docs add mt5/XAUUSD_Scalper/README.md
git -C /c/Users/Administrator/docs commit -m "docs(mt5): open P3 status section"
```

---

### Task 1: `CTradeLedger`

In-memory counters feeding `CRiskManager` and `CExecutionGuard`.

**Files:**
- Create: `mt5/XAUUSD_Scalper/Include/Data/CTradeLedger.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_TradeLedger.mq5`

Must expose:

```mql5
class CTradeLedger
{
public:
   void   Init();
   void   OnTradeClosed(const string strat, const double pnl_account_ccy, const datetime when);
   void   OnTradeFailed(const datetime when);
   int    ConsecLosses(const string strat) const;
   double DailyLossPct(const double account_equity) const;
   datetime LastFailTime() const;
   void   OnDayRollover(const datetime day_start);
};
```

Harness asserts (`passed=6 failed=0`):

- After 3 consecutive losses of −10 USD on strategy EMA, `ConsecLosses("EMA")` returns 3.
- A win resets the consec counter for that strategy.
- `DailyLossPct(10000)` returns 0.3 after three −10 losses (expressed in %).
- `OnDayRollover` resets daily sums but keeps consec counters.
- `OnTradeFailed(1000)` then `LastFailTime()` returns `1000`.
- Initial ledger has every counter at 0.

Implementation guidance:

- Use `string` → `int` / `double` lookup via parallel `string[]` + `double[]` arrays keyed by strategy name. MQL5 has no `CHashMap<string,int>` out of the box; a small linear lookup is fine for 3–5 strategies.
- Persist nothing to disk. That’s P4.

Commit message: `feat(mt5/data): add CTradeLedger in-memory per-strategy trade stats`.

---

### Task 2: `CRiskManager`

**Files:**
- Create: `mt5/XAUUSD_Scalper/Include/Core/CRiskManager.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_RiskManager.mq5`

Must expose:

```mql5
struct RiskInputs
  {
   double account_equity;
   double base_risk_pct;     // default 0.5
   double total_risk_cap_pct;// default 5.0
   double sl_distance;       // in price units
   double sl_per_lot_ccy;    // loss at stop for 1.0 lot
   double kelly_fraction;    // [0, 1]; already half-Kelly
   double open_risk_ccy;     // sum of open positions' theoretical max loss
   double min_lot;
   double max_lot;
   double lot_step;
  };

struct RiskDecision
  {
   bool   allowed;
   double lot;
   string reason;
  };

class CRiskManager
  {
public:
   RiskDecision Size(const RiskInputs &in) const;
  };
```

Rules:

1. `base_risk_ccy = equity * base_risk_pct / 100`.
2. `base_lots = base_risk_ccy / sl_per_lot_ccy` (guard against `sl_per_lot_ccy <= 0`).
3. `kelly_lots = base_lots * clamp(kelly_fraction, 0, 1)`; if `kelly_fraction <= 0` reject.
4. Cap by `min_lot`, `max_lot`, round down to `lot_step`.
5. Project post-trade open risk: `projected = open_risk_ccy + lot * sl_per_lot_ccy`. If `projected > equity * total_risk_cap_pct / 100`, reject with reason `TOTAL_RISK_CAP`.
6. If final lot < `min_lot`, reject with reason `BELOW_MIN_LOT`.

Harness asserts (`passed=6 failed=0`):

- 10 000 USD equity, 0.5 % base, half-Kelly = 0.5, SL loss / lot = 100 USD → lot = 0.25 → round to 0.25 (lot_step 0.01).
- Kelly 0 → rejected with reason `NON_POSITIVE_KELLY`.
- sl_per_lot_ccy ≤ 0 → rejected with reason `INVALID_SL`.
- Projected risk exceeds 5 % cap → rejected with reason `TOTAL_RISK_CAP`.
- Projected risk hits exactly 5 % cap → still allowed (boundary test).
- Lot size below min_lot after Kelly scaling → rejected with reason `BELOW_MIN_LOT`.

Commit message: `feat(mt5/core): add CRiskManager enforcing base-risk anchor with total-risk cap`.

---

### Task 3: `CExecutionEngine`

Wraps `CTrade` with:

- Market / limit selection based on `ENUM_MARKET_STATE` (trending/breakout → market, ranging → limit with Ask − 0.10 / Bid + 0.10 offset).
- Retry ≤ 3 with 100 ms spacing on requote / off-quotes / busy errors.
- Abort on `TRADE_RETCODE_REJECT` and other terminal errors after recording reason.
- Track executed slippage = |fill price − requested price| for trade quality reporting in P4.
- Return an `ExecutionResult` with `{filled, ticket, filled_price, slippage, retcode, reason_str}`.

**Files:**
- Create: `mt5/XAUUSD_Scalper/Include/Core/CExecutionEngine.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_ExecutionEngine_Smoke.mq5`

Note: `CExecutionEngine` depends on live MT5 trade context, so its unit harness is a **smoke-level compile test**: it constructs the class, calls `SetMagic`, `SetSymbol`, and a no-op `PlaceLimit(...)` on a disabled flag that short-circuits `OrderSend`. Full verification happens in the Task 5 manual EA walkthrough.

Commit message: `feat(mt5/core): add CExecutionEngine wrapping CTrade with retry and limit-order support`.

---

### Task 4: `CPositionManager`

Tracks open positions by magic + ticket, applies the unified exit and limited pyramiding.

**Files:**
- Create: `mt5/XAUUSD_Scalper/Include/Core/CPositionManager.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_PositionManager.mq5`

Exit state machine per position:

1. `STATE_OPEN` with full size and initial SL/TP.
2. When unrealized R ≥ +1.0, close 50 % (call `CExecutionEngine.ClosePartial(ticket, half_volume)`), set state to `STATE_PARTIAL_DONE`, move SL to `entry + small_buffer` (`small_buffer = 0.1` default, configurable).
3. After reaching `STATE_PARTIAL_DONE`, every tick recompute ATR trailing SL = `max(current_sl, bid − atr * trail_mult)` for longs; mirror for shorts. Set state to `STATE_TRAILING` once trailing actually tightens beyond breakeven+buffer.
4. Track bars-in-trade; if > `max_hold_bars` (default 60) still in `STATE_OPEN`, close remaining volume with reason `TIMEOUT`.

Pyramiding rules:

- Allow at most 2 additional positions (same direction, same strategy magic) per campaign.
- First add only when: current R ≥ +0.5, position is still `STATE_OPEN` → will be reclassified as a campaign head, new add gets identical SL/TP style from strategy but lot size from `CRiskManager` with adjusted `open_risk_ccy`.
- No pyramiding after: `MARKET_ABNORMAL`, `TrendConfirm` flip, daily loss hit, or cooldown.

Harness (deterministic, using a mock `CExecutionEngine`):

- 6 assertions covering each state transition and one pyramiding accept + one pyramiding reject.

Commit message: `feat(mt5/core): add CPositionManager with 4-stage exit and limited pyramiding`.

---

### Task 5: EA wiring — live trading on passed gates

**Files:**
- Modify: `mt5/XAUUSD_Scalper/Experts/XAUUSD_Scalper_EA.mq5`

Replace the Task 5 (P2) body with a version that, when `EvalStrategy` returns `allowed=true`:

1. Calls `CRiskManager.Size(...)` using strategy Kelly, `sl_per_lot_ccy = sl_distance * tick_value / tick_size`, and the ledger’s open-risk total.
2. On allowed: calls `CExecutionEngine.PlaceMarket(...)` or `PlaceLimit(...)` based on `state`, passes the result to `CPositionManager.OnFill(...)`.
3. On each tick calls `CPositionManager.Update(im, tc, mc, ts, /*bid*/, /*ask*/)` to progress the state machine.
4. When a position closes (callback from `CPositionManager`), call `CTradeLedger.OnTradeClosed(...)`.

All previous gate-logging from P2 stays.

Compile with `bash tools/compile.sh Experts/XAUUSD_Scalper/XAUUSD_Scalper_EA.mq5`, expect `ex5 OK`.

Commit message: `feat(mt5/ea): wire P3 risk-sized orders, unified exit, and limited pyramiding`.

---

### Task 6: P3 README green-gate

**Files:**
- Modify: `mt5/XAUUSD_Scalper/README.md`

Replace the `## P3 status` block with:

```markdown
## P3 status

Complete. Adds:

- `CTradeLedger` — in-memory per-strategy wins/losses/consec/daily loss.
- `CRiskManager` — 0.5 % base risk anchor × half-Kelly adjuster, with a
  hard 5 % total open-risk cap.
- `CExecutionEngine` — market + limit order support with retry, slippage
  tracking, and pending-order timeout.
- `CPositionManager` — 4-stage exit (partial TP 50 % at +1.0 R → breakeven
  → ATR trailing → timeout) and limited pyramiding (≤ 2 adds, gated on
  +0.5 R, no adds after abnormal/trend-flip/daily-loss/cooldown).
- EA wiring: gated signals now produce real MT5 orders on XAUUSD.

### P3 green-gate

- All `Test_*.mq5` from P1+P2+P3 compile `ex5 OK`.
- `Test_TradeLedger.mq5`, `Test_RiskManager.mq5`, `Test_PositionManager.mq5`
  print `passed=N failed=0`.
- EA on a demo XAUUSD account: ≥ 1 market or limit fill, the partial TP
  at +1.0 R triggers, breakeven SL move is visible in the Experts log,
  pyramiding add occurs at most twice per campaign, timeout exit closes
  stale positions.

### Not yet in P3

- Persistence: `trade_history.csv`, `decision_snapshots.csv`, `statistics.json`
- Full `CLogger` with daily rotation
- `CPerformanceTracker`, HTML report, `CDashboard`
- A/B harness toggles for Guard / TrendConfirm / UnifiedExit
```

Commit message: `docs(mt5): close P3 green-gate`.

---

## Self-Review

**Spec coverage:**

| Spec section | Covered in P3? | Where |
| --- | --- | --- |
| §5.3 order type by state + retry / timeout / partial fill | yes | Task 3 |
| §5.4 execution protection (retry, pause on runs of failures) | yes | Task 3 + 1 |
| §6.2 base risk anchor 0.5 % + 5 % total cap | yes | Task 2 |
| §6.3 half-Kelly within anchor | yes | Task 2 |
| §6.4 strategy + global position caps | yes | Task 4 |
| §6.5 4-stage unified exit | yes | Task 4 |
| §6.6 limited pyramiding | yes | Task 4 |
| §7.3-7.5 persistence | no — P4 |
| §8 analysis / reporting | no — P4 |

**Placeholder scan:** all thresholds have defaults or source from inputs. Harness expectations list assertion counts explicitly.

**Type consistency:**

- `ENUM_MARKET_STATE` reused from P1/P2.
- `ENUM_GUARD_REASON` reused from P2.
- `GuardInputs.consec_losses`, `GuardInputs.daily_loss_pct`, `GuardInputs.last_fail_time` now sourced from `CTradeLedger` (fields already typed identically in P2).
- `CStrategyBase::CalculateKellyFraction(min_trades, cold_p, cold_b)` feeds `RiskInputs.kelly_fraction` directly.
- `CPositionManager` state enum (`STATE_OPEN / STATE_PARTIAL_DONE / STATE_TRAILING / STATE_CLOSED`) introduced in Task 4 and consumed only by that class; no cross-task drift.

No drift detected.
