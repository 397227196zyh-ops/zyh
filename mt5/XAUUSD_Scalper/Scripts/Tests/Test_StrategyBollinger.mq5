#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBollinger.mqh>

class FakeIM : public CIndicatorManager
  {
public:
   double up_prev, up_curr, lo_prev, lo_curr, mid;
   virtual double BBUpper(const int s) const override { return s == 1 ? up_prev : up_curr; }
   virtual double BBLower(const int s) const override { return s == 1 ? lo_prev : lo_curr; }
   virtual double BBMiddle(const int s) const override { return mid; }
  };

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_StrategyBollinger");

   FakeIM im; im.up_prev = 2400.00; im.up_curr = 2400.05;
                im.lo_prev = 2399.50; im.lo_curr = 2399.55; im.mid = 2399.80;

   CStrategyBollinger s; s.Configure(0.2, 1.0, 0.8);

   StrategyContext ctx; ctx.im = &im; ctx.state = MARKET_BREAKOUT; ctx.tc = NULL;

   ctx.bid = 2400.15; ctx.ask = 2400.20; ctx.time = 60;
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("upper breakout pullback -> BUY", (int)SIGNAL_BUY, (int)r.direction);

   // Same bar -> suppressed.
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("same bar -> suppressed", (int)SIGNAL_NONE, (int)r.direction);

   // New bar with lower-band pullback -> SELL.
   ctx.bid = 2399.45; ctx.ask = 2399.50; ctx.time = 120;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("lower breakout pullback -> SELL", (int)SIGNAL_SELL, (int)r.direction);

   // New bar inside band -> NONE.
   ctx.bid = 2399.80; ctx.ask = 2399.85; ctx.time = 180;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("inside band -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   tr.End();
}
