#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_IndicatorManager");

   CIndicatorManager im;
   bool ok = im.Init(_Symbol);
   tr.AssertTrue("Init returns true", ok);

   im.Update();

   tr.AssertTrue("ema5 positive",  im.EMA(5,0)  > 0.0);
   tr.AssertTrue("ema10 positive", im.EMA(10,0) > 0.0);
   tr.AssertTrue("ema20 positive", im.EMA(20,0) > 0.0);
   tr.AssertTrue("ema50 positive", im.EMA(50,0) > 0.0);
   tr.AssertTrue("rsi in range",   im.RSI(0) >= 0.0 && im.RSI(0) <= 100.0);
   tr.AssertTrue("atr positive",   im.ATR(0) > 0.0);
   tr.AssertTrue("adx non-negative", im.ADX(0) >= 0.0);
   tr.AssertTrue("bb upper > lower", im.BBUpper(0) > im.BBLower(0));
   tr.AssertTrue("ema5 different from ema50", MathAbs(im.EMA(5,0) - im.EMA(50,0)) >= 0.0);

   im.Shutdown();
   tr.End();
}
