#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>

// EMA cross detection now compares closed bars (shift 2 vs 1) and only fires
// once per minute. The fake indicator surface mirrors that contract.
class FakeIM : public CIndicatorManager
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

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_StrategyEMA");

   FakeIM im;
   im.e5_2  = 2400.00; im.e10_2 = 2400.10;
   im.e5_1  = 2400.20; im.e10_1 = 2400.10;
   im.e20_1 = 2399.50;
   im.atr_1 = 1.0;

   CStrategyEMA s; s.Configure(1.5, 1.2, 0.5, 2.0);

   StrategyContext ctx; ctx.im = &im; ctx.tc = NULL; ctx.state = MARKET_TRENDING;
   ctx.bid = 2400.30; ctx.ask = 2400.35; ctx.time = 60; // bar #1

   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bullish cross -> BUY", (int)SIGNAL_BUY, (int)r.direction);
   tr.AssertTrue    ("sl below bid",        r.stop_loss < ctx.bid);
   tr.AssertTrue    ("tp above bid",        r.take_profit > ctx.bid);

   // Same bar, same signal -> must be suppressed.
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("same bar -> no re-emit", (int)SIGNAL_NONE, (int)r.direction);

   // Bearish cross on a new bar.
   im.e5_2 = 2400.30; im.e10_2 = 2400.20;
   im.e5_1 = 2400.00; im.e10_1 = 2400.20;
   im.e20_1 = 2400.50;
   ctx.bid = 2399.80; ctx.ask = 2399.85; ctx.time = 120;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bearish cross -> SELL", (int)SIGNAL_SELL, (int)r.direction);

   // No cross.
   im.e5_2 = 2400.00; im.e10_2 = 2399.90;
   im.e5_1 = 2400.10; im.e10_1 = 2399.95;
   ctx.time = 180;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("no cross -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   tr.End();
}
