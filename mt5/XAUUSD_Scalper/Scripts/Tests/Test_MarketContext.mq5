#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CMarketContext.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_MarketContext");

   CMarketContext ctx; ctx.Init(50, 20);

   for(int i=0;i<50;i++) ctx.PushATRSample(0.5);
   tr.AssertEqualDouble("atr avg 0.5", 0.5, ctx.ATRAverage(), 1e-9);

   for(int i=0;i<50;i++) ctx.PushATRSample(1.0);
   tr.AssertEqualDouble("atr avg 1.0 after saturation", 1.0, ctx.ATRAverage(), 1e-9);

   ctx.PushBreakout();
   ctx.PushBreakout();
   tr.AssertEqualInt("breakouts 2", 2, (long)ctx.BreakoutCount());

   MarketInputs mi = ctx.BuildInputs(/*adx*/30, /*atr*/1.2, /*bb_width*/2.2,
                                     /*last_spread*/0.05, /*max_jump*/0.10,
                                     /*ticks_per_s*/12.0);
   tr.AssertTrue("inputs atr_avg=1.0", MathAbs(mi.atr_avg - 1.0) < 1e-9);

   tr.End();
}
