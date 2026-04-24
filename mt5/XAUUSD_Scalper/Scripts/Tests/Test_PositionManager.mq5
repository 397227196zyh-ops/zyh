#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CPositionManager.mqh>

// A PositionManager unit harness needs to call Step(...) without touching the
// MT5 trade context. CExecutionEngine exposes dry-run via SetDryRun(true),
// which short-circuits ClosePartial / Close / ModifyStops to simple bool
// returns. Good enough to exercise every PositionManager state transition.

void OnStart()
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
   eng.SetSymbol("XAUUSD");
   eng.SetMagic(7010001);
   eng.SetDryRun(true);

   // Long position: entry 2400.00, SL 2399.00 -> 1R = 1.00 USD
   int idx = pm.OnFill(1001, 7010001, "EMA",
                       +1, 2400.00, 2399.00, 2402.00,
                       0.10, (datetime)1000, true);
   tr.AssertEqualInt("initial state OPEN", (int)POS_STATE_OPEN, (int)pm.At(idx).state);

   // Small move: still OPEN
   pm.Step(idx, eng, 2400.05, 2400.10, 0.30, 0);
   tr.AssertEqualInt("no move -> still OPEN", (int)POS_STATE_OPEN, (int)pm.At(idx).state);

   // Hit +1.0R: partial TP + breakeven
   pm.Step(idx, eng, 2401.00, 2401.10, 0.30, 1);
   tr.AssertEqualInt   ("at +1R -> PARTIAL_DONE",       (int)POS_STATE_PARTIAL_DONE, (int)pm.At(idx).state);
   tr.AssertEqualDouble("volume halved to 0.05",        0.05, pm.At(idx).volume, 1e-9);
   tr.AssertEqualDouble("SL moved to 2400.10 (BE+buf)", 2400.10, pm.At(idx).current_sl, 1e-9);

   // Trailing engages
   pm.Step(idx, eng, 2402.00, 2402.10, 0.30, 0);
   tr.AssertEqualInt   ("trailing engaged",              (int)POS_STATE_TRAILING, (int)pm.At(idx).state);
   tr.AssertEqualDouble("trailing SL = 2401.70",         2401.70, pm.At(idx).current_sl, 1e-9);

   // Pyramid allowance
   int head = pm.OnFill(1002, 7010001, "EMA",
                        +1, 2410.00, 2409.00, 2412.00,
                        0.10, (datetime)2000, true);

   tr.AssertFalse("pyramid rejected before +0.5R",
      pm.AllowPyramid(head, +1, 2410.25, MARKET_TRENDING, TREND_BULLISH,
                      2410.20, 2410.25));

   tr.AssertTrue ("pyramid allowed at +0.5R bullish trend, distance ok",
      pm.AllowPyramid(head, +1, 2410.80, MARKET_TRENDING, TREND_BULLISH,
                      2410.50, 2410.55));

   tr.AssertFalse("pyramid rejected on trend flip",
      pm.AllowPyramid(head, +1, 2410.80, MARKET_TRENDING, TREND_BEARISH,
                      2410.50, 2410.55));

   pm.OnPyramidAdded(head);
   pm.OnPyramidAdded(head);
   tr.AssertFalse("pyramid rejected after 2 adds",
      pm.AllowPyramid(head, +1, 2410.80, MARKET_TRENDING, TREND_BULLISH,
                      2410.50, 2410.55));

   tr.End();
}
