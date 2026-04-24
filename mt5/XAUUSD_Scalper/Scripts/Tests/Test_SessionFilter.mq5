#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CSessionFilter.mqh>

datetime mk(const int h, const int m, const int dow)
{
   // Pick a concrete April 2026 day that actually falls on the requested dow.
   // 2026-04-19 = Sun, 20 = Mon, 21 = Tue, 22 = Wed, 23 = Thu, 24 = Fri, 25 = Sat.
   int day;
   switch(dow)
     {
      case 0: day = 19; break; // Sunday
      case 1: day = 20; break; // Monday
      case 2: day = 21; break;
      case 3: day = 22; break;
      case 4: day = 23; break;
      case 5: day = 24; break;
      case 6: day = 25; break; // Saturday
      default: day = 20; break;
     }
   MqlDateTime d; d.year=2026; d.mon=4; d.day=day; d.hour=h; d.min=m; d.sec=0; d.day_of_year=0; d.day_of_week=dow;
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
