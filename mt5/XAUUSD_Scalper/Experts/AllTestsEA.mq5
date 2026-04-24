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
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 6 - tr.Failed();
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
   double e5_prev, e5_curr, e10_prev, e10_curr, e20_curr, atr_curr;
   virtual double EMA(const int p, const int s) const override
     {
      if(p == 5)  return s == 1 ? e5_prev  : e5_curr;
      if(p == 10) return s == 1 ? e10_prev : e10_curr;
      if(p == 20) return e20_curr;
      return 0.0;
     }
   virtual double ATR(const int s) const override { return atr_curr; }
  };

void RunStrategyEMASuite()
{
   CTestRunner tr; tr.Begin("Test_StrategyEMA");
   FakeIMEMA im;
   im.e5_prev = 2400.00; im.e10_prev = 2400.10;
   im.e5_curr = 2400.20; im.e10_curr = 2400.10;
   im.e20_curr = 2399.50; im.atr_curr = 1.0;
   CStrategyEMA s; s.Configure(1.5, 1.2, 0.5, 2.0);
   StrategyContext ctx; ctx.im = &im; ctx.tc = NULL; ctx.state = MARKET_TRENDING;
   ctx.bid = 2400.30; ctx.ask = 2400.35; ctx.time = 0;
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bullish cross -> BUY", (int)SIGNAL_BUY, (int)r.direction);
   tr.AssertTrue("sl below bid", r.stop_loss < ctx.bid);
   tr.AssertTrue("tp above bid", r.take_profit > ctx.bid);
   im.e5_prev = 2400.30; im.e10_prev = 2400.20;
   im.e5_curr = 2400.00; im.e10_curr = 2400.20;
   im.e20_curr = 2400.50;
   ctx.bid = 2399.80; ctx.ask = 2399.85;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bearish cross -> SELL", (int)SIGNAL_SELL, (int)r.direction);
   im.e5_prev = 2400.00; im.e10_prev = 2399.90;
   im.e5_curr = 2400.10; im.e10_curr = 2399.95;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("no cross -> NONE", (int)SIGNAL_NONE, (int)r.direction);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 4 - tr.Failed();
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
   StrategyContext ctx; ctx.im = &im; ctx.state = MARKET_BREAKOUT; ctx.tc = NULL; ctx.time = 0;
   ctx.bid = 2400.15; ctx.ask = 2400.20;
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("upper breakout pullback -> BUY", (int)SIGNAL_BUY, (int)r.direction);
   ctx.bid = 2399.45; ctx.ask = 2399.50;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("lower breakout pullback -> SELL", (int)SIGNAL_SELL, (int)r.direction);
   ctx.bid = 2399.80; ctx.ask = 2399.85;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("inside band -> NONE", (int)SIGNAL_NONE, (int)r.direction);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 3 - tr.Failed();
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
   StrategyContext ctx; ctx.im = &im; ctx.tc = NULL; ctx.state = MARKET_RANGING; ctx.time = 0;
   im.rsi_prev = 20.0; im.rsi_curr = 22.0; im.e50 = 2400.00;
   ctx.bid = 2400.20; ctx.ask = 2400.25;
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("oversold rising -> BUY", (int)SIGNAL_BUY, (int)r.direction);
   im.rsi_prev = 80.0; im.rsi_curr = 78.0;
   ctx.bid = 2399.80; ctx.ask = 2399.85;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("overbought falling -> SELL", (int)SIGNAL_SELL, (int)r.direction);
   im.rsi_prev = 50.0; im.rsi_curr = 50.0;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("middle RSI -> NONE", (int)SIGNAL_NONE, (int)r.direction);
   im.rsi_prev = 20.0; im.rsi_curr = 22.0; im.e50 = 2395.00; ctx.bid = 2400.00;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("far from EMA50 -> NONE", (int)SIGNAL_NONE, (int)r.direction);
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 4 - tr.Failed();
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
   tr.AssertTrue ("monday 09:00 (london)",    sf.IsOpen(sf_mk(9, 0, 1)));
   tr.AssertTrue ("monday 14:30 (london+ny)", sf.IsOpen(sf_mk(14,30,1)));
   tr.AssertTrue ("monday 21:00 (ny)",        sf.IsOpen(sf_mk(21, 0,1)));
   tr.AssertFalse("monday 03:00 (asia)",      sf.IsOpen(sf_mk( 3, 0,1)));
   tr.AssertFalse("saturday 10:00",           sf.IsOpen(sf_mk(10, 0,6)));
   tr.AssertFalse("sunday 10:00",             sf.IsOpen(sf_mk(10, 0,0)));
   tr.End();
   g_total_failed += tr.Failed();
   g_total_passed += 6 - tr.Failed();
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
