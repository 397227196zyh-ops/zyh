#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/UI/CVisualizer.mqh>

// Smoke: instantiate, render once, clear. Asserts no GetLastError after the
// full create/render/clear cycle on an empty chart. Under the Strategy Tester
// the chart is available by default so the graphical calls are valid.

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_Dashboard_Smoke");

   CVisualizer v;
   v.Init(DASH_COMPACT);
   ResetLastError();

   DashSnapshot s;
   s.equity = 10000.0; s.floating_pnl = 12.3; s.open_positions = 2;
   s.spread = 0.05; s.atr = 0.40; s.adx = 18.0;
   s.market_state = 0; s.trend_state = 1; s.session_open = true;
   s.guard_reason = 0; s.liquidity_score = 72.0; s.ticks_per_sec = 6.0;

   CPerformanceTracker pt;
   pt.RecordTradeClosed(+4.0);
   pt.RecordTradeClosed(-2.0);

   v.RenderDashboard(s, pt);
   tr.AssertEqualInt("no error after render", 0, (long)GetLastError());

   v.OnOrderFilled(TimeCurrent(), 2400.00, +1);
   v.OnOrderClosed(TimeCurrent() + 60, 2400.75, +0.75);
   v.OnAnomaly    (TimeCurrent() + 120, "SPREAD");
   tr.AssertEqualInt("no error after events", 0, (long)GetLastError());

   v.Clear();
   tr.AssertEqualInt("no error after clear", 0, (long)GetLastError());

   tr.End();
}
