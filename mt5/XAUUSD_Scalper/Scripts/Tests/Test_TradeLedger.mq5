#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Data/CTradeLedger.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_TradeLedger");

   CTradeLedger L; L.Init();

   tr.AssertEqualInt    ("initial consec EMA = 0",  0, (long)L.ConsecLosses("EMA"));
   tr.AssertEqualDouble ("initial daily pct = 0",   0.0, L.DailyLossPct(10000.0), 1e-9);
   tr.AssertTrue        ("initial last fail = 0",   L.LastFailTime() == 0);

   L.OnTradeClosed("EMA", -10.0, (datetime)100);
   L.OnTradeClosed("EMA", -10.0, (datetime)200);
   L.OnTradeClosed("EMA", -10.0, (datetime)300);
   tr.AssertEqualInt    ("consec=3 after 3 losses",      3, (long)L.ConsecLosses("EMA"));
   tr.AssertEqualDouble ("dailyPct=0.3 after 30 loss",   0.3, L.DailyLossPct(10000.0), 1e-9);

   L.OnTradeClosed("EMA", +5.0, (datetime)400);
   tr.AssertEqualInt    ("consec resets on win",         0, (long)L.ConsecLosses("EMA"));

   L.OnDayRollover((datetime)500);
   tr.AssertEqualDouble ("dailyPct resets after rollover", 0.0, L.DailyLossPct(10000.0), 1e-9);
   tr.AssertEqualInt    ("consec NOT reset by rollover",   0, (long)L.ConsecLosses("EMA"));

   L.OnTradeFailed((datetime)1000);
   tr.AssertTrue        ("last fail = 1000",               L.LastFailTime() == (datetime)1000);

   tr.End();
}
