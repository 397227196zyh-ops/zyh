#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

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

   // Trending with flat ATR (ADX alone is sufficient)
   in.adx = 42; in.atr = 0.50; in.atr_avg = 0.50; in.bb_width = 0.80; in.breakouts = 0;
   in.ticks_per_s = 10.0; in.last_spread = 0.05; in.max_jump = 0.10;
   tr.AssertEqualInt("trending on high ADX flat ATR", (int)MARKET_TRENDING, (int)CMarketAnalyzer::Classify(in));

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
