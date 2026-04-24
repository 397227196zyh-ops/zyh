#ifndef __XAUUSD_SCALPER_DASHBOARD_MQH__
#define __XAUUSD_SCALPER_DASHBOARD_MQH__

#include <XAUUSD_Scalper/Analysis/CPerformanceTracker.mqh>

enum ENUM_DASH_LAYOUT
  {
   DASH_COMPACT    = 0,
   DASH_DETAILED   = 1,
   DASH_FULLSCREEN = 2
  };

struct DashSnapshot
  {
   double  equity;
   double  floating_pnl;
   int     open_positions;
   double  spread;
   double  atr;
   double  adx;
   int     market_state;
   int     trend_state;
   bool    session_open;
   int     guard_reason;
   double  liquidity_score;
   double  ticks_per_sec;
  };

class CDashboard
  {
private:
   string           m_prefix;
   ENUM_DASH_LAYOUT m_layout;

   int              m_panel_x;
   int              m_panel_y;
   int              m_panel_w;
   int              m_panel_h;

   string           Name(const int id) const
     {
      return StringFormat("%s_%d", m_prefix, id);
     }

   void             SetLabel(const int id, const string text, const int x, const int y,
                              const color c = clrWhite, const int font_size = 9)
     {
      string n = Name(id);
      if(ObjectFind(0, n) < 0)
        {
         ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
        }
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
      ObjectSetString (0, n, OBJPROP_TEXT, text);
      ObjectSetInteger(0, n, OBJPROP_COLOR, c);
      ObjectSetString (0, n, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, font_size);
     }

   void             SetPanel()
     {
      string n = Name(0);
      if(ObjectFind(0, n) < 0)
        {
         ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
        }
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE, m_panel_x);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE, m_panel_y);
      ObjectSetInteger(0, n, OBJPROP_XSIZE,     m_panel_w);
      ObjectSetInteger(0, n, OBJPROP_YSIZE,     m_panel_h);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR,   C'20,20,28');
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_COLOR,     clrGray);
     }

public:
                    CDashboard() : m_prefix("XAUUSD_DASH"), m_layout(DASH_COMPACT),
                                   m_panel_x(12), m_panel_y(28), m_panel_w(300), m_panel_h(200) {}

   void             Init(const string prefix = "XAUUSD_DASH",
                          const ENUM_DASH_LAYOUT layout = DASH_COMPACT)
     {
      m_prefix = prefix;
      m_layout = layout;
      switch(layout)
        {
         case DASH_DETAILED:   m_panel_w = 380; m_panel_h = 260; break;
         case DASH_FULLSCREEN: m_panel_w = 520; m_panel_h = 360; break;
         default:              m_panel_w = 300; m_panel_h = 200; break;
        }
      SetPanel();
     }

   void             Render(const DashSnapshot &s, const CPerformanceTracker &pt)
     {
      const int x = m_panel_x + 10;
      int y = m_panel_y + 8;
      const int line = 14;

      SetLabel(1, "XAUUSD Scalper", x, y, clrGold, 11); y += line + 2;
      SetLabel(2, StringFormat("Equity: %.2f",  s.equity),
               x, y, clrLightGray); y += line;
      SetLabel(3, StringFormat("Float PnL: %.2f", s.floating_pnl),
               x, y, s.floating_pnl >= 0 ? clrLimeGreen : clrTomato); y += line;
      SetLabel(4, StringFormat("Open positions: %d", s.open_positions),
               x, y, clrLightGray); y += line;

      color sp_color = s.spread < 0.08 ? clrLimeGreen
                                       : (s.spread < 0.15 ? clrGoldenrod : clrTomato);
      SetLabel(5, StringFormat("Spread: %.3f", s.spread),  x, y, sp_color); y += line;

      SetLabel(6, StringFormat("ATR: %.3f  ADX: %.1f", s.atr, s.adx),
               x, y, clrLightGray); y += line;

      string state_name = "RANGE";
      if(s.market_state == 1) state_name = "TREND";
      else if(s.market_state == 2) state_name = "BREAK";
      else if(s.market_state == 3) state_name = "ABNORM";
      SetLabel(7, StringFormat("Market: %s", state_name),
               x, y, s.market_state == 3 ? clrTomato : clrDeepSkyBlue); y += line;

      string trend_name = "NEUT";
      if(s.trend_state == 1) trend_name = "BULL";
      else if(s.trend_state == -1) trend_name = "BEAR";
      SetLabel(8, StringFormat("M5 trend: %s", trend_name),
               x, y, clrLightGray); y += line;

      SetLabel(9, StringFormat("Session: %s  Guard: %d",
                               s.session_open ? "OPEN" : "SHUT",
                               s.guard_reason),
               x, y, s.session_open && s.guard_reason == 0 ? clrLimeGreen : clrGoldenrod);
      y += line;

      if(m_layout != DASH_COMPACT)
        {
         SetLabel(10, StringFormat("Liquidity: %.1f", s.liquidity_score), x, y, clrLightGray); y += line;
         SetLabel(11, StringFormat("Ticks/s: %.1f",   s.ticks_per_sec),   x, y, clrLightGray); y += line;

         ReturnsStats r = pt.Returns();
         SetLabel(12, StringFormat("Trades: %d  Win%%: %.1f", r.total_trades, 100.0 * pt.WinRate()),
                  x, y, clrLightGray); y += line;
         SetLabel(13, StringFormat("NetPnL: %.2f  Payoff: %.2f", r.net_pnl, pt.PayoffRatio()),
                  x, y, r.net_pnl >= 0 ? clrLimeGreen : clrTomato); y += line;
        }

      if(m_layout == DASH_FULLSCREEN)
        {
         ExecutionQualityStats eq = pt.ExecutionQuality();
         PyramidingStats py = pt.Pyramiding();
         SetLabel(14, StringFormat("Slippage: %.3f  Rejects: %d", pt.AvgSlippage(), eq.rejects),
                  x, y, clrLightGray); y += line;
         SetLabel(15, StringFormat("Pyramids: %d  Reject(add): %d",
                                    py.adds_done, py.adds_rejected_by_risk),
                  x, y, clrLightGray); y += line;
        }
     }

   void             Clear()
     {
      for(int i = 0; i <= 20; i++)
        {
         string n = Name(i);
         if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
        }
     }
  };

#endif // __XAUUSD_SCALPER_DASHBOARD_MQH__
