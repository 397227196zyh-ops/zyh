//+------------------------------------------------------------------+
//| AllTestsEA.mq5                                                   |
//|                                                                   |
//| Runs every P1 pure-computation unit test (everything except       |
//| Test_IndicatorManager, which needs real broker history) and       |
//| writes the combined result to MQL5/Files/xauusd_test_results.txt. |
//| Designed to run inside the Strategy Tester in "single test" mode  |
//| so it can be launched headlessly via metatester64.exe.            |
//+------------------------------------------------------------------+
#property strict

// Placeholder input so the Strategy Tester recognizes the EA and lets the
// user pick it from the dropdown. Value is unused.
input int InpTestTag = 0;

#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Analysis/CLoggerStub.mqh>
#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>
#include <XAUUSD_Scalper/Core/CMarketContext.mqh>
#include <XAUUSD_Scalper/Core/CSessionFilter.mqh>
#include <XAUUSD_Scalper/Core/CExecutionGuard.mqh>
#include <XAUUSD_Scalper/Core/CTrendConfirm.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBollinger.mqh>
#include <XAUUSD_Scalper/Core/CStrategyRSI.mqh>
#include <XAUUSD_Scalper/Data/CTradeLedger.mqh>
#include <XAUUSD_Scalper/Core/CRiskManager.mqh>
#include <XAUUSD_Scalper/Core/CExecutionEngine.mqh>
#include <XAUUSD_Scalper/Core/CPositionManager.mqh>
#include <XAUUSD_Scalper/Analysis/CPerformanceTracker.mqh>
#include <XAUUSD_Scalper/Analysis/CReportGenerator.mqh>

int g_total_failed = 0;
int g_total_passed = 0;

//+------------------------------------------------------------------+
//| Individual suites                                                 |
//+------------------------------------------------------------------+
void RunTestRunnerSuite()
{
   CTestRunner tr; tr.Begin("Test_TestRunner");
   tr.AssertTrue("true is true", true);
   tr.AssertFalse("false is false", false);
   tr.AssertEqualInt("int eq", 7, 7);
   tr.AssertEqualDouble("double eq", 1.2345, 1.2345, 1e-6);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 4 - tr.Failed();
}

void RunLoggerStubSuite()
{
   CTestRunner tr; tr.Begin("Test_LoggerStub");
   CLoggerStub log; log.SetLevel(LOG_LEVEL_DEBUG);
   log.Info ("alpha", "hello %s", "world");
   log.Warn ("alpha", "warn=%d", 42);
   tr.AssertTrue("logger level is DEBUG",  log.Level() == LOG_LEVEL_DEBUG);
   log.SetLevel(LOG_LEVEL_WARN);
   tr.AssertTrue("logger level changed to WARN", log.Level() == LOG_LEVEL_WARN);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 2 - tr.Failed();
}

void RunTickCollectorSuite()
{
   CTestRunner tr; tr.Begin("Test_TickCollector");
   CTickCollector tc; tc.Init(4);
   MqlTick t; t.time = (datetime)1000; t.bid = 2400.00; t.ask = 2400.05; t.last = 2400.02; t.volume = 1; t.flags = 0;
   tc.OnTick(t);
   t.time = 1001; t.bid = 2400.10; t.ask = 2400.15; tc.OnTick(t);
   t.time = 1002; t.bid = 2400.05; t.ask = 2400.10; tc.OnTick(t);
   t.time = 1003; t.bid = 2400.20; t.ask = 2400.30; tc.OnTick(t);
   t.time = 1004; t.bid = 2400.25; t.ask = 2400.35; tc.OnTick(t);
   tr.AssertEqualInt("count capped at capacity", 4, tc.Count());
   tr.AssertEqualDouble("last spread", 0.10, tc.LastSpread(), 1e-6);
   tr.AssertTrue("max jump >= 0.15", tc.MaxJump() + 1e-6 >= 0.15);
   tr.AssertTrue("ticks per sec >0", tc.TicksPerSecondEstimate() > 0.0);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 4 - tr.Failed();
}

void RunMarketAnalyzerSuite()
{
   CTestRunner tr; tr.Begin("Test_MarketAnalyzer");
   MarketInputs in;
   in.adx = 15; in.atr = 0.50; in.atr_avg = 0.50; in.bb_width = 0.80;
   in.last_spread = 0.05; in.max_jump = 0.10; in.ticks_per_s = 10.0; in.breakouts = 0;
   tr.AssertEqualInt("ranging", (int)MARKET_RANGING, (int)CMarketAnalyzer::Classify(in));
   in.adx = 30; in.atr = 1.0; in.atr_avg = 0.80; in.bb_width = 2.0; in.breakouts = 1;
   tr.AssertEqualInt("trending", (int)MARKET_TRENDING, (int)CMarketAnalyzer::Classify(in));
   in.adx = 22; in.atr = 1.0; in.atr_avg = 0.80; in.bb_width = 3.0; in.breakouts = 3;
   tr.AssertEqualInt("breakout", (int)MARKET_BREAKOUT, (int)CMarketAnalyzer::Classify(in));
   in.adx = 20; in.atr = 1.0; in.atr_avg = 0.80; in.ticks_per_s = 1.0;
   tr.AssertEqualInt("abnormal on tick collapse", (int)MARKET_ABNORMAL, (int)CMarketAnalyzer::Classify(in));
   in.ticks_per_s = 10.0; in.last_spread = 0.20;
   tr.AssertEqualInt("abnormal on spread blowout", (int)MARKET_ABNORMAL, (int)CMarketAnalyzer::Classify(in));
   in.last_spread = 0.05; in.atr = 3.0; in.atr_avg = 0.80;
   tr.AssertEqualInt("abnormal on ATR blowout", (int)MARKET_ABNORMAL, (int)CMarketAnalyzer::Classify(in));
   in.adx = 42; in.atr = 0.50; in.atr_avg = 0.50; in.bb_width = 0.80; in.breakouts = 0;
   in.ticks_per_s = 10.0; in.last_spread = 0.05; in.max_jump = 0.10;
   tr.AssertEqualInt("trending on high ADX flat ATR", (int)MARKET_TRENDING, (int)CMarketAnalyzer::Classify(in));
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 7 - tr.Failed();
}

class CNullStrategy : public CStrategyBase
  {
public:
                     CNullStrategy() { m_name = "NULL"; m_magic = 111; }
   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r; r.direction = SIGNAL_NONE; r.stop_loss = 0; r.take_profit = 0; return r;
     }
  };

void RunStrategyBaseSuite()
{
   CTestRunner tr; tr.Begin("Test_StrategyBase");
   CNullStrategy s;
   tr.AssertTrue("name NULL", s.Name() == "NULL");
   tr.AssertEqualInt("magic 111", 111, (long)s.Magic());
   s.OnTradeClosed(+10.0); s.OnTradeClosed(-4.0); s.OnTradeClosed(+6.0);
   tr.AssertEqualInt("trades 3", 3, (long)s.Trades());
   tr.AssertEqualInt("wins 2",   2, (long)s.Wins());
   tr.AssertEqualDouble("gross pnl 12.0", 12.0, s.GrossPnL(), 1e-6);
   double f = s.CalculateKellyFraction(30, 0.55, 1.2);
   tr.AssertTrue("cold-start kelly > 0", f > 0.0);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 7 - tr.Failed();
}

class FakeIMEMA : public CIndicatorManager
  {
public:
   double e5_2, e5_1, e10_2, e10_1, e20_1, atr_1;
   virtual double EMA(const int p, const int s) const override
     {
      if(p == 5)  return s == 2 ? e5_2  : e5_1;
      if(p == 10) return s == 2 ? e10_2 : e10_1;
      if(p == 20) return e20_1;
      return 0.0;
     }
   virtual double ATR(const int s) const override { return atr_1; }
  };

void RunStrategyEMASuite()
{
   CTestRunner tr; tr.Begin("Test_StrategyEMA");
   FakeIMEMA im;
   im.e5_2 = 2400.00; im.e10_2 = 2400.10;
   im.e5_1 = 2400.20; im.e10_1 = 2400.10;
   im.e20_1 = 2399.50; im.atr_1 = 1.0;
   CStrategyEMA s; s.Configure(1.5, 1.2, 0.5, 2.0);
   StrategyContext ctx; ctx.im = &im; ctx.tc = NULL; ctx.state = MARKET_TRENDING;
   ctx.bid = 2400.30; ctx.ask = 2400.35; ctx.time = 60;
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bullish cross -> BUY", (int)SIGNAL_BUY, (int)r.direction);
   tr.AssertTrue    ("sl below bid",        r.stop_loss < ctx.bid);
   tr.AssertTrue    ("tp above bid",        r.take_profit > ctx.bid);
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("same bar suppressed", (int)SIGNAL_NONE, (int)r.direction);

   im.e5_2 = 2400.30; im.e10_2 = 2400.20;
   im.e5_1 = 2400.00; im.e10_1 = 2400.20;
   im.e20_1 = 2400.50;
   ctx.bid = 2399.80; ctx.ask = 2399.85; ctx.time = 120;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bearish cross -> SELL", (int)SIGNAL_SELL, (int)r.direction);

   im.e5_2 = 2400.00; im.e10_2 = 2399.90;
   im.e5_1 = 2400.10; im.e10_1 = 2399.95;
   ctx.time = 180;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("no cross -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 5 - tr.Failed();
}

class FakeIMBoll : public CIndicatorManager
  {
public:
   double up_prev, up_curr, lo_prev, lo_curr, mid;
   virtual double BBUpper(const int s) const override  { return s == 1 ? up_prev : up_curr; }
   virtual double BBLower(const int s) const override  { return s == 1 ? lo_prev : lo_curr; }
   virtual double BBMiddle(const int s) const override { return mid; }
  };

void RunStrategyBollingerSuite()
{
   CTestRunner tr; tr.Begin("Test_StrategyBollinger");
   FakeIMBoll im; im.up_prev = 2400.00; im.up_curr = 2400.05;
                   im.lo_prev = 2399.50; im.lo_curr = 2399.55; im.mid = 2399.80;
   CStrategyBollinger s; s.Configure(0.2, 1.0, 0.8);
   StrategyContext ctx; ctx.im = &im; ctx.state = MARKET_BREAKOUT; ctx.tc = NULL;
   ctx.bid = 2400.15; ctx.ask = 2400.20; ctx.time = 60;
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("upper breakout pullback -> BUY", (int)SIGNAL_BUY, (int)r.direction);
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("same bar suppressed",            (int)SIGNAL_NONE, (int)r.direction);
   ctx.bid = 2399.45; ctx.ask = 2399.50; ctx.time = 120;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("lower breakout pullback -> SELL", (int)SIGNAL_SELL, (int)r.direction);
   ctx.bid = 2399.80; ctx.ask = 2399.85; ctx.time = 180;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("inside band -> NONE", (int)SIGNAL_NONE, (int)r.direction);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 4 - tr.Failed();
}

class FakeIMRSI : public CIndicatorManager
  {
public:
   double rsi_prev, rsi_curr, e50;
   virtual double RSI(const int s) const override { return s == 1 ? rsi_prev : rsi_curr; }
   virtual double EMA(const int p, const int s) const override { return p == 50 ? e50 : 0.0; }
  };

void RunStrategyRSISuite()
{
   CTestRunner tr; tr.Begin("Test_StrategyRSI");
   FakeIMRSI im; CStrategyRSI s; s.Configure(25.0, 75.0, 1.5, 0.6, 0.5);
   StrategyContext ctx; ctx.im = &im; ctx.tc = NULL; ctx.state = MARKET_RANGING;
   im.rsi_prev = 20.0; im.rsi_curr = 22.0; im.e50 = 2400.00;
   ctx.bid = 2400.20; ctx.ask = 2400.25; ctx.time = 60;
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("oversold rising -> BUY", (int)SIGNAL_BUY, (int)r.direction);
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("same bar suppressed",   (int)SIGNAL_NONE, (int)r.direction);
   im.rsi_prev = 80.0; im.rsi_curr = 78.0;
   ctx.bid = 2399.80; ctx.ask = 2399.85; ctx.time = 120;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("overbought falling -> SELL", (int)SIGNAL_SELL, (int)r.direction);
   im.rsi_prev = 50.0; im.rsi_curr = 50.0; ctx.time = 180;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("middle RSI -> NONE", (int)SIGNAL_NONE, (int)r.direction);
   im.rsi_prev = 20.0; im.rsi_curr = 22.0; im.e50 = 2395.00;
   ctx.bid = 2400.00; ctx.time = 240;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("far from EMA50 -> NONE", (int)SIGNAL_NONE, (int)r.direction);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 5 - tr.Failed();
}

//+------------------------------------------------------------------+
//| P2 suites                                                         |
//+------------------------------------------------------------------+
datetime sf_mk(const int h, const int m, const int dow)
{
   // Pick a concrete April 2026 day that actually falls on the requested dow.
   // 2026-04-19 = Sun, 20 = Mon, 21 = Tue, 22 = Wed, 23 = Thu, 24 = Fri, 25 = Sat.
   int day;
   switch(dow)
     {
      case 0: day = 19; break;
      case 1: day = 20; break;
      case 2: day = 21; break;
      case 3: day = 22; break;
      case 4: day = 23; break;
      case 5: day = 24; break;
      case 6: day = 25; break;
      default: day = 20; break;
     }
   MqlDateTime d; d.year=2026; d.mon=4; d.day=day; d.hour=h; d.min=m; d.sec=0; d.day_of_year=0; d.day_of_week=dow;
   return StructToTime(d);
}

void RunSessionFilterSuite()
{
   CTestRunner tr; tr.Begin("Test_SessionFilter");
   CSessionFilter sf; sf.Configure(7,16,13,22);
   sf.SetBrokerOffsetForTest(0);
   tr.AssertTrue ("monday 09:00 (london)",    sf.IsOpen(sf_mk(9, 0, 1)));
   tr.AssertTrue ("monday 14:30 (london+ny)", sf.IsOpen(sf_mk(14,30,1)));
   tr.AssertTrue ("monday 21:00 (ny)",        sf.IsOpen(sf_mk(21, 0,1)));
   tr.AssertFalse("monday 03:00 (asia)",      sf.IsOpen(sf_mk( 3, 0,1)));
   tr.AssertFalse("saturday 10:00",           sf.IsOpen(sf_mk(10, 0,6)));
   tr.AssertFalse("sunday 10:00",             sf.IsOpen(sf_mk(10, 0,0)));

   sf.SetBrokerOffsetForTest(3);
   // GMT+3 broker: broker hour H == UTC hour H-3.
   tr.AssertTrue ("GMT+3 broker 10:00 -> london open",       sf.IsOpen(sf_mk(10, 0, 1)));
   tr.AssertFalse("GMT+3 broker 09:00 -> closed (UTC 06)",   sf.IsOpen(sf_mk( 9, 0, 1)));
   tr.AssertTrue ("GMT+3 broker 18:30 -> NY open (UTC 15:30)", sf.IsOpen(sf_mk(18,30, 1)));

   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 9 - tr.Failed();
}

void RunMarketContextSuite()
{
   CTestRunner tr; tr.Begin("Test_MarketContext");
   CMarketContext ctx; ctx.Init(50, 20);
   for(int i=0;i<50;i++) ctx.PushATRSample(0.5);
   tr.AssertEqualDouble("atr avg 0.5", 0.5, ctx.ATRAverage(), 1e-9);
   for(int i=0;i<50;i++) ctx.PushATRSample(1.0);
   tr.AssertEqualDouble("atr avg 1.0 after saturation", 1.0, ctx.ATRAverage(), 1e-9);
   ctx.PushBreakout(); ctx.PushBreakout();
   tr.AssertEqualInt("breakouts 2", 2, (long)ctx.BreakoutCount());
   MarketInputs mi = ctx.BuildInputs(30, 1.2, 2.2, 0.05, 0.10, 12.0);
   tr.AssertTrue("inputs atr_avg=1.0", MathAbs(mi.atr_avg - 1.0) < 1e-9);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 4 - tr.Failed();
}

void RunExecutionGuardSuite()
{
   CTestRunner tr; tr.Begin("Test_ExecutionGuard");
   CExecutionGuard g; g.Configure(0.08, 0.1, 60, 2.0, 5);
   GuardInputs in;
   in.session_open=true; in.spread=0.05; in.stops_level=0.02; in.freeze_level=0.01;
   in.market_state=MARKET_TRENDING; in.now=(datetime)1000; in.last_fail_time=0;
   in.daily_loss_pct=0.0; in.consec_losses=0;
   GuardDecision d = g.Evaluate(in);
   tr.AssertTrue     ("all good -> allowed",            d.allowed);
   tr.AssertEqualInt ("reason_code OK",                 (int)GUARD_OK,             (int)d.reason);
   in.session_open=false;
   d = g.Evaluate(in);
   tr.AssertEqualInt ("session closed -> SESSION",      (int)GUARD_SESSION_CLOSED, (int)d.reason);
   in.session_open=true; in.spread=0.20;
   d = g.Evaluate(in);
   tr.AssertEqualInt ("spread high -> SPREAD",          (int)GUARD_SPREAD,         (int)d.reason);
   in.spread=0.05; in.market_state=MARKET_ABNORMAL;
   d = g.Evaluate(in);
   tr.AssertEqualInt ("abnormal -> ABNORMAL",           (int)GUARD_ABNORMAL_MARKET,(int)d.reason);
   in.market_state=MARKET_TRENDING; in.consec_losses=10;
   d = g.Evaluate(in);
   tr.AssertEqualInt ("consec losses -> CONSEC",        (int)GUARD_CONSEC_LOSSES,  (int)d.reason);
   in.consec_losses=0; in.daily_loss_pct=5.0;
   d = g.Evaluate(in);
   tr.AssertEqualInt ("daily loss -> DAILY",            (int)GUARD_DAILY_LOSS,     (int)d.reason);
   in.daily_loss_pct=0.0; in.last_fail_time=(datetime)995; in.now=(datetime)1000;
   d = g.Evaluate(in);
   tr.AssertEqualInt ("cooldown -> COOLDOWN",           (int)GUARD_COOLDOWN,       (int)d.reason);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 7 - tr.Failed();
}

class FakeIMTrend : public CIndicatorManager
  {
public:
   double e20_m5[3];
   double e50_m5;
   virtual double EMA20_M5(const int s) const override { return e20_m5[s]; }
   virtual double EMA50_M5(const int s) const override { return e50_m5; }
  };

void RunTrendConfirmSuite()
{
   CTestRunner tr; tr.Begin("Test_TrendConfirm");
   FakeIMTrend im; CTrendConfirm tc;
   im.e50_m5 = 2399.00; im.e20_m5[0]=2400.5; im.e20_m5[1]=2400.2; im.e20_m5[2]=2400.0;
   tr.AssertEqualInt("bullish M5", (int)TREND_BULLISH, (int)tc.Classify(im, 2400.60));
   im.e50_m5 = 2401.00; im.e20_m5[0]=2399.5; im.e20_m5[1]=2399.7; im.e20_m5[2]=2399.9;
   tr.AssertEqualInt("bearish M5", (int)TREND_BEARISH, (int)tc.Classify(im, 2399.40));
   im.e50_m5 = 2400.00; im.e20_m5[0]=2400.05; im.e20_m5[1]=2400.00; im.e20_m5[2]=2400.00;
   tr.AssertEqualInt("neutral M5", (int)TREND_NEUTRAL, (int)tc.Classify(im, 2400.02));
   tr.AssertTrue ("EMA bullish+BUY passes",   tc.Allows("EMA",  SIGNAL_BUY,  TREND_BULLISH, 2400.02, 2400.00));
   tr.AssertFalse("EMA bearish+BUY rejects",  tc.Allows("EMA",  SIGNAL_BUY,  TREND_BEARISH, 2400.02, 2400.00));
   tr.AssertTrue ("BOLL bullish+BUY passes",  tc.Allows("BOLL", SIGNAL_BUY,  TREND_BULLISH, 2400.02, 2400.00));
   tr.AssertFalse("BOLL neutral+BUY rejects", tc.Allows("BOLL", SIGNAL_BUY,  TREND_NEUTRAL, 2400.02, 2400.00));
   tr.AssertTrue ("RSI neutral+BUY passes",   tc.Allows("RSI",  SIGNAL_BUY,  TREND_NEUTRAL, 2400.02, 2400.00));
   tr.AssertFalse("RSI bearish+BUY rejects",  tc.Allows("RSI",  SIGNAL_BUY,  TREND_BEARISH, 2400.02, 2400.00));
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 9 - tr.Failed();
}

//+------------------------------------------------------------------+
//| P3 suites                                                         |
//+------------------------------------------------------------------+
void RunTradeLedgerSuite()
{
   CTestRunner tr; tr.Begin("Test_TradeLedger");
   CTradeLedger L; L.Init();

   tr.AssertEqualInt    ("initial consec EMA = 0",           0, (long)L.ConsecLosses("EMA"));
   tr.AssertEqualDouble ("initial daily pct = 0",            0.0, L.DailyLossPct(10000.0), 1e-9);
   tr.AssertTrue        ("initial last fail = 0",            L.LastFailTime() == 0);

   L.OnTradeClosed("EMA", -10.0, (datetime)100);
   L.OnTradeClosed("EMA", -10.0, (datetime)200);
   L.OnTradeClosed("EMA", -10.0, (datetime)300);
   tr.AssertEqualInt    ("consec=3 after 3 losses",          3, (long)L.ConsecLosses("EMA"));
   tr.AssertEqualDouble ("dailyPct=0.3 after 30 loss",       0.3, L.DailyLossPct(10000.0), 1e-9);

   L.OnTradeClosed("EMA", +5.0, (datetime)400);
   tr.AssertEqualInt    ("consec resets on win",             0, (long)L.ConsecLosses("EMA"));

   L.OnDayRollover((datetime)500);
   tr.AssertEqualDouble ("dailyPct resets after rollover",   0.0, L.DailyLossPct(10000.0), 1e-9);
   tr.AssertEqualInt    ("consec NOT reset by rollover",     0, (long)L.ConsecLosses("EMA"));

   L.OnTradeFailed((datetime)1000);
   tr.AssertTrue        ("last fail = 1000",                 L.LastFailTime() == (datetime)1000);

   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 9 - tr.Failed();
}

void RunRiskManagerSuite()
{
   CTestRunner tr; tr.Begin("Test_RiskManager");
   CRiskManager rm;
   RiskInputs in;

   in.account_equity     = 10000.0;
   in.base_risk_pct      = 0.5;
   in.total_risk_cap_pct = 5.0;
   in.sl_distance        = 1.0;
   in.sl_per_lot_ccy     = 100.0;
   in.kelly_fraction     = 0.5;
   in.open_risk_ccy      = 0.0;
   in.min_lot            = 0.01;
   in.max_lot            = 5.0;
   in.lot_step           = 0.01;
   in.commission_per_lot = 0.0;
   in.allow_min_lot_fallback = false;

   RiskDecision d = rm.Size(in);
   tr.AssertTrue        ("baseline allowed",                 d.allowed);
   tr.AssertEqualDouble ("baseline lot = 0.25",              0.25, d.lot, 1e-9);

   RiskInputs bad = in; bad.kelly_fraction = 0.0;
   d = rm.Size(bad);
   tr.AssertTrue        ("kelly 0 rejected",                 !d.allowed);
   tr.AssertTrue        ("kelly 0 reason NON_POSITIVE_KELLY",d.reason == "NON_POSITIVE_KELLY");

   bad = in; bad.sl_per_lot_ccy = 0.0;
   d = rm.Size(bad);
   tr.AssertTrue        ("invalid SL rejected",              !d.allowed);
   tr.AssertTrue        ("invalid SL reason INVALID_SL",     d.reason == "INVALID_SL");

   bad = in; bad.open_risk_ccy = 499.0;
   d = rm.Size(bad);
   tr.AssertTrue        ("over cap rejected",                !d.allowed);
   tr.AssertTrue        ("over cap reason TOTAL_RISK_CAP",   d.reason == "TOTAL_RISK_CAP");

   bad = in; bad.open_risk_ccy = 475.0;
   d = rm.Size(bad);
   tr.AssertTrue        ("boundary at cap allowed",          d.allowed);

   bad = in; bad.kelly_fraction = 0.001;
   d = rm.Size(bad);
   tr.AssertTrue        ("below min rejected",               !d.allowed);
   tr.AssertTrue        ("below min reason BELOW_MIN_LOT",   d.reason == "BELOW_MIN_LOT");

   bad = in; bad.kelly_fraction = 0.001; bad.allow_min_lot_fallback = true;
   d = rm.Size(bad);
   tr.AssertTrue        ("min lot fallback allowed",         d.allowed);
   tr.AssertEqualDouble ("fallback lot = min_lot",           0.01, d.lot, 1e-9);
   tr.AssertTrue        ("fallback reason MIN_LOT_FALLBACK", d.reason == "MIN_LOT_FALLBACK");

   bad = in; bad.commission_per_lot = 100.0;
   d = rm.Size(bad);
   tr.AssertTrue        ("commission baseline allowed",      d.allowed);
   tr.AssertEqualDouble ("commission shrinks lot to 0.12",   0.12, d.lot, 1e-9);

   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 16 - tr.Failed();
}

void RunExecutionEngineSmokeSuite()
{
   CTestRunner tr; tr.Begin("Test_ExecutionEngine_Smoke");
   CExecutionEngine e;
   e.SetSymbol("XAUUSD"); e.SetMagic(7010999);
   e.Configure(3, 100, 0.10, 5); e.SetDryRun(true);

   ExecutionResult r = e.PlaceMarket(+1, 0.01, 0.0, 0.0, 2400.0);
   tr.AssertFalse("dry-run market does not fill", r.filled);
   tr.AssertTrue ("dry-run market reason DRY_RUN", r.reason_str == "DRY_RUN");

   r = e.PlaceLimit(-1, 0.01, 2401.0, 0.0, 0.0);
   tr.AssertFalse("dry-run limit does not fill", r.filled);
   tr.AssertTrue ("dry-run limit reason DRY_RUN", r.reason_str == "DRY_RUN");
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 4 - tr.Failed();
}

void RunPositionManagerSuite()
{
   CTestRunner tr; tr.Begin("Test_PositionManager");

   CPositionManager pm;
   PosMgrConfig cfg;
   cfg.partial_r_threshold    = 1.0;
   cfg.partial_close_fraction = 0.5;
   cfg.breakeven_buffer       = 0.10;
   cfg.trail_atr_mult         = 1.0;
   cfg.max_hold_bars          = 60;
   cfg.max_adds               = 2;
   cfg.pyramid_r_threshold    = 0.5;
   cfg.pyramid_min_distance   = 0.20;
   pm.Configure(cfg);

   CExecutionEngine eng;
   eng.SetSymbol("XAUUSD"); eng.SetMagic(7010001); eng.SetDryRun(true);

   int idx = pm.OnFill(1001, 7010001, "EMA",
                       +1, 2400.00, 2399.00, 2402.00, 0.10, (datetime)1000, true);
   tr.AssertEqualInt("initial state OPEN", (int)POS_STATE_OPEN, (int)pm.At(idx).state);

   pm.Step(idx, eng, 2400.05, 2400.10, 0.30, 0);
   tr.AssertEqualInt("no move -> still OPEN", (int)POS_STATE_OPEN, (int)pm.At(idx).state);

   pm.Step(idx, eng, 2401.00, 2401.10, 0.30, 1);
   tr.AssertEqualInt   ("at +1R -> PARTIAL_DONE",  (int)POS_STATE_PARTIAL_DONE, (int)pm.At(idx).state);
   tr.AssertEqualDouble("volume halved to 0.05",   0.05, pm.At(idx).volume, 1e-9);
   tr.AssertEqualDouble("SL moved to 2400.10",     2400.10, pm.At(idx).current_sl, 1e-9);

   pm.Step(idx, eng, 2402.00, 2402.10, 0.30, 0);
   tr.AssertEqualInt   ("trailing engaged",        (int)POS_STATE_TRAILING, (int)pm.At(idx).state);
   tr.AssertEqualDouble("trailing SL = 2401.70",   2401.70, pm.At(idx).current_sl, 1e-9);

   int head = pm.OnFill(1002, 7010001, "EMA",
                        +1, 2410.00, 2409.00, 2412.00, 0.10, (datetime)2000, true);

   tr.AssertFalse("pyramid rejected before +0.5R",
      pm.AllowPyramid(head, +1, 2410.25, MARKET_TRENDING, TREND_BULLISH, 2410.20, 2410.25));

   tr.AssertTrue ("pyramid allowed at +0.5R bullish",
      pm.AllowPyramid(head, +1, 2410.80, MARKET_TRENDING, TREND_BULLISH, 2410.50, 2410.55));

   tr.AssertFalse("pyramid rejected on trend flip",
      pm.AllowPyramid(head, +1, 2410.80, MARKET_TRENDING, TREND_BEARISH, 2410.50, 2410.55));

   pm.OnPyramidAdded(head);
   pm.OnPyramidAdded(head);
   tr.AssertFalse("pyramid rejected after 2 adds",
      pm.AllowPyramid(head, +1, 2410.80, MARKET_TRENDING, TREND_BULLISH, 2410.50, 2410.55));

   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 11 - tr.Failed();
}

//+------------------------------------------------------------------+
//| P4 suites (pure computation only — Logger / CSV / Dashboard have  |
//| their own Script harnesses since they touch files / chart objects)|
//+------------------------------------------------------------------+
void RunPerformanceTrackerSuite()
{
   CTestRunner tr; tr.Begin("Test_PerformanceTracker");
   CPerformanceTracker pt;

   pt.RecordTradeClosed(+10.0);
   pt.RecordTradeClosed(+5.0);
   pt.RecordTradeClosed(-4.0);
   tr.AssertEqualInt    ("total trades 3",          3, (long)pt.Returns().total_trades);
   tr.AssertEqualDouble ("win rate 0.6667",         0.6666666666, pt.WinRate(), 1e-6);
   tr.AssertEqualDouble ("payoff = 7.5/4 = 1.875",  1.875, pt.PayoffRatio(), 1e-6);

   pt.RecordCandidate(); pt.RecordCandidate(); pt.RecordCandidate();
   pt.RecordRejectSession(); pt.RecordRejectGuard(); pt.RecordFilled();
   SignalQualityStats sq = pt.SignalQuality();
   tr.AssertEqualInt("signal candidates 3", 3, (long)sq.candidates);
   tr.AssertEqualInt("signal filled 1",     1, (long)sq.filled);

   pt.RecordFill(0.02, 30, false);
   pt.RecordFill(0.04, 20, true);
   pt.RecordReject();
   tr.AssertEqualDouble ("avg slippage 0.03",  0.03, pt.AvgSlippage(), 1e-9);
   tr.AssertEqualDouble ("reject rate 1/3",    0.3333333333, pt.RejectRate(), 1e-6);
   tr.AssertEqualInt    ("limit fills 1",      1, (long)pt.ExecutionQuality().limit_fills);

   pt.RecordPartial(); pt.RecordPartial();
   pt.RecordTrailExit(+3.0);
   pt.RecordTimeoutExit(-0.5);
   PositionMgmtStats pm = pt.PositionManagement();
   tr.AssertEqualInt    ("partial triggered 2",  2, (long)pm.partial_triggered);
   tr.AssertEqualInt    ("trail exits 1",        1, (long)pm.trail_exits);
   tr.AssertEqualDouble ("trail pnl sum 3.0",    3.0, pm.trail_pnl_sum, 1e-9);

   pt.RecordAdd(+1.2); pt.RecordAdd(+0.8);
   pt.RecordAddRejected();
   pt.RecordPyramidDrawdown(0.35);
   PyramidingStats py = pt.Pyramiding();
   tr.AssertEqualInt    ("adds done 2",             2, (long)py.adds_done);
   tr.AssertEqualDouble ("adds pnl sum 2.0",        2.0, py.pyramid_pnl_sum, 1e-9);
   tr.AssertEqualDouble ("adds max drawdown 0.35",  0.35, py.pyramid_max_drawdown, 1e-9);

   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 14 - tr.Failed();
}

void RunReportGeneratorSuite()
{
   CTestRunner tr; tr.Begin("Test_ReportGenerator");

   CPerformanceTracker pt;
   // Replay a long-ish sequence so the overview/signal/execution/position/
   // pyramiding sections end up with non-trivial numeric content and the
   // guard bar section gets enough labels to cross 5 KB in the HTML body.
   double pnls[] = {+12.5, -6.0, +4.0, -3.5, +8.2, +1.1, -2.2, +5.5, -1.0, +3.3};
   for(int i = 0; i < ArraySize(pnls); i++)
      pt.RecordTradeClosed(pnls[i]);
   for(int i = 0; i < 20; i++) pt.RecordCandidate();
   for(int i = 0; i < 12; i++) pt.RecordFilled();
   for(int i = 0; i < 6;  i++) pt.RecordFill(0.02 + 0.01 * i, 20 + 5 * i, (i % 2) == 0);
   for(int i = 0; i < 3;  i++) pt.RecordReject();
   pt.RecordLimitTimeout();
   pt.RecordPartial(); pt.RecordPartial();
   pt.RecordTrailExit(+3.0); pt.RecordTrailExit(+2.5);
   pt.RecordTimeoutExit(-0.5);
   pt.RecordBeatenAfterBE();
   pt.RecordAdd(+1.2); pt.RecordAdd(+0.8); pt.RecordAddRejected();
   pt.RecordPyramidDrawdown(0.45);

   EquityPoint eq[]; ArrayResize(eq, 40);
   double equity_value = 10000.0;
   for(int i = 0; i < 40; i++)
     {
      equity_value += (i % 3 == 0) ? 8.5 : -2.0;
      eq[i].time   = (datetime)(1000 + 60 * i);
      eq[i].equity = equity_value;
     }

   TradeReportRow trades[]; ArrayResize(trades, 40);
   string names[] = {"EMA", "BOLL", "RSI"};
   for(int i = 0; i < 40; i++)
     {
      trades[i].time  = (datetime)(2000 + 120 * i);
      trades[i].strat = names[i % 3];
      trades[i].dir   = (i % 2 == 0) ? +1 : -1;
      trades[i].entry = 2400.0 + i * 0.25;
      trades[i].exit  = trades[i].entry + ((i % 2 == 0) ? +0.80 : -0.60);
      trades[i].pnl   = (trades[i].exit - trades[i].entry) * trades[i].dir * 10.0;
     }

   GuardBar bars[]; ArrayResize(bars, 6);
   bars[0].reason = "SPREAD";          bars[0].count = 9;
   bars[1].reason = "SESSION_CLOSED";  bars[1].count = 11;
   bars[2].reason = "ABNORMAL_MARKET"; bars[2].count = 4;
   bars[3].reason = "CONSEC_LOSSES";   bars[3].count = 3;
   bars[4].reason = "DAILY_LOSS";      bars[4].count = 2;
   bars[5].reason = "COOLDOWN";        bars[5].count = 5;

   CReportGenerator gen;
   string html = gen.BuildHTML(pt, eq, trades, bars);
   tr.AssertTrue ("html has title marker",    StringFind(html, "<title>XAUUSD Scalper Report") >= 0);
   tr.AssertTrue ("html has equity data",     StringFind(html, "const EQUITY_DATA =")          >= 0);
   tr.AssertTrue ("html has guard section",   StringFind(html, "guard_reason_distribution")    >= 0);
   tr.AssertTrue ("html > 5KB",               StringLen(html) > 5 * 1024);

   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 4 - tr.Failed();
}

//+------------------------------------------------------------------+
bool g_tests_done = false;

void WriteSummary()
{
   string line = StringFormat("ALLTESTS: passed=%d failed=%d", g_total_passed, g_total_failed);
   Print(line);
   int fh = FileOpen("xauusd_test_results.txt", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fh != INVALID_HANDLE)
     {
      FileWrite(fh, line);
      FileClose(fh);
      Print("ALLTESTS: results file written to MQL5/Files/xauusd_test_results.txt");
     }
   else
     {
      PrintFormat("ALLTESTS: failed to open results file, error=%d", GetLastError());
     }
}

void RunAllSuites()
{
   if(g_tests_done) return;
   g_tests_done = true;

   g_total_failed = 0;
   g_total_passed = 0;

   RunTestRunnerSuite();
   RunLoggerStubSuite();
   RunTickCollectorSuite();
   RunMarketAnalyzerSuite();
   RunStrategyBaseSuite();
   RunStrategyEMASuite();
   RunStrategyBollingerSuite();
   RunStrategyRSISuite();
   RunSessionFilterSuite();
   RunMarketContextSuite();
   RunExecutionGuardSuite();
   RunTrendConfirmSuite();
   RunTradeLedgerSuite();
   RunRiskManagerSuite();
   RunExecutionEngineSmokeSuite();
   RunPositionManagerSuite();
   RunPerformanceTrackerSuite();
   RunReportGeneratorSuite();

   WriteSummary();
}

int OnInit()
{
   // Run suites immediately on init; also set a 1s timer as a safety net
   // (some tester modes may not deliver OnTick before terminating).
   RunAllSuites();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   RunAllSuites();
}

void OnTimer()
{
   RunAllSuites();
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(!g_tests_done) RunAllSuites();
}

// Strategy Tester entry point. Return value drives "Balance" column in Tester;
// 0 is fine. Without this OnTester, Tester runs but never calls OnDeinit on
// "real ticks" mode if the EA hasn't produced trades — we don't care.
double OnTester()
{
   if(!g_tests_done) RunAllSuites();
   return 0.0;
}
