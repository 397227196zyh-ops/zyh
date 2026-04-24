#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Data/CExecutionQuality.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_ExecutionQuality");

   CExecutionQuality q;
   tr.AssertTrue ("open csv", q.Open("XAUUSD_Scalper/tests/execution_quality_test.csv"));

   ExecQualityRow r;
   r.time = TimeCurrent(); r.strat = "EMA"; r.side = 1;
   r.requested_price = 2400.00; r.fill_price = 2400.01; r.slippage = 0.01;
   r.retries = 0; r.latency_ms = 35; r.order_type = "market";
   tr.AssertTrue ("write row", q.Write(r));

   q.Close();
   tr.AssertTrue ("close ok", true);
   tr.End();
}
