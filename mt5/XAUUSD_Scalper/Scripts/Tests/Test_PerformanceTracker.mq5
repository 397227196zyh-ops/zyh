#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Analysis/CPerformanceTracker.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_PerformanceTracker");

   CPerformanceTracker pt;

   // Returns: 2 wins + 1 loss -> winrate 0.6667, payoff = avg_w/avg_l
   pt.RecordTradeClosed(+10.0);
   pt.RecordTradeClosed(+5.0);
   pt.RecordTradeClosed(-4.0);
   tr.AssertEqualInt    ("total trades 3",         3,    (long)pt.Returns().total_trades);
   tr.AssertEqualDouble ("win rate 0.6667",        0.6666666666, pt.WinRate(), 1e-6);
   tr.AssertEqualDouble ("payoff = 7.5/4 = 1.875", 1.875, pt.PayoffRatio(), 1e-6);

   // Signal quality
   pt.RecordCandidate(); pt.RecordCandidate(); pt.RecordCandidate();
   pt.RecordRejectSession(); pt.RecordRejectGuard(); pt.RecordFilled();
   SignalQualityStats sq = pt.SignalQuality();
   tr.AssertEqualInt("signal candidates 3",  3, (long)sq.candidates);
   tr.AssertEqualInt("signal filled 1",      1, (long)sq.filled);

   // Execution quality
   pt.RecordFill(/*slip*/0.02, /*latency*/30, /*limit*/false);
   pt.RecordFill(/*slip*/0.04, /*latency*/20, /*limit*/true);
   pt.RecordReject();
   tr.AssertEqualDouble ("avg slippage 0.03",  0.03, pt.AvgSlippage(), 1e-9);
   tr.AssertEqualDouble ("reject rate 1/3",    0.3333333333, pt.RejectRate(), 1e-6);
   tr.AssertEqualInt    ("limit fills 1",      1, (long)pt.ExecutionQuality().limit_fills);

   // Position management
   pt.RecordPartial(); pt.RecordPartial();
   pt.RecordTrailExit(+3.0);
   pt.RecordTimeoutExit(-0.5);
   PositionMgmtStats pm = pt.PositionManagement();
   tr.AssertEqualInt    ("partial triggered 2",   2, (long)pm.partial_triggered);
   tr.AssertEqualInt    ("trail exits 1",         1, (long)pm.trail_exits);
   tr.AssertEqualDouble ("trail pnl sum 3.0",     3.0, pm.trail_pnl_sum, 1e-9);

   // Pyramiding
   pt.RecordAdd(+1.2);
   pt.RecordAdd(+0.8);
   pt.RecordAddRejected();
   pt.RecordPyramidDrawdown(0.35);
   PyramidingStats py = pt.Pyramiding();
   tr.AssertEqualInt    ("adds done 2",                   2, (long)py.adds_done);
   tr.AssertEqualDouble ("adds pnl sum 2.0",              2.0, py.pyramid_pnl_sum, 1e-9);
   tr.AssertEqualDouble ("adds max drawdown 0.35",        0.35, py.pyramid_max_drawdown, 1e-9);

   tr.End();
}
