#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

class CNullStrategy : public CStrategyBase
  {
public:
                     CNullStrategy() { m_name = "NULL"; m_magic = 111; }
   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r;
      r.direction = SIGNAL_NONE;
      r.stop_loss = 0;
      r.take_profit = 0;
      return r;
     }
  };

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_StrategyBase");

   CNullStrategy s;
   tr.AssertTrue("name NULL",         s.Name() == "NULL");
   tr.AssertEqualInt("magic 111",     111, (long)s.Magic());

   s.OnTradeClosed(+10.0);
   s.OnTradeClosed(-4.0);
   s.OnTradeClosed(+6.0);
   tr.AssertEqualInt("trades 3",       3, (long)s.Trades());
   tr.AssertEqualInt("wins 2",         2, (long)s.Wins());
   tr.AssertEqualDouble("gross pnl 12.0", 12.0, s.GrossPnL(), 1e-6);

   double f = s.CalculateKellyFraction(30 /*min_trades*/, 0.55 /*cold_p*/, 1.2 /*cold_b*/);
   tr.AssertTrue("cold-start kelly > 0", f > 0.0);

   tr.End();
}
