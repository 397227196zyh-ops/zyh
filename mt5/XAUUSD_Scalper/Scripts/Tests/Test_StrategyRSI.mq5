#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CStrategyRSI.mqh>

class FakeIM : public CIndicatorManager
  {
public:
   double rsi_prev, rsi_curr, e50;
   virtual double RSI(const int s) const override { return s == 1 ? rsi_prev : rsi_curr; }
   virtual double EMA(const int p, const int s) const override { return p == 50 ? e50 : 0.0; }
  };

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_StrategyRSI");

   FakeIM im; CStrategyRSI s;
   s.Configure(25.0, 75.0, 1.5, 0.6, 0.5);

   StrategyContext ctx; ctx.im = &im; ctx.tc = NULL; ctx.state = MARKET_RANGING; ctx.time = 0;

   // Oversold turning up
   im.rsi_prev = 20.0; im.rsi_curr = 22.0; im.e50 = 2400.00;
   ctx.bid = 2400.20; ctx.ask = 2400.25;
   SignalResult r = s.CheckSignal(ctx);
   tr.AssertEqualInt("oversold rising -> BUY", (int)SIGNAL_BUY, (int)r.direction);

   // Overbought turning down
   im.rsi_prev = 80.0; im.rsi_curr = 78.0;
   ctx.bid = 2399.80; ctx.ask = 2399.85;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("overbought falling -> SELL", (int)SIGNAL_SELL, (int)r.direction);

   // Middle RSI -> NONE
   im.rsi_prev = 50.0; im.rsi_curr = 50.0;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("middle RSI -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   // Far from EMA50 -> NONE
   im.rsi_prev = 20.0; im.rsi_curr = 22.0; im.e50 = 2395.00; ctx.bid = 2400.00;
   r = s.CheckSignal(ctx);
   tr.AssertEqualInt("far from EMA50 -> NONE", (int)SIGNAL_NONE, (int)r.direction);

   tr.End();
}
