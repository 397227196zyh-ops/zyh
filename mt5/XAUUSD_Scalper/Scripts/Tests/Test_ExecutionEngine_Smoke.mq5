#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CExecutionEngine.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_ExecutionEngine_Smoke");

   CExecutionEngine e;
   e.SetSymbol("XAUUSD");
   e.SetMagic(7010999);
   e.Configure(3, 100, 0.10, 5);
   e.SetDryRun(true);

   ExecutionResult r = e.PlaceMarket(/*dir*/+1, /*vol*/0.01, /*sl*/0.0, /*tp*/0.0, /*req*/2400.0);
   tr.AssertFalse("dry-run market does not fill", r.filled);
   tr.AssertTrue ("dry-run market reason DRY_RUN", r.reason_str == "DRY_RUN");

   r = e.PlaceLimit(/*dir*/-1, /*vol*/0.01, /*price*/2401.0, /*sl*/0.0, /*tp*/0.0);
   tr.AssertFalse("dry-run limit does not fill", r.filled);
   tr.AssertTrue ("dry-run limit reason DRY_RUN", r.reason_str == "DRY_RUN");

   tr.End();
}
