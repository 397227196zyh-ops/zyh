#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CTrendConfirm.mqh>

class FakeIM2 : public CIndicatorManager
  {
public:
   double e20_m5[3];
   double e50_m5;
   virtual double EMA20_M5(const int s) const override { return e20_m5[s]; }
   virtual double EMA50_M5(const int s) const override { return e50_m5; }
  };

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_TrendConfirm");

   FakeIM2 im; im.e50_m5 = 2399.00; im.e20_m5[0]=2400.5; im.e20_m5[1]=2400.2; im.e20_m5[2]=2400.0;
   CTrendConfirm tc;

   tr.AssertEqualInt("bullish M5", (int)TREND_BULLISH,  (int)tc.Classify(im, /*bid*/2400.60));
   im.e50_m5 = 2401.00; im.e20_m5[0]=2399.5; im.e20_m5[1]=2399.7; im.e20_m5[2]=2399.9;
   tr.AssertEqualInt("bearish M5", (int)TREND_BEARISH,  (int)tc.Classify(im, /*bid*/2399.40));
   im.e50_m5 = 2400.00; im.e20_m5[0]=2400.05; im.e20_m5[1]=2400.00; im.e20_m5[2]=2400.00;
   tr.AssertEqualInt("neutral M5", (int)TREND_NEUTRAL,  (int)tc.Classify(im, /*bid*/2400.02));

   tr.AssertTrue ("EMA bullish+BUY passes",   tc.Allows("EMA",  SIGNAL_BUY,  TREND_BULLISH, 2400.02, 2400.00));
   tr.AssertFalse("EMA bearish+BUY rejects",  tc.Allows("EMA",  SIGNAL_BUY,  TREND_BEARISH, 2400.02, 2400.00));
   tr.AssertTrue ("BOLL bullish+BUY passes",  tc.Allows("BOLL", SIGNAL_BUY,  TREND_BULLISH, 2400.02, 2400.00));
   tr.AssertFalse("BOLL neutral+BUY rejects", tc.Allows("BOLL", SIGNAL_BUY,  TREND_NEUTRAL, 2400.02, 2400.00));
   tr.AssertTrue ("RSI neutral+BUY passes",   tc.Allows("RSI",  SIGNAL_BUY,  TREND_NEUTRAL, 2400.02, 2400.00));
   tr.AssertFalse("RSI bearish+BUY rejects",  tc.Allows("RSI",  SIGNAL_BUY,  TREND_BEARISH, 2400.02, 2400.00));

   tr.End();
}
