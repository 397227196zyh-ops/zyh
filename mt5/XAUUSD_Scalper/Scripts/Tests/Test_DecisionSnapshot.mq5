#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Data/CDecisionSnapshot.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_DecisionSnapshot");

   CDecisionSnapshot s;
   tr.AssertTrue ("open csv", s.Open("XAUUSD_Scalper/tests/decision_snapshots_test.csv"));

   DecisionRow r;
   r.time = (datetime)(TimeCurrent());
   r.strat = "EMA"; r.dir = 1; r.session_open = true;
   r.guard_reason = 0; r.trend_state = 1; r.allowed = true; r.reason = "PASS";
   r.spread = 0.05; r.atr = 1.2; r.adx = 25.0; r.sl_distance = 0.80; r.planned_lot = 0.02;
   r.is_pyramid = false;
   tr.AssertTrue ("write row", s.Write(r));

   s.Close();
   tr.AssertTrue ("close ok", true);
   tr.End();
}
