#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Data/CTradeHistory.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_TradeHistory");

   CTradeHistory h;
   tr.AssertTrue ("open csv", h.Open("XAUUSD_Scalper/tests/trade_history_test.csv"));

   TradeRow r;
   r.open_time = (datetime)1000; r.close_time = (datetime)2000;
   r.strat = "EMA"; r.dir = 1; r.entry = 2400.00; r.exit = 2401.20;
   r.lots = 0.02; r.pnl = 2.40; r.commission = 0.10; r.swap = 0.0;
   r.market_state_on_open = 1; r.liquidity_score_on_open = 72.5;
   r.slippage = 0.01; r.exec_ms = 18; r.was_limit = false;
   tr.AssertTrue ("write row", h.Write(r));

   h.Close();
   tr.AssertTrue ("close ok", true);
   tr.End();
}
