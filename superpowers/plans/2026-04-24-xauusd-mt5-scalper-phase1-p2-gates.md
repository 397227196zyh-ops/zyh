# XAUUSD MT5 Scalper Phase 1 — P2 Session / Execution Guard / Trend Confirm Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **In this repo dispatched subagents MUST include the "NOT ALLOWED" fence from the task prompt; controller verifies `git diff` after every return.**

**Goal:** Wire the 3 gating layers required before order execution — `CSessionFilter`, `CExecutionGuard`, and `CTrendConfirm` — and extend `CMarketAnalyzer` with a rolling context so the EA can declare, per strategy signal, whether the trade would be allowed. No orders are sent in P2. The EA must log every reject reason in a deterministic, machine-readable form.

**Architecture:** Each gate is a pure MQL5 class with deterministic inputs and one `Evaluate` / `IsOpen` / `Classify` entry point. A new `GateDecision` struct aggregates the per-signal result; the EA populates it each tick and writes it to the Expert log. All thresholds are external `input` parameters with ECN-friendly defaults; the spec’s note about "configurable for a normal standard account" is covered by keeping every threshold exposed.

**Tech Stack:** MetaTrader 5 / MQL5, MetaEditor build 3815+, existing `CTestRunner` harness from P1.

---

## P2 Scope

P2 adds:

1. `CSessionFilter` — Monday–Friday session windows (London + New York), with configurable server time and overlap.
2. `CMarketContext` — rolling ATR average, ADX average, breakout counter, and last-state memory; replaces the P1 placeholder in `OnTick`.
3. `CExecutionGuard` — single `Evaluate(input)` returning a `GuardDecision` with a reject-code enum.
4. `CTrendConfirm` — M5 trend state classifier and per-strategy pass/fail rules.
5. EA wiring that consumes all four layers and logs a `GateDecision` per strategy per tick.

P2 does NOT add: order sending, position manager, risk manager, pyramiding, persistence, performance tracker, HTML report, dashboard. Those ship in P3/P4.

P2 ends green when:

- Every new `.mqh` / `.mq5` compiles via `tools/compile.sh` with `ex5 OK` and no log diagnostics.
- Every new harness under `Scripts/Tests/Test_*.mq5` prints `passed=N failed=0` for its N asserts.
- The EA, attached to XAUUSD M1, emits at least one `[INF] gate | strat=<EMA|BOLL|RSI> dir=<...> session=<1|0> guard=<0|code> trend=<B|S|N> allowed=<0|1> reason=<...>` line per tick and no runtime error.

---

### Task 0: P2 branch checkpoint

**Files:**
- Modify: `mt5/XAUUSD_Scalper/README.md`

- [ ] **Step 1: Record P2 start**

Append a new `## P2 status` section at the end of the file:

```markdown
## P2 status

In progress — adds `CSessionFilter`, `CMarketContext`, `CExecutionGuard`,
`CTrendConfirm`, and gated `OnTick` logging.
```

- [ ] **Step 2: Commit**

```bash
git -C "/c/Users/Administrator/docs" add mt5/XAUUSD_Scalper/README.md
git -C "/c/Users/Administrator/docs" commit -m "docs(mt5): open P2 status section"
```

---

### Task 1: `CSessionFilter`

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Core/CSessionFilter.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_SessionFilter.mq5`

- [ ] **Step 1: Harness (fails: CSessionFilter undeclared)**

`Test_SessionFilter.mq5`:

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CSessionFilter.mqh>

datetime mk(const int h, const int m, const int dow)
{
   MqlDateTime d; d.year=2026; d.mon=4; d.day=20+dow; d.hour=h; d.min=m; d.sec=0; d.day_of_year=0; d.day_of_week=dow;
   return StructToTime(d);
}

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_SessionFilter");

   CSessionFilter sf;
   sf.Configure(/*lon_start*/ 7, /*lon_end*/ 16, /*ny_start*/ 13, /*ny_end*/ 22);

   tr.AssertTrue ("monday 09:00 (london)",  sf.IsOpen(mk(9, 0, 1)));
   tr.AssertTrue ("monday 14:30 (london+ny)",sf.IsOpen(mk(14,30,1)));
   tr.AssertTrue ("monday 21:00 (ny)",       sf.IsOpen(mk(21, 0,1)));
   tr.AssertFalse("monday 03:00 (asia)",     sf.IsOpen(mk( 3, 0,1)));
   tr.AssertFalse("saturday 10:00",          sf.IsOpen(mk(10, 0,6)));
   tr.AssertFalse("sunday 10:00",            sf.IsOpen(mk(10, 0,0)));

   tr.End();
}
```

- [ ] **Step 2: Implementation**

`CSessionFilter.mqh`:

```mql5
#ifndef __XAUUSD_SCALPER_SESSION_FILTER_MQH__
#define __XAUUSD_SCALPER_SESSION_FILTER_MQH__

class CSessionFilter
  {
private:
   int               m_lon_start_h;
   int               m_lon_end_h;
   int               m_ny_start_h;
   int               m_ny_end_h;

public:
                     CSessionFilter() : m_lon_start_h(7), m_lon_end_h(16),
                                        m_ny_start_h(13), m_ny_end_h(22) {}

   void              Configure(const int lon_start, const int lon_end,
                               const int ny_start,  const int ny_end)
     {
      m_lon_start_h = lon_start; m_lon_end_h = lon_end;
      m_ny_start_h  = ny_start;  m_ny_end_h  = ny_end;
     }

   bool              IsOpen(const datetime server_time) const
     {
      MqlDateTime d; TimeToStruct(server_time, d);
      if(d.day_of_week == 0 || d.day_of_week == 6) return false;
      const int h = d.hour;
      const bool in_lon = h >= m_lon_start_h && h < m_lon_end_h;
      const bool in_ny  = h >= m_ny_start_h  && h < m_ny_end_h;
      return in_lon || in_ny;
     }
  };

#endif // __XAUUSD_SCALPER_SESSION_FILTER_MQH__
```

- [ ] **Step 3: Compile & commit**

```bash
cd /c/Users/Administrator/docs/mt5/XAUUSD_Scalper
bash tools/deploy.sh
bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_SessionFilter.mq5
git -C /c/Users/Administrator/docs add \
  mt5/XAUUSD_Scalper/Include/Core/CSessionFilter.mqh \
  mt5/XAUUSD_Scalper/Scripts/Tests/Test_SessionFilter.mq5
git -C /c/Users/Administrator/docs commit -m "feat(mt5/core): add CSessionFilter London/NY window with weekend guard"
```

---

### Task 2: `CMarketContext` rolling state

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Core/CMarketContext.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_MarketContext.mq5`

`CMarketContext` holds a 50-sample rolling average over ATR, a 20-bar breakout counter, and a latched `ENUM_MARKET_STATE` with hysteresis. The EA calls `OnBar(im, tc)` once per new M1 bar close and `OnTick(im, tc)` every tick; the rolling state is kept in memory and never recomputed from scratch.

- [ ] **Step 1: Harness**

`Test_MarketContext.mq5`:

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CMarketContext.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_MarketContext");

   CMarketContext ctx; ctx.Init(50, 20);

   // Feed 50 ATR samples of 0.5; average = 0.5
   for(int i=0;i<50;i++) ctx.PushATRSample(0.5);
   tr.AssertEqualDouble("atr avg 0.5", 0.5, ctx.ATRAverage(), 1e-9);

   // Replace with higher ATR values gradually; avg should trend up
   for(int i=0;i<50;i++) ctx.PushATRSample(1.0);
   tr.AssertEqualDouble("atr avg 1.0 after saturation", 1.0, ctx.ATRAverage(), 1e-9);

   // Breakouts
   ctx.PushBreakout();
   ctx.PushBreakout();
   tr.AssertEqualInt("breakouts 2", 2, (long)ctx.BreakoutCount());

   // Classify via analyzer input builder
   MarketInputs mi = ctx.BuildInputs(/*adx*/30, /*atr*/1.2, /*bb_width*/2.2,
                                     /*last_spread*/0.05, /*max_jump*/0.10,
                                     /*ticks_per_s*/12.0);
   tr.AssertTrue("inputs atr_avg=1.0", MathAbs(mi.atr_avg - 1.0) < 1e-9);

   tr.End();
}
```

- [ ] **Step 2: Implementation**

`CMarketContext.mqh`:

```mql5
#ifndef __XAUUSD_SCALPER_MARKET_CONTEXT_MQH__
#define __XAUUSD_SCALPER_MARKET_CONTEXT_MQH__

#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

class CMarketContext
  {
private:
   double            m_atr_ring[];
   int               m_atr_cap;
   int               m_atr_size;
   int               m_atr_head;
   double            m_atr_sum;

   int               m_breakout_win;
   int               m_breakouts[];

public:
                     CMarketContext() : m_atr_cap(0), m_atr_size(0), m_atr_head(0), m_atr_sum(0), m_breakout_win(0) {}

   void              Init(const int atr_window, const int breakout_window)
     {
      m_atr_cap = atr_window > 0 ? atr_window : 50;
      ArrayResize(m_atr_ring, m_atr_cap);
      m_atr_size = 0; m_atr_head = 0; m_atr_sum = 0.0;
      m_breakout_win = breakout_window > 0 ? breakout_window : 20;
      ArrayResize(m_breakouts, 0);
     }

   void              PushATRSample(const double v)
     {
      if(m_atr_size < m_atr_cap) { m_atr_ring[m_atr_head] = v; m_atr_head = (m_atr_head + 1) % m_atr_cap; m_atr_size++; m_atr_sum += v; return; }
      double old = m_atr_ring[m_atr_head];
      m_atr_ring[m_atr_head] = v;
      m_atr_head = (m_atr_head + 1) % m_atr_cap;
      m_atr_sum += (v - old);
     }

   double            ATRAverage() const { return m_atr_size > 0 ? m_atr_sum / (double)m_atr_size : 0.0; }

   void              PushBreakout()
     {
      int n = ArraySize(m_breakouts);
      ArrayResize(m_breakouts, n + 1);
      m_breakouts[n] = 1;
      if(ArraySize(m_breakouts) > m_breakout_win)
        {
         for(int i=0;i<ArraySize(m_breakouts)-m_breakout_win;i++) { /* shift handled below */ }
         int drop = ArraySize(m_breakouts) - m_breakout_win;
         for(int i=0;i<m_breakout_win;i++) m_breakouts[i] = m_breakouts[i+drop];
         ArrayResize(m_breakouts, m_breakout_win);
        }
     }

   int               BreakoutCount() const
     {
      int n = ArraySize(m_breakouts);
      int s = 0;
      for(int i=0;i<n;i++) s += m_breakouts[i];
      return s;
     }

   MarketInputs      BuildInputs(const double adx, const double atr, const double bb_width,
                                 const double last_spread, const double max_jump,
                                 const double ticks_per_s) const
     {
      MarketInputs mi;
      mi.adx         = adx;
      mi.atr         = atr;
      mi.atr_avg     = ATRAverage();
      mi.bb_width    = bb_width;
      mi.last_spread = last_spread;
      mi.max_jump    = max_jump;
      mi.ticks_per_s = ticks_per_s;
      mi.breakouts   = BreakoutCount();
      return mi;
     }
  };

#endif // __XAUUSD_SCALPER_MARKET_CONTEXT_MQH__
```

- [ ] **Step 3: Compile & commit**

```bash
cd /c/Users/Administrator/docs/mt5/XAUUSD_Scalper
bash tools/deploy.sh
bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_MarketContext.mq5
git -C /c/Users/Administrator/docs add \
  mt5/XAUUSD_Scalper/Include/Core/CMarketContext.mqh \
  mt5/XAUUSD_Scalper/Scripts/Tests/Test_MarketContext.mq5
git -C /c/Users/Administrator/docs commit -m "feat(mt5/core): add CMarketContext rolling ATR average and breakout window"
```

---

### Task 3: `CExecutionGuard`

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Core/CExecutionGuard.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_ExecutionGuard.mq5`

- [ ] **Step 1: Harness**

`Test_ExecutionGuard.mq5`:

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CExecutionGuard.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_ExecutionGuard");

   CExecutionGuard g;
   g.Configure(/*max_spread*/0.08, /*max_stop_level*/0.1, /*cool_off_sec*/60,
               /*daily_loss_limit_pct*/2.0, /*consec_loss_limit*/5);

   GuardInputs in;
   in.session_open   = true;
   in.spread         = 0.05;
   in.stops_level    = 0.02;
   in.freeze_level   = 0.01;
   in.market_state   = MARKET_TRENDING;
   in.now            = (datetime)1000;
   in.last_fail_time = 0;
   in.daily_loss_pct = 0.0;
   in.consec_losses  = 0;

   GuardDecision d = g.Evaluate(in);
   tr.AssertTrue("all good -> allowed",                   d.allowed);
   tr.AssertEqualInt("reason_code NONE",                  (int)GUARD_OK, (int)d.reason);

   in.session_open = false;
   d = g.Evaluate(in);
   tr.AssertEqualInt("session closed -> SESSION",         (int)GUARD_SESSION_CLOSED, (int)d.reason);

   in.session_open = true; in.spread = 0.20;
   d = g.Evaluate(in);
   tr.AssertEqualInt("spread high -> SPREAD",             (int)GUARD_SPREAD, (int)d.reason);

   in.spread = 0.05; in.market_state = MARKET_ABNORMAL;
   d = g.Evaluate(in);
   tr.AssertEqualInt("abnormal state -> ABNORMAL",        (int)GUARD_ABNORMAL_MARKET, (int)d.reason);

   in.market_state = MARKET_TRENDING; in.consec_losses = 10;
   d = g.Evaluate(in);
   tr.AssertEqualInt("consec losses -> CONSEC",           (int)GUARD_CONSEC_LOSSES, (int)d.reason);

   in.consec_losses = 0; in.daily_loss_pct = 5.0;
   d = g.Evaluate(in);
   tr.AssertEqualInt("daily loss -> DAILY",               (int)GUARD_DAILY_LOSS, (int)d.reason);

   in.daily_loss_pct = 0.0; in.last_fail_time = 995; in.now = 1000;
   d = g.Evaluate(in);
   tr.AssertEqualInt("cooldown -> COOLDOWN",              (int)GUARD_COOLDOWN, (int)d.reason);

   tr.End();
}
```

- [ ] **Step 2: Implementation**

`CExecutionGuard.mqh`:

```mql5
#ifndef __XAUUSD_SCALPER_EXECUTION_GUARD_MQH__
#define __XAUUSD_SCALPER_EXECUTION_GUARD_MQH__

#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

enum ENUM_GUARD_REASON
  {
   GUARD_OK               = 0,
   GUARD_SESSION_CLOSED   = 1,
   GUARD_SPREAD           = 2,
   GUARD_STOPS_LEVEL      = 3,
   GUARD_ABNORMAL_MARKET  = 4,
   GUARD_COOLDOWN         = 5,
   GUARD_CONSEC_LOSSES    = 6,
   GUARD_DAILY_LOSS       = 7
  };

struct GuardInputs
  {
   bool              session_open;
   double            spread;
   double            stops_level;
   double            freeze_level;
   ENUM_MARKET_STATE market_state;
   datetime          now;
   datetime          last_fail_time;
   double            daily_loss_pct;
   int               consec_losses;
  };

struct GuardDecision
  {
   bool              allowed;
   ENUM_GUARD_REASON reason;
  };

class CExecutionGuard
  {
private:
   double            m_max_spread;
   double            m_max_stop_level;
   int               m_cool_off_sec;
   double            m_daily_loss_limit_pct;
   int               m_consec_loss_limit;

public:
                     CExecutionGuard() : m_max_spread(0.08), m_max_stop_level(0.1),
                                         m_cool_off_sec(60), m_daily_loss_limit_pct(2.0),
                                         m_consec_loss_limit(5) {}

   void              Configure(const double max_spread, const double max_stop_level,
                               const int cool_off_sec,  const double daily_loss_limit_pct,
                               const int consec_loss_limit)
     {
      m_max_spread = max_spread; m_max_stop_level = max_stop_level;
      m_cool_off_sec = cool_off_sec;
      m_daily_loss_limit_pct = daily_loss_limit_pct;
      m_consec_loss_limit = consec_loss_limit;
     }

   GuardDecision     Evaluate(const GuardInputs &in) const
     {
      GuardDecision d; d.allowed = false; d.reason = GUARD_OK;
      if(!in.session_open)                              { d.reason = GUARD_SESSION_CLOSED;  return d; }
      if(in.spread > m_max_spread)                      { d.reason = GUARD_SPREAD;          return d; }
      if(in.stops_level > m_max_stop_level ||
         in.freeze_level > m_max_stop_level)            { d.reason = GUARD_STOPS_LEVEL;     return d; }
      if(in.market_state == MARKET_ABNORMAL)            { d.reason = GUARD_ABNORMAL_MARKET; return d; }
      if(in.consec_losses >= m_consec_loss_limit)       { d.reason = GUARD_CONSEC_LOSSES;   return d; }
      if(in.daily_loss_pct >= m_daily_loss_limit_pct)   { d.reason = GUARD_DAILY_LOSS;      return d; }
      if(in.last_fail_time != 0 &&
         in.now - in.last_fail_time < m_cool_off_sec)   { d.reason = GUARD_COOLDOWN;        return d; }
      d.allowed = true;
      return d;
     }
  };

#endif // __XAUUSD_SCALPER_EXECUTION_GUARD_MQH__
```

- [ ] **Step 3: Compile & commit**

```bash
cd /c/Users/Administrator/docs/mt5/XAUUSD_Scalper
bash tools/deploy.sh
bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_ExecutionGuard.mq5
git -C /c/Users/Administrator/docs add \
  mt5/XAUUSD_Scalper/Include/Core/CExecutionGuard.mqh \
  mt5/XAUUSD_Scalper/Scripts/Tests/Test_ExecutionGuard.mq5
git -C /c/Users/Administrator/docs commit -m "feat(mt5/core): add CExecutionGuard with session/spread/stops/cooldown/loss rules"
```

---

### Task 4: `CTrendConfirm`

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Core/CTrendConfirm.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_TrendConfirm.mq5`

- [ ] **Step 1: Harness**

`Test_TrendConfirm.mq5`:

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CTrendConfirm.mqh>

class FakeIM2 : public CIndicatorManager
  {
public:
   double e20_m5[3];
   double e50_m5;
   virtual double EMA20_M5(const int s) const override { return e20_m5[s]; }
   virtual double EMA50_M5(const int s) const override { return e50_m5; }
  };

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_TrendConfirm");

   FakeIM2 im; im.e50_m5 = 2399.00; im.e20_m5[0]=2400.5; im.e20_m5[1]=2400.2; im.e20_m5[2]=2400.0;
   CTrendConfirm tc;

   tr.AssertEqualInt("bullish M5", (int)TREND_BULLISH,  (int)tc.Classify(im, /*bid*/2400.60));
   im.e50_m5 = 2401.00; im.e20_m5[0]=2399.5; im.e20_m5[1]=2399.7; im.e20_m5[2]=2399.9;
   tr.AssertEqualInt("bearish M5", (int)TREND_BEARISH,  (int)tc.Classify(im, /*bid*/2399.40));
   im.e50_m5 = 2400.00; im.e20_m5[0]=2400.05; im.e20_m5[1]=2400.00; im.e20_m5[2]=2400.00;
   tr.AssertEqualInt("neutral M5", (int)TREND_NEUTRAL,  (int)tc.Classify(im, /*bid*/2400.02));

   // Per-strategy pass rules
   tr.AssertTrue ("EMA bullish+BUY passes",  tc.Allows("EMA",  SIGNAL_BUY,  TREND_BULLISH, 2400.02, 2400.00));
   tr.AssertFalse("EMA bearish+BUY rejects", tc.Allows("EMA",  SIGNAL_BUY,  TREND_BEARISH, 2400.02, 2400.00));
   tr.AssertTrue ("BOLL bullish+BUY passes", tc.Allows("BOLL", SIGNAL_BUY,  TREND_BULLISH, 2400.02, 2400.00));
   tr.AssertFalse("BOLL neutral+BUY rejects",tc.Allows("BOLL", SIGNAL_BUY,  TREND_NEUTRAL, 2400.02, 2400.00));
   tr.AssertTrue ("RSI neutral+BUY passes",  tc.Allows("RSI",  SIGNAL_BUY,  TREND_NEUTRAL, 2400.02, 2400.00));
   tr.AssertFalse("RSI bearish+BUY rejects", tc.Allows("RSI",  SIGNAL_BUY,  TREND_BEARISH, 2400.02, 2400.00));

   tr.End();
}
```

- [ ] **Step 2: Implementation**

`CTrendConfirm.mqh`:

```mql5
#ifndef __XAUUSD_SCALPER_TREND_CONFIRM_MQH__
#define __XAUUSD_SCALPER_TREND_CONFIRM_MQH__

#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

enum ENUM_TREND_STATE
  {
   TREND_NEUTRAL = 0,
   TREND_BULLISH = 1,
   TREND_BEARISH = 2
  };

class CTrendConfirm
  {
private:
   double            m_far_threshold;

public:
                     CTrendConfirm() : m_far_threshold(1.0) {}

   void              Configure(const double far_threshold) { m_far_threshold = far_threshold; }

   ENUM_TREND_STATE  Classify(const CIndicatorManager &im, const double bid) const
     {
      double e20_0 = im.EMA20_M5(0);
      double e20_1 = im.EMA20_M5(1);
      double e20_2 = im.EMA20_M5(2);
      double e50   = im.EMA50_M5(0);
      if(e20_0 > e50 && e20_0 > e20_1 && e20_1 > e20_2 && bid > e20_0) return TREND_BULLISH;
      if(e20_0 < e50 && e20_0 < e20_1 && e20_1 < e20_2 && bid < e20_0) return TREND_BEARISH;
      return TREND_NEUTRAL;
     }

   bool              Allows(const string strat_name, const ENUM_SIGNAL_DIRECTION dir,
                            const ENUM_TREND_STATE  state,
                            const double bid, const double ema20_m5) const
     {
      if(dir == SIGNAL_NONE) return false;
      if(strat_name == "EMA")
        {
         if(dir == SIGNAL_BUY)  return state == TREND_BULLISH || state == TREND_NEUTRAL;
         if(dir == SIGNAL_SELL) return state == TREND_BEARISH || state == TREND_NEUTRAL;
        }
      else if(strat_name == "BOLL")
        {
         if(dir == SIGNAL_BUY)  return state == TREND_BULLISH;
         if(dir == SIGNAL_SELL) return state == TREND_BEARISH;
        }
      else if(strat_name == "RSI")
        {
         double dist = MathAbs(bid - ema20_m5);
         if(dir == SIGNAL_BUY)
           {
            if(state == TREND_BEARISH) return false;
            if(state == TREND_BULLISH) return dist <= m_far_threshold;
            return true;
           }
         if(dir == SIGNAL_SELL)
           {
            if(state == TREND_BULLISH) return false;
            if(state == TREND_BEARISH) return dist <= m_far_threshold;
            return true;
           }
        }
      return false;
     }
  };

#endif // __XAUUSD_SCALPER_TREND_CONFIRM_MQH__
```

- [ ] **Step 3: Compile & commit**

```bash
cd /c/Users/Administrator/docs/mt5/XAUUSD_Scalper
bash tools/deploy.sh
bash tools/compile.sh Scripts/XAUUSD_Scalper/Tests/Test_TrendConfirm.mq5
git -C /c/Users/Administrator/docs add \
  mt5/XAUUSD_Scalper/Include/Core/CTrendConfirm.mqh \
  mt5/XAUUSD_Scalper/Scripts/Tests/Test_TrendConfirm.mq5
git -C /c/Users/Administrator/docs commit -m "feat(mt5/core): add CTrendConfirm with M5 trend state and per-strategy pass rules"
```

---

### Task 5: EA wiring with gated logging

Replace the P1 `OnTick` pipeline so that each strategy emits a `GateDecision` line before any signal could become an order. No order is placed yet.

**Files:**

- Modify: `mt5/XAUUSD_Scalper/Experts/XAUUSD_Scalper_EA.mq5`

- [ ] **Step 1: New EA body**

Replace the file content with:

```mql5
#property strict
#property description "XAUUSD Scalper Phase 1 - P2 gated signals"

#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>
#include <XAUUSD_Scalper/Core/CMarketContext.mqh>
#include <XAUUSD_Scalper/Core/CSessionFilter.mqh>
#include <XAUUSD_Scalper/Core/CExecutionGuard.mqh>
#include <XAUUSD_Scalper/Core/CTrendConfirm.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBollinger.mqh>
#include <XAUUSD_Scalper/Core/CStrategyRSI.mqh>
#include <XAUUSD_Scalper/Analysis/CLoggerStub.mqh>

input bool   InpEnableEMA        = true;
input bool   InpEnableBoll       = true;
input bool   InpEnableRSI        = true;
input int    InpTickBuffer       = 10000;
input int    InpLonStartHour     = 7;
input int    InpLonEndHour       = 16;
input int    InpNYStartHour      = 13;
input int    InpNYEndHour        = 22;
input double InpMaxSpread        = 0.08;
input double InpMaxStopLevel     = 0.1;
input int    InpCoolOffSec       = 60;
input double InpDailyLossLimit   = 2.0;
input int    InpConsecLossLimit  = 5;
input double InpTrendFarThresh   = 1.0;

CTickCollector     g_tc;
CIndicatorManager  g_im;
CMarketContext     g_mc;
CSessionFilter     g_sf;
CExecutionGuard    g_eg;
CTrendConfirm      g_tcf;
CStrategyEMA       g_sema;
CStrategyBollinger g_sboll;
CStrategyRSI       g_srsi;
CLoggerStub        g_log;

datetime g_last_fail_time = 0;

int OnInit()
{
   g_tc.Init(InpTickBuffer);
   if(!g_im.Init(_Symbol))
     { g_log.Error("init", "indicator manager init failed"); return INIT_FAILED; }
   g_mc.Init(50, 20);
   g_sf.Configure(InpLonStartHour, InpLonEndHour, InpNYStartHour, InpNYEndHour);
   g_eg.Configure(InpMaxSpread, InpMaxStopLevel, InpCoolOffSec, InpDailyLossLimit, InpConsecLossLimit);
   g_tcf.Configure(InpTrendFarThresh);
   g_log.Info("init", "Init OK");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_im.Shutdown();
   g_log.Info("deinit", StringFormat("reason=%d", reason));
}

void LogGate(const string strat, const ENUM_SIGNAL_DIRECTION dir,
             const bool session_open, const GuardDecision gd,
             const ENUM_TREND_STATE ts, const bool allowed, const string reason)
{
   g_log.Info("gate",
      StringFormat("strat=%s dir=%d session=%d guard=%d trend=%d allowed=%d reason=%s",
                   strat, (int)dir, session_open ? 1 : 0,
                   (int)gd.reason, (int)ts, allowed ? 1 : 0, reason));
}

void EvalStrategy(const string name, CStrategyBase &s, const StrategyContext &ctx,
                  const bool session_open, const GuardDecision gd, const ENUM_TREND_STATE ts,
                  const double ema20_m5)
{
   SignalResult r = s.CheckSignal(ctx);
   if(!session_open)          { LogGate(name, r.direction, session_open, gd, ts, false, "SESSION"); return; }
   if(!gd.allowed)            { LogGate(name, r.direction, session_open, gd, ts, false, EnumToString(gd.reason)); return; }
   if(r.direction == SIGNAL_NONE) { LogGate(name, r.direction, session_open, gd, ts, false, "NO_SIGNAL"); return; }
   bool trend_ok = g_tcf.Allows(name, r.direction, ts, ctx.bid, ema20_m5);
   if(!trend_ok)              { LogGate(name, r.direction, session_open, gd, ts, false, "TREND"); return; }
   LogGate(name, r.direction, session_open, gd, ts, true, "PASS");
}

void OnTick()
{
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   g_tc.OnTick(t);
   g_im.Update();

   // Push per-tick ATR sample into rolling context
   g_mc.PushATRSample(g_im.ATR(0));

   MarketInputs mi = g_mc.BuildInputs(g_im.ADX(0), g_im.ATR(0), g_im.BBWidth(0),
                                      g_tc.LastSpread(), g_tc.MaxJump(),
                                      g_tc.TicksPerSecondEstimate());
   ENUM_MARKET_STATE state = CMarketAnalyzer::Classify(mi);

   const bool session_open = g_sf.IsOpen(t.time);

   GuardInputs gin;
   gin.session_open   = session_open;
   gin.spread         = g_tc.LastSpread();
   gin.stops_level    = 0.0;
   gin.freeze_level   = 0.0;
   gin.market_state   = state;
   gin.now            = t.time;
   gin.last_fail_time = g_last_fail_time;
   gin.daily_loss_pct = 0.0;
   gin.consec_losses  = 0;
   GuardDecision gd = g_eg.Evaluate(gin);

   const ENUM_TREND_STATE ts = g_tcf.Classify(g_im, t.bid);

   StrategyContext ctx; ctx.im = &g_im; ctx.tc = &g_tc; ctx.state = state;
   ctx.bid = t.bid; ctx.ask = t.ask; ctx.time = t.time;

   if(InpEnableEMA)  EvalStrategy("EMA",  g_sema,  ctx, session_open, gd, ts, g_im.EMA20_M5(0));
   if(InpEnableBoll) EvalStrategy("BOLL", g_sboll, ctx, session_open, gd, ts, g_im.EMA20_M5(0));
   if(InpEnableRSI)  EvalStrategy("RSI",  g_srsi,  ctx, session_open, gd, ts, g_im.EMA20_M5(0));
}
```

- [ ] **Step 2: Compile & commit**

```bash
cd /c/Users/Administrator/docs/mt5/XAUUSD_Scalper
bash tools/deploy.sh
bash tools/compile.sh Experts/XAUUSD_Scalper/XAUUSD_Scalper_EA.mq5
git -C /c/Users/Administrator/docs add mt5/XAUUSD_Scalper/Experts/XAUUSD_Scalper_EA.mq5
git -C /c/Users/Administrator/docs commit -m "feat(mt5/ea): wire P2 session+guard+trend gates and log per-strategy GateDecision"
```

---

### Task 6: P2 README green-gate

**Files:**

- Modify: `mt5/XAUUSD_Scalper/README.md`

- [ ] **Step 1: Replace the `## P2 status` section**

Replace the previous `## P2 status` block (added in Task 0) with:

```markdown
## P2 status

Complete. Adds:

- `CSessionFilter` — London/NY weekday windows.
- `CMarketContext` — rolling ATR average + breakout window.
- `CExecutionGuard` — spread / stops / cooldown / daily-loss / consec-loss /
  abnormal-market / session-closed rejection with explicit reason codes.
- `CTrendConfirm` — M5 trend state and per-strategy allow rules
  (`EMA` allows neutral, `BOLL` requires same-direction trend, `RSI` rejects
  counter-trend and requires proximity to M5 EMA20 in same-direction trend).
- Gated `OnTick` logging: one `[INF] gate | strat=... dir=... session=...
  guard=... trend=... allowed=... reason=...` line per strategy per tick.

### P2 green-gate

All must hold before starting P3:

- `bash tools/compile.sh` prints `ex5 OK` for every new `Scripts/Tests/Test_*.mq5`.
- `Test_SessionFilter.mq5` prints `passed=6 failed=0`.
- `Test_MarketContext.mq5` prints `passed=4 failed=0`.
- `Test_ExecutionGuard.mq5` prints `passed=7 failed=0`.
- `Test_TrendConfirm.mq5` prints `passed=9 failed=0`.
- The EA on XAUUSD M1 emits `[INF] gate | ...` for each of EMA/BOLL/RSI.

### Not yet in P2

- Order placement, risk manager, Kelly with base-risk anchor
- Position manager (partial TP, breakeven, ATR trailing, timeout exit)
- Limited pyramiding
- Persistence and reporting
```

- [ ] **Step 2: Commit**

```bash
git -C /c/Users/Administrator/docs add mt5/XAUUSD_Scalper/README.md
git -C /c/Users/Administrator/docs commit -m "docs(mt5): close P2 green-gate"
```

---

## Self-Review

**Spec coverage:**

| Spec section | Covered | Where |
| --- | --- | --- |
| §2.2 run flow with SessionFilter + ExecutionGuard + TrendConfirm | yes | Tasks 1, 3, 4, 5 |
| §3.7 M5 trend confirm per-strategy rules | yes | Task 4 |
| §4.3 abnormal market piping into Guard | yes | Task 3 reason `GUARD_ABNORMAL_MARKET` |
| §5.1 session filter London/NY weekday only | yes | Task 1 |
| §5.2 Guard: spread/stops/freeze/cooldown/daily loss/consec loss/abnormal/session | yes | Task 3 |
| §5.3 order type selection by state | deferred to P3 (no orders in P2) |
| §6 risk/position mgmt | deferred to P3 |
| §7.3-7.5 persistence | deferred to P4 |
| §8 analysis | deferred to P4 |

**Placeholder scan:** no `TBD`, every step contains the exact code/text needed.

**Type consistency:**

- `MarketInputs` reused from P1 in Tasks 2 and 3.
- `ENUM_MARKET_STATE` reused in Tasks 3 and 5.
- `ENUM_SIGNAL_DIRECTION` reused in Tasks 4 and 5.
- `CIndicatorManager::EMA20_M5 / EMA50_M5 (int shift)` already present and virtual from P1 Task 4.
- `CStrategyBase::CheckSignal` unchanged.

No drift detected.
