#ifndef __XAUUSD_SCALPER_CHART_DRAWER_MQH__
#define __XAUUSD_SCALPER_CHART_DRAWER_MQH__

#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

// Draws open/close arrows, market-state background rectangles, anomaly
// marks. Keep naming scoped under a prefix so Clear() can yank them.

class CChartDrawer
  {
private:
   string m_prefix;
   int    m_seq;

   string NewName(const string tag)
     {
      m_seq++;
      return StringFormat("%s_%s_%d", m_prefix, tag, m_seq);
     }

public:
                     CChartDrawer() : m_prefix("XAUUSD_DRAW"), m_seq(0) {}

   void              Init(const string prefix = "XAUUSD_DRAW") { m_prefix = prefix; m_seq = 0; }

   void              DrawArrowOpen(const datetime when, const double price, const int direction,
                                    const color c = clrLightSkyBlue)
     {
      string n = NewName("OPEN");
      ObjectCreate(0, n, direction > 0 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL, 0, when, price);
      ObjectSetInteger(0, n, OBJPROP_COLOR, c);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }

   void              DrawArrowClose(const datetime when, const double price,
                                     const double pnl)
     {
      string n = NewName("CLOSE");
      ObjectCreate(0, n, OBJ_ARROW_STOP, 0, when, price);
      ObjectSetInteger(0, n, OBJPROP_COLOR, pnl >= 0 ? clrLimeGreen : clrTomato);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }

   void              DrawAnomaly(const datetime when, const string tag)
     {
      string n = NewName(tag);
      ObjectCreate(0, n, OBJ_VLINE, 0, when, 0);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clrTomato);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, n, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }

   void              DrawStateRegion(const datetime t0, const datetime t1,
                                      const double y0, const double y1,
                                      const ENUM_MARKET_STATE state)
     {
      color c = clrGray;
      switch(state)
        {
         case MARKET_RANGING:  c = C'30,50,30'; break;
         case MARKET_TRENDING: c = C'30,40,70'; break;
         case MARKET_BREAKOUT: c = C'70,50,30'; break;
         case MARKET_ABNORMAL: c = C'70,30,30'; break;
        }
      string n = NewName("REGION");
      ObjectCreate(0, n, OBJ_RECTANGLE, 0, t0, y0, t1, y1);
      ObjectSetInteger(0, n, OBJPROP_COLOR, c);
      ObjectSetInteger(0, n, OBJPROP_BACK, true);
      ObjectSetInteger(0, n, OBJPROP_FILL, true);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }

   void              Clear()
     {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
        {
         string n = ObjectName(0, i);
         if(StringFind(n, m_prefix) == 0) ObjectDelete(0, n);
        }
     }
  };

#endif // __XAUUSD_SCALPER_CHART_DRAWER_MQH__
