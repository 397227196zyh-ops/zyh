#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>

class FakeIM : public CIndicatorManager
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

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_StrategyEMA");

   FakeIM im;
   im.e5_prev  = 2400.00; im.e10_prev = 2400.10;
   im.e5_curr  = 2400.20; im.e10_curr = 2400.10;
   im.e20_curr = 2399.50;
   im.atr_curr = 1.0;

   CStrategyEMA s;
   s.Configure(1.5, 1.2, 0.5, 2.0);

   StrategyContext ctx; ctx.im = &im; ctx.tc = NULL; ctx.state = MARKET_TRENDING;
   ctx.bid = 2400.30; ctx.ask = 2400.35; ctx.time = 0;

   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bullish cross -> BUY", (int)SIGNAL_BUY, (int)r.direction);
   tr.AssertTrue("sl below bid",  r.stop_loss < ctx.bid);
   tr.AssertTrue("tp above bid",  r.take_profit > ctx.bid);

   im.e5_prev  = 2400.30; im.e10_prev = 2400.20;
   im.e5_curr  = 2400.00; im.e10_curr = 2400.20;
   im.e20_curr = 2400.50;
   ctx.bid = 2399.80; ctx.ask = 2399.85;

   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("bearish cross -> SELL", (int)SIGNAL_SELL, (int)r.direction);

   im.e5_prev  = 2400.00; im.e10_prev = 2399.90;
   im.e5_curr  = 2400.10; im.e10_curr = 2399.95;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("no cross -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   tr.End();
}
