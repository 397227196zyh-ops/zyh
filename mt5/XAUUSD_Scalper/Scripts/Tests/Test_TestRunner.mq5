//+------------------------------------------------------------------+
//| Test_TestRunner.mq5                                              |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include <XAUUSD_Scalper/Tests/TestRunner.mqh>

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_TestRunner");

   tr.AssertTrue("true is true", true);
   tr.AssertFalse("false is false", false);
   tr.AssertEqualInt("int eq", 7, 7);
   tr.AssertEqualDouble("double eq", 1.2345, 1.2345, 1e-6);

   tr.End();
}
