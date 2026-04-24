#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Analysis/CReportGenerator.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_ReportGenerator");

   CPerformanceTracker pt;
   pt.RecordTradeClosed(+12.5);
   pt.RecordTradeClosed(-6.0);
   pt.RecordTradeClosed(+4.0);
   pt.RecordCandidate(); pt.RecordFilled(); pt.RecordFilled();
   pt.RecordFill(0.02, 25, false); pt.RecordFill(0.04, 30, true);
   pt.RecordReject();
   pt.RecordPartial(); pt.RecordTrailExit(+3.5); pt.RecordTimeoutExit(-0.2);
   pt.RecordAdd(+1.4); pt.RecordAddRejected();

   EquityPoint eq[]; ArrayResize(eq, 3);
   eq[0].time = (datetime)1000; eq[0].equity = 10000.0;
   eq[1].time = (datetime)2000; eq[1].equity = 10012.5;
   eq[2].time = (datetime)3000; eq[2].equity = 10006.5;

   TradeReportRow trades[]; ArrayResize(trades, 2);
   trades[0].time = (datetime)2000; trades[0].strat = "EMA";
   trades[0].dir  = +1;  trades[0].entry = 2400.00; trades[0].exit = 2401.25; trades[0].pnl = 12.5;
   trades[1].time = (datetime)3000; trades[1].strat = "BOLL";
   trades[1].dir  = -1;  trades[1].entry = 2402.00; trades[1].exit = 2402.60; trades[1].pnl = -6.0;

   GuardBar bars[]; ArrayResize(bars, 3);
   bars[0].reason = "SPREAD";   bars[0].count = 4;
   bars[1].reason = "SESSION";  bars[1].count = 7;
   bars[2].reason = "ABNORMAL"; bars[2].count = 2;

   CReportGenerator gen;
   string html = gen.BuildHTML(pt, eq, trades, bars);

   tr.AssertTrue("html contains title marker",
      StringFind(html, "<title>XAUUSD Scalper Report") >= 0);
   tr.AssertTrue("html contains equity data marker",
      StringFind(html, "const EQUITY_DATA =") >= 0);
   tr.AssertTrue("html contains guard distribution marker",
      StringFind(html, "guard_reason_distribution") >= 0);
   tr.AssertTrue("html size > 5KB",
      StringLen(html) > 5 * 1024);

   string path = "XAUUSD_Scalper/tests/report_test.html";
   tr.AssertTrue("writes html to disk", gen.Write(path, html));

   tr.End();
}
