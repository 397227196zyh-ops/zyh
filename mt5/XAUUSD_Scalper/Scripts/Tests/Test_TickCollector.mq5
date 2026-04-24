#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Data/CTickCollector.mqh>

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_TickCollector");

   CTickCollector tc;
   tc.Init(4);

   MqlTick t;
   t.time      = (datetime)1000;
   t.bid       = 2400.00;
   t.ask       = 2400.05;
   t.last      = 2400.02;
   t.volume    = 1;
   t.flags     = 0;

   tc.OnTick(t);
   t.time = 1001; t.bid = 2400.10; t.ask = 2400.15; tc.OnTick(t);
   t.time = 1002; t.bid = 2400.05; t.ask = 2400.10; tc.OnTick(t);
   t.time = 1003; t.bid = 2400.20; t.ask = 2400.30; tc.OnTick(t);
   t.time = 1004; t.bid = 2400.25; t.ask = 2400.35; tc.OnTick(t); // wraps

   tr.AssertEqualInt("count capped at capacity", 4, tc.Count());
   tr.AssertEqualDouble("last spread", 0.10, tc.LastSpread(), 1e-6);
   tr.AssertTrue("max jump >= 0.15",  tc.MaxJump() + 1e-6 >= 0.15);
   tr.AssertTrue("ticks per sec >0",  tc.TicksPerSecondEstimate() > 0.0);

   tr.End();
}
