#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CSessionFilter.mqh>

datetime mk(const int h, const int m, const int dow)
{
   MqlDateTime d; d.year=2026; d.mon=4; d.day=20+dow; d.hour=h; d.min=m; d.sec=0; d.day_of_year=0; d.day_of_week=dow;
   return StructToTime(d);
}

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_SessionFilter");

   CSessionFilter sf;
   sf.Configure(/*lon_start*/ 7, /*lon_end*/ 16, /*ny_start*/ 13, /*ny_end*/ 22);

   tr.AssertTrue ("monday 09:00 (london)",   sf.IsOpen(mk(9, 0, 1)));
   tr.AssertTrue ("monday 14:30 (london+ny)",sf.IsOpen(mk(14,30,1)));
   tr.AssertTrue ("monday 21:00 (ny)",       sf.IsOpen(mk(21, 0,1)));
   tr.AssertFalse("monday 03:00 (asia)",     sf.IsOpen(mk( 3, 0,1)));
   tr.AssertFalse("saturday 10:00",          sf.IsOpen(mk(10, 0,6)));
   tr.AssertFalse("sunday 10:00",            sf.IsOpen(mk(10, 0,0)));

   tr.End();
}
