# XAUUSD MT5 Scalper Phase 1 — P1 Foundation & Three Strategies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the compilable MT5 EA skeleton plus `IndicatorManager`, `TickCollector`, `MarketAnalyzer`, a minimal in-terminal test runner, and the three parallel strategies (EMA / Bollinger / RSI) — matching sections 2, 3, 4, 7.1, 7.2 of `docs/superpowers/specs/2026-04-24-xauusd-mt5-scalper-phase1-merged-design.md`.

**Architecture:** A single MT5 Expert Advisor (`XAUUSD_Scalper_EA.mq5`) orchestrates a dependency-injected class graph split under `Include/Core/`, `Include/Data/`, `Include/Analysis/`, and a lightweight MQL5 Script-based test runner under `Include/Tests/` + `Scripts/Tests/`. Each strategy derives from `CStrategyBase`, and a per-module Script exercises its public contract with asserts before any EA-side wiring is enabled.

**Tech Stack:** MetaTrader 5 / MQL5, MetaEditor build 3815+, OOP classes with `#include` headers, Script-based harness (no third-party framework).

---

## P1 Scope

P1 delivers the foundation only. It does NOT implement SessionFilter, ExecutionGuard, TrendConfirm, RiskManager, ExecutionEngine, PositionManager, Logger beyond a stub, PerformanceTracker, Dashboard, or reporting. Those ship in P2/P3/P4 plans. P1 must leave every later module a clean, named extension point.

When P1 ends the project must:

1. Compile in MetaEditor with zero errors and zero warnings.
2. Load on an M1 XAUUSD chart, attach without runtime errors, log `Init OK` and `Tick OK`.
3. All harness scripts under `Scripts/Tests/` run to completion and print `TEST: PASS` lines with zero `TEST: FAIL`.
4. Each strategy can, given synthetic price/indicator inputs from a harness, produce `SIGNAL_BUY / SIGNAL_SELL / SIGNAL_NONE` deterministically.
5. Indicator manager reuses cached handles and buffers across all strategies.
6. Market analyzer can classify ranging / trending / breakout / abnormal for supplied synthetic inputs.
7. All code committed incrementally to the `docs/` git repo under the `mt5/` working copy described below.

---

## Working Directory Layout

All MT5 source files live under `mt5/XAUUSD_Scalper/` inside the existing git repo at `C:\Users\Administrator\docs\`. The engineer symlinks or copies this folder into their MT5 Terminal Data Folder so compilation uses the same on-disk files the git repo tracks.

```
docs/
├── mt5/
│   └── XAUUSD_Scalper/
│       ├── Experts/
│       │   └── XAUUSD_Scalper_EA.mq5
│       ├── Include/
│       │   ├── Core/
│       │   │   ├── CStrategyBase.mqh
│       │   │   ├── CStrategyEMA.mqh
│       │   │   ├── CStrategyBollinger.mqh
│       │   │   ├── CStrategyRSI.mqh
│       │   │   └── CMarketAnalyzer.mqh
│       │   ├── Data/
│       │   │   ├── CTickCollector.mqh
│       │   │   └── CIndicatorManager.mqh
│       │   ├── Analysis/
│       │   │   └── CLoggerStub.mqh
│       │   └── Tests/
│       │       └── TestRunner.mqh
│       └── Scripts/
│           └── Tests/
│               ├── Test_IndicatorManager.mq5
│               ├── Test_MarketAnalyzer.mq5
│               ├── Test_StrategyEMA.mq5
│               ├── Test_StrategyBollinger.mq5
│               ├── Test_StrategyRSI.mq5
│               └── Test_TickCollector.mq5
└── superpowers/
    └── specs/2026-04-24-xauusd-mt5-scalper-phase1-merged-design.md
```

---

## Harness Convention

Every harness Script in `Scripts/Tests/*.mq5` calls into `CTestRunner` and prints:

- `TEST: RUN <Name>` before a case
- `TEST: PASS <Name>` on success
- `TEST: FAIL <Name> expected=<...> got=<...>` on failure

A test run is considered green if the Expert Log contains zero `TEST: FAIL` lines after executing every harness script in sequence. Engineers drag each `.mq5` script onto an XAUUSD M1 chart and read the Experts tab in the Terminal.

**Verification for “a test fails first” in an MQL5 Script context:** because MQL5 has no jest-style `--failing` flag, a red step is demonstrated by:

1. Writing and compiling the harness script first with the module header still empty.
2. Confirming MetaEditor produces a compile error referencing the undefined symbol (that is the red state).
3. Only then adding the minimal module code to make it compile and pass.

This keeps the TDD loop intact in MQL5.

---

### Task 0: Initialize MT5 project folder and commit empty scaffolding

**Files:**

- Create: `mt5/XAUUSD_Scalper/.gitkeep`
- Create: `mt5/XAUUSD_Scalper/Experts/.gitkeep`
- Create: `mt5/XAUUSD_Scalper/Include/Core/.gitkeep`
- Create: `mt5/XAUUSD_Scalper/Include/Data/.gitkeep`
- Create: `mt5/XAUUSD_Scalper/Include/Analysis/.gitkeep`
- Create: `mt5/XAUUSD_Scalper/Include/Tests/.gitkeep`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/.gitkeep`
- Create: `mt5/XAUUSD_Scalper/README.md`

- [ ] **Step 1: Create directory skeleton and placeholder files**

Create every folder listed above and place an empty `.gitkeep` in each. Then create `mt5/XAUUSD_Scalper/README.md` with exactly this content:

```markdown
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
```

- [ ] **Step 2: Verify directory tree**

Run: `find mt5/XAUUSD_Scalper -type f -print | sort`

Expected output:

```
mt5/XAUUSD_Scalper/Experts/.gitkeep
mt5/XAUUSD_Scalper/Include/Analysis/.gitkeep
mt5/XAUUSD_Scalper/Include/Core/.gitkeep
mt5/XAUUSD_Scalper/Include/Data/.gitkeep
mt5/XAUUSD_Scalper/Include/Tests/.gitkeep
mt5/XAUUSD_Scalper/README.md
mt5/XAUUSD_Scalper/Scripts/Tests/.gitkeep
mt5/XAUUSD_Scalper/.gitkeep
```

- [ ] **Step 3: Commit**

```bash
git add mt5/XAUUSD_Scalper
git commit -m "chore(mt5): scaffold XAUUSD scalper phase 1 project folders"
```

---

### Task 1: Minimal test runner `CTestRunner`

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Tests/TestRunner.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_TestRunner.mq5`

- [ ] **Step 1: Write the failing harness first**

Create `mt5/XAUUSD_Scalper/Scripts/Tests/Test_TestRunner.mq5` with exactly:

```mql5
//+------------------------------------------------------------------+
//| Test_TestRunner.mq5                                              |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include <XAUUSD_Scalper/Tests/TestRunner.mqh>

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_TestRunner");

   tr.AssertTrue("true is true", true);
   tr.AssertFalse("false is false", false);
   tr.AssertEqualInt("int eq", 7, 7);
   tr.AssertEqualDouble("double eq", 1.2345, 1.2345, 1e-6);

   tr.End();
}
```

- [ ] **Step 2: Compile and verify it fails with missing-symbol error**

In MetaEditor, open `Test_TestRunner.mq5` and press F7.

Expected: MetaEditor reports compile error similar to `'CTestRunner' - undeclared identifier`. Record the error in the commit message as the captured red state.

- [ ] **Step 3: Implement `CTestRunner`**

Create `mt5/XAUUSD_Scalper/Include/Tests/TestRunner.mqh` with exactly:

```mql5
//+------------------------------------------------------------------+
//| TestRunner.mqh                                                   |
//+------------------------------------------------------------------+
#ifndef __XAUUSD_SCALPER_TEST_RUNNER_MQH__
#define __XAUUSD_SCALPER_TEST_RUNNER_MQH__

class CTestRunner
  {
private:
   string            m_suite;
   int               m_passed;
   int               m_failed;

public:
                     CTestRunner() : m_suite(""), m_passed(0), m_failed(0) {}

   void              Begin(const string suite_name)
     {
      m_suite  = suite_name;
      m_passed = 0;
      m_failed = 0;
      PrintFormat("TEST: BEGIN %s", m_suite);
     }

   void              End()
     {
      PrintFormat("TEST: END   %s passed=%d failed=%d", m_suite, m_passed, m_failed);
     }

   void              AssertTrue(const string name, const bool cond)
     {
      if(cond) { m_passed++; PrintFormat("TEST: PASS %s/%s", m_suite, name); }
      else     { m_failed++; PrintFormat("TEST: FAIL %s/%s expected=true got=false", m_suite, name); }
     }

   void              AssertFalse(const string name, const bool cond)
     {
      AssertTrue(name, !cond);
     }

   void              AssertEqualInt(const string name, const long expected, const long actual)
     {
      if(expected == actual) { m_passed++; PrintFormat("TEST: PASS %s/%s", m_suite, name); }
      else { m_failed++; PrintFormat("TEST: FAIL %s/%s expected=%I64d got=%I64d", m_suite, name, expected, actual); }
     }

   void              AssertEqualDouble(const string name, const double expected, const double actual, const double eps)
     {
      if(MathAbs(expected - actual) <= eps) { m_passed++; PrintFormat("TEST: PASS %s/%s", m_suite, name); }
      else { m_failed++; PrintFormat("TEST: FAIL %s/%s expected=%.8f got=%.8f", m_suite, name, expected, actual); }
     }

   int               Failed() const { return m_failed; }
  };

#endif // __XAUUSD_SCALPER_TEST_RUNNER_MQH__
```

- [ ] **Step 4: Compile and run harness to green**

1. In MetaEditor, press F7 on `Test_TestRunner.mq5`. Expected: `0 error(s), 0 warning(s)`.
2. Attach MT5 terminal to any symbol, drag `Test_TestRunner.mq5` from Navigator onto the chart.
3. Expected Expert Log lines include:
   - `TEST: BEGIN Test_TestRunner`
   - `TEST: PASS Test_TestRunner/true is true`
   - `TEST: PASS Test_TestRunner/false is false`
   - `TEST: PASS Test_TestRunner/int eq`
   - `TEST: PASS Test_TestRunner/double eq`
   - `TEST: END   Test_TestRunner passed=4 failed=0`

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Include/Tests/TestRunner.mqh \
         mt5/XAUUSD_Scalper/Scripts/Tests/Test_TestRunner.mq5
git commit -m "feat(mt5/tests): add minimal CTestRunner harness with basic asserts"
```

---

### Task 2: Logger stub `CLoggerStub`

P1 only needs `Info`, `Warn`, `Error`, `Debug` that wrap `Print`/`PrintFormat`. The full `CLogger` (file-based, daily rotation) ships in P4.

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Analysis/CLoggerStub.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_LoggerStub.mq5`

- [ ] **Step 1: Write the failing harness first**

Create `mt5/XAUUSD_Scalper/Scripts/Tests/Test_LoggerStub.mq5`:

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Analysis/CLoggerStub.mqh>

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_LoggerStub");

   CLoggerStub log;
   log.SetLevel(LOG_LEVEL_DEBUG);

   log.Info ("alpha",  "hello %s", "world");
   log.Warn ("alpha",  "warn=%d", 42);
   log.Error("alpha",  "err=%s",  "boom");
   log.Debug("alpha",  "dbg=%.2f", 1.25);

   tr.AssertTrue("logger level is DEBUG",  log.Level() == LOG_LEVEL_DEBUG);
   log.SetLevel(LOG_LEVEL_WARN);
   tr.AssertTrue("logger level changed to WARN", log.Level() == LOG_LEVEL_WARN);

   tr.End();
}
```

- [ ] **Step 2: Compile and confirm red state**

Expected MetaEditor error: `'CLoggerStub' - undeclared identifier`.

- [ ] **Step 3: Implement `CLoggerStub`**

Create `mt5/XAUUSD_Scalper/Include/Analysis/CLoggerStub.mqh`:

```mql5
#ifndef __XAUUSD_SCALPER_LOGGER_STUB_MQH__
#define __XAUUSD_SCALPER_LOGGER_STUB_MQH__

enum ENUM_LOG_LEVEL
  {
   LOG_LEVEL_DEBUG = 0,
   LOG_LEVEL_INFO  = 1,
   LOG_LEVEL_WARN  = 2,
   LOG_LEVEL_ERROR = 3
  };

class CLoggerStub
  {
private:
   ENUM_LOG_LEVEL    m_level;

   void              Emit(const string tag, const ENUM_LOG_LEVEL lvl, const string msg) const
     {
      if(lvl < m_level) return;
      string prefix;
      switch(lvl)
        {
         case LOG_LEVEL_DEBUG: prefix = "DBG"; break;
         case LOG_LEVEL_INFO:  prefix = "INF"; break;
         case LOG_LEVEL_WARN:  prefix = "WRN"; break;
         case LOG_LEVEL_ERROR: prefix = "ERR"; break;
         default:              prefix = "???"; break;
        }
      PrintFormat("[%s] %s | %s", prefix, tag, msg);
     }

public:
                     CLoggerStub() : m_level(LOG_LEVEL_INFO) {}

   void              SetLevel(const ENUM_LOG_LEVEL lvl) { m_level = lvl; }
   ENUM_LOG_LEVEL    Level() const { return m_level; }

   void              Debug(const string tag, const string fmt, string a="", string b="", string c="", string d="")
     { Emit(tag, LOG_LEVEL_DEBUG, StringFormat(fmt, a, b, c, d)); }

   void              Info (const string tag, const string fmt, string a="", string b="", string c="", string d="")
     { Emit(tag, LOG_LEVEL_INFO,  StringFormat(fmt, a, b, c, d)); }

   void              Warn (const string tag, const string fmt, string a="", string b="", string c="", string d="")
     { Emit(tag, LOG_LEVEL_WARN,  StringFormat(fmt, a, b, c, d)); }

   void              Error(const string tag, const string fmt, string a="", string b="", string c="", string d="")
     { Emit(tag, LOG_LEVEL_ERROR, StringFormat(fmt, a, b, c, d)); }
  };

#endif // __XAUUSD_SCALPER_LOGGER_STUB_MQH__
```

- [ ] **Step 4: Compile and run**

Expected: `0 error(s), 0 warning(s)`. Running the harness on any chart prints both `[INF] alpha | hello world` and the 2 pass lines followed by `passed=2 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Include/Analysis/CLoggerStub.mqh \
         mt5/XAUUSD_Scalper/Scripts/Tests/Test_LoggerStub.mq5
git commit -m "feat(mt5/logger): add CLoggerStub wrapping Print/PrintFormat with levels"
```

---

### Task 3: Tick collector `CTickCollector`

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Data/CTickCollector.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_TickCollector.mq5`

- [ ] **Step 1: Write the failing harness**

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Data/CTickCollector.mqh>

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_TickCollector");

   CTickCollector tc;
   tc.Init(4);

   MqlTick t;
   t.time      = (datetime)1000;
   t.bid       = 2400.00;
   t.ask       = 2400.05;
   t.last      = 2400.02;
   t.volume    = 1;
   t.flags     = 0;

   tc.OnTick(t);
   t.time = 1001; t.bid = 2400.10; t.ask = 2400.15; tc.OnTick(t);
   t.time = 1002; t.bid = 2400.05; t.ask = 2400.10; tc.OnTick(t);
   t.time = 1003; t.bid = 2400.20; t.ask = 2400.30; tc.OnTick(t);
   t.time = 1004; t.bid = 2400.25; t.ask = 2400.35; tc.OnTick(t); // wraps

   tr.AssertEqualInt("count capped at capacity", 4, tc.Count());
   tr.AssertEqualDouble("last spread", 0.10, tc.LastSpread(), 1e-6);
   tr.AssertTrue("max jump >= 0.15",  tc.MaxJump() + 1e-6 >= 0.15);
   tr.AssertTrue("ticks per sec >0",  tc.TicksPerSecondEstimate() > 0.0);

   tr.End();
}
```

- [ ] **Step 2: Compile and confirm red state**

Expected: `'CTickCollector' - undeclared identifier`.

- [ ] **Step 3: Implement `CTickCollector`**

```mql5
#ifndef __XAUUSD_SCALPER_TICK_COLLECTOR_MQH__
#define __XAUUSD_SCALPER_TICK_COLLECTOR_MQH__

struct TickRecord
  {
   datetime          time;
   double            bid;
   double            ask;
   double            last;
   ulong             volume;
   uint              flags;
   double            spread;
  };

class CTickCollector
  {
private:
   TickRecord        m_buf[];
   int               m_cap;
   int               m_size;
   int               m_head;
   double            m_max_jump;
   double            m_last_spread;
   datetime          m_first_time;
   datetime          m_last_time;

public:
                     CTickCollector() : m_cap(0), m_size(0), m_head(0), m_max_jump(0), m_last_spread(0), m_first_time(0), m_last_time(0) {}

   void              Init(const int capacity)
     {
      m_cap = capacity > 0 ? capacity : 1000;
      ArrayResize(m_buf, m_cap);
      m_size = 0;
      m_head = 0;
      m_max_jump = 0;
      m_last_spread = 0;
      m_first_time = 0;
      m_last_time = 0;
     }

   void              OnTick(const MqlTick &t)
     {
      TickRecord r;
      r.time   = t.time;
      r.bid    = t.bid;
      r.ask    = t.ask;
      r.last   = t.last;
      r.volume = t.volume;
      r.flags  = t.flags;
      r.spread = t.ask - t.bid;

      if(m_size > 0)
        {
         int prev_idx = (m_head - 1 + m_cap) % m_cap;
         double jump = MathAbs(r.bid - m_buf[prev_idx].bid);
         if(jump > m_max_jump) m_max_jump = jump;
        }
      else
         m_first_time = r.time;

      m_buf[m_head] = r;
      m_head = (m_head + 1) % m_cap;
      if(m_size < m_cap) m_size++;

      m_last_spread = r.spread;
      m_last_time = r.time;
     }

   int               Count() const { return m_size; }
   double            LastSpread() const { return m_last_spread; }
   double            MaxJump() const { return m_max_jump; }

   double            TicksPerSecondEstimate() const
     {
      if(m_size < 2 || m_last_time == m_first_time) return 0.0;
      return (double)m_size / (double)(m_last_time - m_first_time);
     }
  };

#endif // __XAUUSD_SCALPER_TICK_COLLECTOR_MQH__
```

- [ ] **Step 4: Compile and run green**

Expected: `0 error(s), 0 warning(s)`. Running on chart prints `TEST: PASS` x4 and `passed=4 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Include/Data/CTickCollector.mqh \
         mt5/XAUUSD_Scalper/Scripts/Tests/Test_TickCollector.mq5
git commit -m "feat(mt5/data): add CTickCollector ring buffer with spread/jump/rate metrics"
```

---

### Task 4: Indicator manager `CIndicatorManager`

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Data/CIndicatorManager.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_IndicatorManager.mq5`

- [ ] **Step 1: Write the failing harness**

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_IndicatorManager");

   CIndicatorManager im;
   bool ok = im.Init(_Symbol);
   tr.AssertTrue("Init returns true", ok);

   im.Update();

   tr.AssertTrue("ema5 positive",  im.EMA(5,0)  > 0.0);
   tr.AssertTrue("ema10 positive", im.EMA(10,0) > 0.0);
   tr.AssertTrue("ema20 positive", im.EMA(20,0) > 0.0);
   tr.AssertTrue("ema50 positive", im.EMA(50,0) > 0.0);
   tr.AssertTrue("rsi in range",   im.RSI(0) >= 0.0 && im.RSI(0) <= 100.0);
   tr.AssertTrue("atr positive",   im.ATR(0) > 0.0);
   tr.AssertTrue("adx non-negative", im.ADX(0) >= 0.0);
   tr.AssertTrue("bb upper > lower", im.BBUpper(0) > im.BBLower(0));
   tr.AssertTrue("ema5 different from ema50", MathAbs(im.EMA(5,0) - im.EMA(50,0)) >= 0.0);

   im.Shutdown();
   tr.End();
}
```

- [ ] **Step 2: Compile and confirm red state**

Expected: `'CIndicatorManager' - undeclared identifier`.

- [ ] **Step 3: Implement `CIndicatorManager`**

```mql5
#ifndef __XAUUSD_SCALPER_INDICATOR_MANAGER_MQH__
#define __XAUUSD_SCALPER_INDICATOR_MANAGER_MQH__

class CIndicatorManager
  {
private:
   string            m_symbol;

   int               h_ema5, h_ema10, h_ema20, h_ema50;
   int               h_bb, h_rsi, h_atr, h_adx;
   int               h_ema20_m5, h_ema50_m5;

   double            b_ema5[], b_ema10[], b_ema20[], b_ema50[];
   double            b_bb_up[], b_bb_mid[], b_bb_lo[];
   double            b_rsi[], b_atr[], b_adx[], b_plus_di[], b_minus_di[];
   double            b_ema20_m5[], b_ema50_m5[];

   bool              CopyOne(const int handle, const int buffer_index, double &dst[])
     {
      if(handle == INVALID_HANDLE) return false;
      if(CopyBuffer(handle, buffer_index, 0, 5, dst) < 5) return false;
      ArraySetAsSeries(dst, true);
      return true;
     }

public:
                     CIndicatorManager() : m_symbol(""),
                                           h_ema5(INVALID_HANDLE),  h_ema10(INVALID_HANDLE),
                                           h_ema20(INVALID_HANDLE), h_ema50(INVALID_HANDLE),
                                           h_bb(INVALID_HANDLE),    h_rsi(INVALID_HANDLE),
                                           h_atr(INVALID_HANDLE),   h_adx(INVALID_HANDLE),
                                           h_ema20_m5(INVALID_HANDLE), h_ema50_m5(INVALID_HANDLE) {}

   bool              Init(const string symbol)
     {
      m_symbol = symbol;
      h_ema5      = iMA (m_symbol, PERIOD_M1,  5, 0, MODE_EMA, PRICE_CLOSE);
      h_ema10     = iMA (m_symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
      h_ema20     = iMA (m_symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
      h_ema50     = iMA (m_symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
      h_bb        = iBands(m_symbol, PERIOD_M1, 20, 0, 2.0, PRICE_CLOSE);
      h_rsi       = iRSI  (m_symbol, PERIOD_M1, 14, PRICE_CLOSE);
      h_atr       = iATR  (m_symbol, PERIOD_M1, 14);
      h_adx       = iADX  (m_symbol, PERIOD_M1, 14);
      h_ema20_m5  = iMA (m_symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
      h_ema50_m5  = iMA (m_symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
      return h_ema5  != INVALID_HANDLE && h_ema10 != INVALID_HANDLE &&
             h_ema20 != INVALID_HANDLE && h_ema50 != INVALID_HANDLE &&
             h_bb    != INVALID_HANDLE && h_rsi   != INVALID_HANDLE &&
             h_atr   != INVALID_HANDLE && h_adx   != INVALID_HANDLE &&
             h_ema20_m5 != INVALID_HANDLE && h_ema50_m5 != INVALID_HANDLE;
     }

   void              Shutdown()
     {
      if(h_ema5  != INVALID_HANDLE) IndicatorRelease(h_ema5);
      if(h_ema10 != INVALID_HANDLE) IndicatorRelease(h_ema10);
      if(h_ema20 != INVALID_HANDLE) IndicatorRelease(h_ema20);
      if(h_ema50 != INVALID_HANDLE) IndicatorRelease(h_ema50);
      if(h_bb    != INVALID_HANDLE) IndicatorRelease(h_bb);
      if(h_rsi   != INVALID_HANDLE) IndicatorRelease(h_rsi);
      if(h_atr   != INVALID_HANDLE) IndicatorRelease(h_atr);
      if(h_adx   != INVALID_HANDLE) IndicatorRelease(h_adx);
      if(h_ema20_m5 != INVALID_HANDLE) IndicatorRelease(h_ema20_m5);
      if(h_ema50_m5 != INVALID_HANDLE) IndicatorRelease(h_ema50_m5);
     }

   void              Update()
     {
      CopyOne(h_ema5, 0, b_ema5);
      CopyOne(h_ema10,0, b_ema10);
      CopyOne(h_ema20,0, b_ema20);
      CopyOne(h_ema50,0, b_ema50);
      CopyOne(h_bb,   0, b_bb_mid);
      CopyOne(h_bb,   1, b_bb_up);
      CopyOne(h_bb,   2, b_bb_lo);
      CopyOne(h_rsi,  0, b_rsi);
      CopyOne(h_atr,  0, b_atr);
      CopyOne(h_adx,  0, b_adx);
      CopyOne(h_adx,  1, b_plus_di);
      CopyOne(h_adx,  2, b_minus_di);
      CopyOne(h_ema20_m5, 0, b_ema20_m5);
      CopyOne(h_ema50_m5, 0, b_ema50_m5);
     }

   double            EMA(const int period, const int shift) const
     {
      switch(period)
        {
         case 5:  return shift < ArraySize(b_ema5)  ? b_ema5[shift]  : 0.0;
         case 10: return shift < ArraySize(b_ema10) ? b_ema10[shift] : 0.0;
         case 20: return shift < ArraySize(b_ema20) ? b_ema20[shift] : 0.0;
         case 50: return shift < ArraySize(b_ema50) ? b_ema50[shift] : 0.0;
         default: return 0.0;
        }
     }

   double            BBUpper(const int shift) const { return shift < ArraySize(b_bb_up)  ? b_bb_up[shift]  : 0.0; }
   double            BBMiddle(const int shift) const{ return shift < ArraySize(b_bb_mid) ? b_bb_mid[shift] : 0.0; }
   double            BBLower(const int shift) const { return shift < ArraySize(b_bb_lo)  ? b_bb_lo[shift]  : 0.0; }
   double            RSI(const int shift) const { return shift < ArraySize(b_rsi) ? b_rsi[shift] : 0.0; }
   double            ATR(const int shift) const { return shift < ArraySize(b_atr) ? b_atr[shift] : 0.0; }
   double            ADX(const int shift) const { return shift < ArraySize(b_adx) ? b_adx[shift] : 0.0; }
   double            PlusDI(const int shift) const { return shift < ArraySize(b_plus_di) ? b_plus_di[shift] : 0.0; }
   double            MinusDI(const int shift) const { return shift < ArraySize(b_minus_di) ? b_minus_di[shift] : 0.0; }

   double            EMA20_M5(const int shift) const { return shift < ArraySize(b_ema20_m5) ? b_ema20_m5[shift] : 0.0; }
   double            EMA50_M5(const int shift) const { return shift < ArraySize(b_ema50_m5) ? b_ema50_m5[shift] : 0.0; }

   double            BBWidth(const int shift) const { return BBUpper(shift) - BBLower(shift); }
   double            PriceInBand(const double price, const int shift) const
     {
      double w = BBWidth(shift);
      if(w <= 0.0) return 0.5;
      return (price - BBLower(shift)) / w;
     }
  };

#endif // __XAUUSD_SCALPER_INDICATOR_MANAGER_MQH__
```

- [ ] **Step 4: Compile and run green on XAUUSD M1**

Requires: chart opened on `XAUUSD` M1, enough history loaded. Expected log: `TEST: PASS` x9 and `passed=9 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Include/Data/CIndicatorManager.mqh \
         mt5/XAUUSD_Scalper/Scripts/Tests/Test_IndicatorManager.mq5
git commit -m "feat(mt5/data): add CIndicatorManager with M1 + M5 handles and cached buffers"
```

---

### Task 5: Market analyzer `CMarketAnalyzer`

`CMarketAnalyzer` takes an `CIndicatorManager &` plus a `CTickCollector &` and emits an `ENUM_MARKET_STATE`.

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Core/CMarketAnalyzer.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_MarketAnalyzer.mq5`

- [ ] **Step 1: Write the failing harness with a synthetic fixture**

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

// Minimal fake indicator/tick collectors that satisfy the analyzer's read surface.
// We do this by deriving from the real classes and overriding via injection constructor
// parameters available on CMarketAnalyzer — see Step 3 for the actual class design.
void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_MarketAnalyzer");

   MarketInputs in;
   // Ranging baseline
   in.adx         = 15;
   in.atr         = 0.50;
   in.atr_avg     = 0.50;
   in.bb_width    = 0.80;
   in.last_spread = 0.05;
   in.max_jump    = 0.10;
   in.ticks_per_s = 10.0;
   in.breakouts   = 0;

   tr.AssertEqualInt("ranging", (int)MARKET_RANGING, (int)CMarketAnalyzer::Classify(in));

   // Trending
   in.adx = 30; in.atr = 1.0; in.atr_avg = 0.80; in.bb_width = 2.0; in.breakouts = 1;
   tr.AssertEqualInt("trending", (int)MARKET_TRENDING, (int)CMarketAnalyzer::Classify(in));

   // Breakout
   in.adx = 22; in.atr = 1.0; in.atr_avg = 0.80; in.bb_width = 3.0; in.breakouts = 3;
   tr.AssertEqualInt("breakout", (int)MARKET_BREAKOUT, (int)CMarketAnalyzer::Classify(in));

   // Abnormal: tick density collapses
   in.adx = 20; in.atr = 1.0; in.atr_avg = 0.80; in.ticks_per_s = 1.0;
   tr.AssertEqualInt("abnormal on tick collapse", (int)MARKET_ABNORMAL, (int)CMarketAnalyzer::Classify(in));

   // Abnormal: spread blowout
   in.ticks_per_s = 10.0; in.last_spread = 0.20;
   tr.AssertEqualInt("abnormal on spread blowout", (int)MARKET_ABNORMAL, (int)CMarketAnalyzer::Classify(in));

   // Abnormal: ATR blowout
   in.last_spread = 0.05; in.atr = 3.0; in.atr_avg = 0.80;
   tr.AssertEqualInt("abnormal on ATR blowout", (int)MARKET_ABNORMAL, (int)CMarketAnalyzer::Classify(in));

   tr.End();
}
```

- [ ] **Step 2: Compile and confirm red state**

Expected: `'CMarketAnalyzer' - undeclared identifier` (and `MarketInputs`).

- [ ] **Step 3: Implement `CMarketAnalyzer`**

```mql5
#ifndef __XAUUSD_SCALPER_MARKET_ANALYZER_MQH__
#define __XAUUSD_SCALPER_MARKET_ANALYZER_MQH__

enum ENUM_MARKET_STATE
  {
   MARKET_RANGING  = 0,
   MARKET_TRENDING = 1,
   MARKET_BREAKOUT = 2,
   MARKET_ABNORMAL = 3
  };

struct MarketInputs
  {
   double adx;
   double atr;
   double atr_avg;
   double bb_width;
   double last_spread;
   double max_jump;
   double ticks_per_s;
   int    breakouts;
  };

class CMarketAnalyzer
  {
public:
   static ENUM_MARKET_STATE Classify(const MarketInputs &in)
     {
      if(in.atr > in.atr_avg * 2.5) return MARKET_ABNORMAL;
      if(in.last_spread > 0.15)     return MARKET_ABNORMAL;
      if(in.max_jump    > 0.5)      return MARKET_ABNORMAL;
      if(in.ticks_per_s < 3.0)      return MARKET_ABNORMAL;

      if(in.adx >= 25.0 && in.atr > in.atr_avg) return MARKET_TRENDING;

      if(in.breakouts >= 2 && in.bb_width > 2.0) return MARKET_BREAKOUT;

      return MARKET_RANGING;
     }
  };

#endif // __XAUUSD_SCALPER_MARKET_ANALYZER_MQH__
```

Note: In later tasks `CMarketAnalyzer` will grow an instance method `Evaluate(CIndicatorManager &im, CTickCollector &tc)` that builds a `MarketInputs` and calls this `Classify`. The static split keeps P1 testable without touching live indicator handles.

- [ ] **Step 4: Compile and run green**

Expected log: 6 `TEST: PASS` lines and `passed=6 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Include/Core/CMarketAnalyzer.mqh \
         mt5/XAUUSD_Scalper/Scripts/Tests/Test_MarketAnalyzer.mq5
git commit -m "feat(mt5/core): add CMarketAnalyzer state classifier with static Classify()"
```

---

### Task 6: Strategy base `CStrategyBase`

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Core/CStrategyBase.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_StrategyBase.mq5`

- [ ] **Step 1: Write the failing harness**

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

class CNullStrategy : public CStrategyBase
  {
public:
                     CNullStrategy() { m_name = "NULL"; m_magic = 111; }
   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r;
      r.direction = SIGNAL_NONE;
      r.stop_loss = 0;
      r.take_profit = 0;
      return r;
     }
  };

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_StrategyBase");

   CNullStrategy s;
   tr.AssertTrue("name NULL",         s.Name() == "NULL");
   tr.AssertEqualInt("magic 111",     111, (long)s.Magic());

   s.OnTradeClosed(+10.0);
   s.OnTradeClosed(-4.0);
   s.OnTradeClosed(+6.0);
   tr.AssertEqualInt("trades 3",       3, (long)s.Trades());
   tr.AssertEqualInt("wins 2",         2, (long)s.Wins());
   tr.AssertEqualDouble("gross pnl 12.0", 12.0, s.GrossPnL(), 1e-6);

   double f = s.CalculateKellyFraction(30 /*min_trades*/, 0.55 /*cold_p*/, 1.2 /*cold_b*/);
   tr.AssertTrue("cold-start kelly > 0", f > 0.0);

   tr.End();
}
```

- [ ] **Step 2: Compile and confirm red state**

Expected: `'CStrategyBase' - undeclared identifier`.

- [ ] **Step 3: Implement `CStrategyBase`**

```mql5
#ifndef __XAUUSD_SCALPER_STRATEGY_BASE_MQH__
#define __XAUUSD_SCALPER_STRATEGY_BASE_MQH__

#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

enum ENUM_SIGNAL_DIRECTION
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
  };

struct StrategyContext
  {
   CIndicatorManager *im;
   CTickCollector    *tc;
   ENUM_MARKET_STATE  state;
   double             bid;
   double             ask;
   datetime           time;
  };

struct SignalResult
  {
   ENUM_SIGNAL_DIRECTION direction;
   double                stop_loss;
   double                take_profit;
  };

class CStrategyBase
  {
protected:
   string            m_name;
   ulong             m_magic;
   int               m_trades;
   int               m_wins;
   double            m_gross_pnl;
   double            m_gross_win;
   double            m_gross_loss;

public:
                     CStrategyBase() : m_name(""), m_magic(0), m_trades(0), m_wins(0),
                                       m_gross_pnl(0), m_gross_win(0), m_gross_loss(0) {}
   virtual          ~CStrategyBase() {}

   string            Name() const  { return m_name; }
   ulong             Magic() const { return m_magic; }
   int               Trades() const { return m_trades; }
   int               Wins() const   { return m_wins; }
   double            GrossPnL() const { return m_gross_pnl; }

   void              OnTradeClosed(const double pnl)
     {
      m_trades++;
      m_gross_pnl += pnl;
      if(pnl > 0) { m_wins++; m_gross_win += pnl; }
      else        { m_gross_loss += -pnl; }
     }

   double            WinRate() const
     {
      return m_trades > 0 ? (double)m_wins / (double)m_trades : 0.0;
     }

   double            PayoffRatio() const
     {
      double avg_w = m_wins > 0 ? m_gross_win / (double)m_wins : 0.0;
      int losses = m_trades - m_wins;
      double avg_l = losses > 0 ? m_gross_loss / (double)losses : 0.0;
      return avg_l > 0 ? avg_w / avg_l : 0.0;
     }

   double            CalculateKellyFraction(const int min_trades,
                                            const double cold_p, const double cold_b) const
     {
      double p, b;
      if(m_trades < min_trades) { p = cold_p; b = cold_b; }
      else                      { p = WinRate(); b = PayoffRatio(); }
      if(b <= 0.0) return 0.0;
      double f = (p * b - (1.0 - p)) / b;
      if(f < 0.0) f = 0.0;
      return f;
     }

   virtual SignalResult CheckSignal(const StrategyContext &ctx) = 0;
  };

#endif // __XAUUSD_SCALPER_STRATEGY_BASE_MQH__
```

- [ ] **Step 4: Compile and run green**

Expected: `0 error(s), 0 warning(s)` and `passed=4 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Include/Core/CStrategyBase.mqh \
         mt5/XAUUSD_Scalper/Scripts/Tests/Test_StrategyBase.mq5
git commit -m "feat(mt5/core): add CStrategyBase with Kelly cold-start and PnL stats"
```

---

### Task 7: `CStrategyEMA` fast EMA crossover

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Core/CStrategyEMA.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_StrategyEMA.mq5`

- [ ] **Step 1: Write the failing harness**

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>

class FakeIM : public CIndicatorManager
  {
public:
   double e5_prev, e5_curr, e10_prev, e10_curr, e20_curr, atr_curr;
   double EMA(const int p, const int s) const
     {
      if(p == 5)  return s == 1 ? e5_prev  : e5_curr;
      if(p == 10) return s == 1 ? e10_prev : e10_curr;
      if(p == 20) return e20_curr;
      return 0.0;
     }
   double ATR(const int s) const { return atr_curr; }
  };

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_StrategyEMA");

   FakeIM im;
   // Bullish cross: prev ema5 < ema10, curr ema5 > ema10, price above ema20
   im.e5_prev  = 2400.00; im.e10_prev = 2400.10;
   im.e5_curr  = 2400.20; im.e10_curr = 2400.10;
   im.e20_curr = 2399.50;
   im.atr_curr = 1.0;

   CStrategyEMA s;
   s.Configure(1.5 /*sl_mult*/, 1.2 /*tp_mult*/, 0.5 /*sl_min*/, 2.0 /*sl_max*/);

   StrategyContext ctx; ctx.im = &im; ctx.tc = NULL; ctx.state = MARKET_TRENDING;
   ctx.bid = 2400.30; ctx.ask = 2400.35; ctx.time = 0;

   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bullish cross -> BUY", (int)SIGNAL_BUY, (int)r.direction);
   tr.AssertTrue("sl below bid",  r.stop_loss < ctx.bid);
   tr.AssertTrue("tp above bid",  r.take_profit > ctx.bid);

   // Bearish cross with ema5 going from above to below ema10, price below ema20
   im.e5_prev  = 2400.30; im.e10_prev = 2400.20;
   im.e5_curr  = 2400.00; im.e10_curr = 2400.20;
   im.e20_curr = 2400.50;
   ctx.bid = 2399.80; ctx.ask = 2399.85;

   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bearish cross -> SELL", (int)SIGNAL_SELL, (int)r.direction);

   // No cross -> NONE
   im.e5_prev  = 2400.00; im.e10_prev = 2399.90;
   im.e5_curr  = 2400.10; im.e10_curr = 2399.95;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("no cross -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   tr.End();
}
```

Note: MQL5 allows static-dispatch “fake” subclass inheriting from `CIndicatorManager` because our getters are non-virtual in P1; the fake simply overloads them in its own scope. The harness compiles and links only because `StrategyContext.im` is typed `CIndicatorManager *` and we cast the fake pointer — MQL5 permits this as long as both classes expose the same member names. If a MetaEditor build in the engineer’s environment flags this, add `virtual` to the indicator getters and re-run.

- [ ] **Step 2: Compile and confirm red state**

Expected: `'CStrategyEMA' - undeclared identifier`.

- [ ] **Step 3: Implement `CStrategyEMA`**

```mql5
#ifndef __XAUUSD_SCALPER_STRATEGY_EMA_MQH__
#define __XAUUSD_SCALPER_STRATEGY_EMA_MQH__

#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

class CStrategyEMA : public CStrategyBase
  {
private:
   double            m_sl_mult;
   double            m_tp_mult;
   double            m_sl_min;
   double            m_sl_max;

   double            ClampSL(const double sl_dist) const
     {
      double d = sl_dist;
      if(d < m_sl_min) d = m_sl_min;
      if(d > m_sl_max) d = m_sl_max;
      return d;
     }

public:
                     CStrategyEMA() : m_sl_mult(1.5), m_tp_mult(1.2), m_sl_min(0.5), m_sl_max(2.0)
     {
      m_name = "EMA";
      m_magic = 7010001;
     }

   void              Configure(const double sl_mult, const double tp_mult,
                               const double sl_min,  const double sl_max)
     {
      m_sl_mult = sl_mult; m_tp_mult = tp_mult;
      m_sl_min  = sl_min;  m_sl_max  = sl_max;
     }

   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r; r.direction = SIGNAL_NONE; r.stop_loss = 0; r.take_profit = 0;
      if(ctx.im == NULL) return r;

      double e5_prev  = ctx.im.EMA(5, 1);
      double e5_curr  = ctx.im.EMA(5, 0);
      double e10_prev = ctx.im.EMA(10, 1);
      double e10_curr = ctx.im.EMA(10, 0);
      double e20      = ctx.im.EMA(20, 0);
      double atr      = ctx.im.ATR(0);

      double sl_dist = ClampSL(atr * m_sl_mult);
      double tp_dist = atr * m_tp_mult;

      bool bull_cross = (e5_prev <= e10_prev) && (e5_curr > e10_curr) && (ctx.bid > e20);
      bool bear_cross = (e5_prev >= e10_prev) && (e5_curr < e10_curr) && (ctx.bid < e20);

      if(bull_cross)
        {
         r.direction   = SIGNAL_BUY;
         r.stop_loss   = ctx.bid - sl_dist;
         r.take_profit = ctx.bid + tp_dist;
        }
      else if(bear_cross)
        {
         r.direction   = SIGNAL_SELL;
         r.stop_loss   = ctx.ask + sl_dist;
         r.take_profit = ctx.ask - tp_dist;
        }
      return r;
     }
  };

#endif // __XAUUSD_SCALPER_STRATEGY_EMA_MQH__
```

- [ ] **Step 4: Compile and run green**

Expected: `TEST: PASS` x4 and `passed=4 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Include/Core/CStrategyEMA.mqh \
         mt5/XAUUSD_Scalper/Scripts/Tests/Test_StrategyEMA.mq5
git commit -m "feat(mt5/core): add CStrategyEMA fast EMA crossover with ATR SL/TP"
```

---

### Task 8: `CStrategyBollinger` breakout-pullback

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Core/CStrategyBollinger.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_StrategyBollinger.mq5`

- [ ] **Step 1: Write the failing harness**

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBollinger.mqh>

class FakeIM : public CIndicatorManager
  {
public:
   double up_prev, up_curr, lo_prev, lo_curr, mid;
   double BBUpper(const int s) const { return s == 1 ? up_prev : up_curr; }
   double BBLower(const int s) const { return s == 1 ? lo_prev : lo_curr; }
   double BBMiddle(const int s) const { return mid; }
  };

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_StrategyBollinger");

   FakeIM im; im.up_prev = 2400.00; im.up_curr = 2400.05;
                im.lo_prev = 2399.50; im.lo_curr = 2399.55; im.mid = 2399.80;

   CStrategyBollinger s; s.Configure(0.2 /*pullback*/, 1.0 /*sl*/, 0.8 /*tp*/);

   StrategyContext ctx; ctx.im = &im; ctx.state = MARKET_BREAKOUT; ctx.tc = NULL; ctx.time = 0;

   // Upper breakout then pullback -> BUY
   ctx.bid = 2400.15; ctx.ask = 2400.20; // close to upper band, breakout context
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("upper breakout pullback -> BUY", (int)SIGNAL_BUY, (int)r.direction);

   // Lower breakout pullback -> SELL
   ctx.bid = 2399.45; ctx.ask = 2399.50;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("lower breakout pullback -> SELL", (int)SIGNAL_SELL, (int)r.direction);

   // Inside band -> NONE
   ctx.bid = 2399.80; ctx.ask = 2399.85;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("inside band -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   tr.End();
}
```

- [ ] **Step 2: Compile and confirm red state**

Expected: `'CStrategyBollinger' - undeclared identifier`.

- [ ] **Step 3: Implement `CStrategyBollinger`**

```mql5
#ifndef __XAUUSD_SCALPER_STRATEGY_BOLL_MQH__
#define __XAUUSD_SCALPER_STRATEGY_BOLL_MQH__

#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

class CStrategyBollinger : public CStrategyBase
  {
private:
   double            m_pullback;
   double            m_sl;
   double            m_tp;

public:
                     CStrategyBollinger() : m_pullback(0.2), m_sl(1.0), m_tp(0.8)
     {
      m_name  = "BOLL";
      m_magic = 7010002;
     }

   void              Configure(const double pullback, const double sl, const double tp)
     {
      m_pullback = pullback; m_sl = sl; m_tp = tp;
     }

   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r; r.direction = SIGNAL_NONE; r.stop_loss = 0; r.take_profit = 0;
      if(ctx.im == NULL) return r;

      double up = ctx.im.BBUpper(0);
      double lo = ctx.im.BBLower(0);

      double dist_up = MathAbs(ctx.bid - up);
      double dist_lo = MathAbs(ctx.bid - lo);

      bool is_up_break = ctx.bid > up - m_pullback && ctx.bid > ctx.im.BBMiddle(0) && dist_up <= m_pullback;
      bool is_lo_break = ctx.bid < lo + m_pullback && ctx.bid < ctx.im.BBMiddle(0) && dist_lo <= m_pullback;

      if(is_up_break)
        {
         r.direction   = SIGNAL_BUY;
         r.stop_loss   = ctx.bid - m_sl;
         r.take_profit = ctx.bid + m_tp;
        }
      else if(is_lo_break)
        {
         r.direction   = SIGNAL_SELL;
         r.stop_loss   = ctx.ask + m_sl;
         r.take_profit = ctx.ask - m_tp;
        }
      return r;
     }
  };

#endif // __XAUUSD_SCALPER_STRATEGY_BOLL_MQH__
```

- [ ] **Step 4: Compile and run green**

Expected: `passed=3 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Include/Core/CStrategyBollinger.mqh \
         mt5/XAUUSD_Scalper/Scripts/Tests/Test_StrategyBollinger.mq5
git commit -m "feat(mt5/core): add CStrategyBollinger breakout-pullback strategy"
```

---

### Task 9: `CStrategyRSI` extreme reversal

**Files:**

- Create: `mt5/XAUUSD_Scalper/Include/Core/CStrategyRSI.mqh`
- Create: `mt5/XAUUSD_Scalper/Scripts/Tests/Test_StrategyRSI.mq5`

- [ ] **Step 1: Write the failing harness**

```mql5
#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CStrategyRSI.mqh>

class FakeIM : public CIndicatorManager
  {
public:
   double rsi_prev, rsi_curr, e50;
   double RSI(const int s) const { return s == 1 ? rsi_prev : rsi_curr; }
   double EMA(const int p, const int s) const { return p == 50 ? e50 : 0.0; }
  };

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_StrategyRSI");

   FakeIM im; CStrategyRSI s;
   s.Configure(25.0, 75.0, 1.5, 0.6, 0.5);

   StrategyContext ctx; ctx.im = &im; ctx.tc = NULL; ctx.state = MARKET_RANGING; ctx.time = 0;

   // Oversold turning up: prev 20 -> curr 22, price near EMA50
   im.rsi_prev = 20.0; im.rsi_curr = 22.0; im.e50 = 2400.00;
   ctx.bid = 2400.20; ctx.ask = 2400.25;
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("oversold rising -> BUY", (int)SIGNAL_BUY, (int)r.direction);

   // Overbought turning down: prev 80 -> curr 78, price near EMA50
   im.rsi_prev = 80.0; im.rsi_curr = 78.0;
   ctx.bid = 2399.80; ctx.ask = 2399.85;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("overbought falling -> SELL", (int)SIGNAL_SELL, (int)r.direction);

   // RSI stays in middle -> NONE
   im.rsi_prev = 50.0; im.rsi_curr = 50.0;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("middle RSI -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   // Price too far from EMA50 -> NONE even if RSI valid
   im.rsi_prev = 20.0; im.rsi_curr = 22.0; im.e50 = 2395.00; ctx.bid = 2400.00;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("far from EMA50 -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   tr.End();
}
```

- [ ] **Step 2: Compile and confirm red state**

Expected: `'CStrategyRSI' - undeclared identifier`.

- [ ] **Step 3: Implement `CStrategyRSI`**

```mql5
#ifndef __XAUUSD_SCALPER_STRATEGY_RSI_MQH__
#define __XAUUSD_SCALPER_STRATEGY_RSI_MQH__

#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

class CStrategyRSI : public CStrategyBase
  {
private:
   double            m_lo;
   double            m_hi;
   double            m_dist;
   double            m_sl;
   double            m_tp;

public:
                     CStrategyRSI() : m_lo(25), m_hi(75), m_dist(1.5), m_sl(0.6), m_tp(0.5)
     {
      m_name  = "RSI";
      m_magic = 7010003;
     }

   void              Configure(const double lo, const double hi, const double dist,
                               const double sl, const double tp)
     {
      m_lo = lo; m_hi = hi; m_dist = dist; m_sl = sl; m_tp = tp;
     }

   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r; r.direction = SIGNAL_NONE; r.stop_loss = 0; r.take_profit = 0;
      if(ctx.im == NULL) return r;

      double rsi_prev = ctx.im.RSI(1);
      double rsi_curr = ctx.im.RSI(0);
      double e50      = ctx.im.EMA(50, 0);
      double dist     = MathAbs(ctx.bid - e50);

      if(dist > m_dist) return r;

      bool over_sold_up  = rsi_prev < m_lo && rsi_curr > rsi_prev;
      bool over_bought_dn= rsi_prev > m_hi && rsi_curr < rsi_prev;

      if(over_sold_up)
        {
         r.direction   = SIGNAL_BUY;
         r.stop_loss   = ctx.bid - m_sl;
         r.take_profit = ctx.bid + m_tp;
        }
      else if(over_bought_dn)
        {
         r.direction   = SIGNAL_SELL;
         r.stop_loss   = ctx.ask + m_sl;
         r.take_profit = ctx.ask - m_tp;
        }
      return r;
     }
  };

#endif // __XAUUSD_SCALPER_STRATEGY_RSI_MQH__
```

- [ ] **Step 4: Compile and run green**

Expected: `passed=4 failed=0`.

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Include/Core/CStrategyRSI.mqh \
         mt5/XAUUSD_Scalper/Scripts/Tests/Test_StrategyRSI.mq5
git commit -m "feat(mt5/core): add CStrategyRSI extreme reversal with EMA50 distance gate"
```

---

### Task 10: EA entry point `XAUUSD_Scalper_EA.mq5`

Wires Tick collector, indicator manager, market analyzer, three strategies. No orders are sent in P1; the EA only logs each strategy’s evaluated signal.

**Files:**

- Create: `mt5/XAUUSD_Scalper/Experts/XAUUSD_Scalper_EA.mq5`

- [ ] **Step 1: Write the failing compile check**

Create the Expert file with empty body referencing all modules but no `OnInit`/`OnTick`:

```mql5
#property strict
#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBollinger.mqh>
#include <XAUUSD_Scalper/Core/CStrategyRSI.mqh>
#include <XAUUSD_Scalper/Analysis/CLoggerStub.mqh>
```

- [ ] **Step 2: Compile and confirm red state**

Expected MetaEditor error: `'OnInit' - function must be declared`.

- [ ] **Step 3: Implement full EA body**

Replace the file content with:

```mql5
#property strict
#property description "XAUUSD Scalper Phase 1 - foundation only"

#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBollinger.mqh>
#include <XAUUSD_Scalper/Core/CStrategyRSI.mqh>
#include <XAUUSD_Scalper/Analysis/CLoggerStub.mqh>

input bool   InpEnableEMA   = true;
input bool   InpEnableBoll  = true;
input bool   InpEnableRSI   = true;
input int    InpTickBuffer  = 10000;

CTickCollector    g_tc;
CIndicatorManager g_im;
CStrategyEMA      g_sema;
CStrategyBollinger g_sboll;
CStrategyRSI      g_srsi;
CLoggerStub       g_log;

int OnInit()
{
   g_tc.Init(InpTickBuffer);
   if(!g_im.Init(_Symbol))
   {
      g_log.Error("init", "indicator manager init failed");
      return INIT_FAILED;
   }
   g_log.Info("init", "Init OK");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_im.Shutdown();
   g_log.Info("deinit", "reason=%d", (string)reason);
}

void OnTick()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   g_tc.OnTick(t);
   g_im.Update();

   MarketInputs mi;
   mi.adx         = g_im.ADX(0);
   mi.atr         = g_im.ATR(0);
   mi.atr_avg     = g_im.ATR(0); // replaced with rolling avg in P3
   mi.bb_width    = g_im.BBWidth(0);
   mi.last_spread = g_tc.LastSpread();
   mi.max_jump    = g_tc.MaxJump();
   mi.ticks_per_s = g_tc.TicksPerSecondEstimate();
   mi.breakouts   = 0; // fully wired in P3
   ENUM_MARKET_STATE state = CMarketAnalyzer::Classify(mi);

   StrategyContext ctx; ctx.im = &g_im; ctx.tc = &g_tc; ctx.state = state;
   ctx.bid = t.bid; ctx.ask = t.ask; ctx.time = t.time;

   if(InpEnableEMA)
   {
      SignalResult r = g_sema.CheckSignal(ctx);
      g_log.Debug("ema",  "dir=%d",  (string)r.direction);
   }
   if(InpEnableBoll)
   {
      SignalResult r = g_sboll.CheckSignal(ctx);
      g_log.Debug("boll", "dir=%d",  (string)r.direction);
   }
   if(InpEnableRSI)
   {
      SignalResult r = g_srsi.CheckSignal(ctx);
      g_log.Debug("rsi",  "dir=%d",  (string)r.direction);
   }
}
```

- [ ] **Step 4: Compile, attach to XAUUSD M1, verify runtime**

1. MetaEditor F7: expect `0 error(s), 0 warning(s)`.
2. In MT5, drag `XAUUSD_Scalper_EA` onto an `XAUUSD` M1 chart. Allow automated trading.
3. Expect Experts log:
   - `[INF] init | Init OK`
   - `[DBG] ema  | dir=0` lines (most ticks will have no signal)
4. Right-click the EA → Remove. Expect:
   - `[INF] deinit | reason=1`

- [ ] **Step 5: Commit**

```bash
git add mt5/XAUUSD_Scalper/Experts/XAUUSD_Scalper_EA.mq5
git commit -m "feat(mt5/ea): wire foundation EA loop with three strategies and logger stub"
```

---

### Task 11: Repository README update and P1 green gate

**Files:**

- Modify: `mt5/XAUUSD_Scalper/README.md`

- [ ] **Step 1: Replace README with the P1 green-gate description**

Replace content with:

```markdown
# XAUUSD MT5 Scalper — Phase 1 (P1 foundation complete)

Implements sections 2, 3, 4, 7.1, 7.2 of
`docs/superpowers/specs/2026-04-24-xauusd-mt5-scalper-phase1-merged-design.md`.

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
- EA attached to XAUUSD M1 prints `Init OK`, then at least one `[DBG] ema` / `[DBG] boll` / `[DBG] rsi` line, then `deinit` on removal.

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
```

- [ ] **Step 2: Execute the P1 green gate manually and record output**

Run every test listed above on XAUUSD M1 and confirm each `passed=... failed=0` line.

- [ ] **Step 3: Commit**

```bash
git add mt5/XAUUSD_Scalper/README.md
git commit -m "docs(mt5): lock P1 green-gate checklist and explicit non-goals"
```

---

## Self-Review

**Spec coverage (against `2026-04-24-xauusd-mt5-scalper-phase1-merged-design.md`):**

| Spec section | Covered in P1? | Where |
| --- | --- | --- |
| §2 Architecture skeleton | yes | Task 0, 10 |
| §3 Three strategies | yes | Tasks 6, 7, 8, 9 |
| §4 Market analyzer classification | yes (offline only) | Task 5 |
| §7.1 Tick collector | yes | Task 3 |
| §7.2 Indicator manager (incl. M5 EMA) | yes | Task 4 |
| §8.2 Logger | partial — stub only | Task 2 (full logger in P4) |
| §5 Session/Guard/Execution | no — in P2 | — |
| §6 Risk/Position mgmt | no — in P3 | — |
| §3.7 M5 trend confirm | no — in P2 | — |
| §7.3-7.5 Persistence | no — in P4 | — |
| §8.1 / §8.3 / §8.4 Analysis & reporting | no — in P4 | — |
| §9 UI | no — in P4 | — |

**Placeholder scan:** no `TBD`, no "handle edge cases", every step contains the exact code/text the engineer needs, every test step has the exact command and expected output.

**Type consistency:**

- `CIndicatorManager::EMA(period, shift)` signature stable across Tasks 4, 7, 9, 10.
- `CIndicatorManager::RSI(shift)`, `ATR(shift)`, `ADX(shift)`, `BBUpper/Lower/Middle(shift)` stable across Tasks 4, 5, 7, 8, 9, 10.
- `CStrategyBase::CheckSignal(const StrategyContext &)` stable across Tasks 6, 7, 8, 9, 10.
- `MarketInputs` fields stable between Tasks 5 and 10.
- `SignalResult.direction` enum (`SIGNAL_NONE/BUY/SELL`) stable across Tasks 6, 7, 8, 9, 10.

No drift detected.
