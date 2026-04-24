#ifndef __XAUUSD_SCALPER_VISUALIZER_MQH__
#define __XAUUSD_SCALPER_VISUALIZER_MQH__

#include <XAUUSD_Scalper/UI/CDashboard.mqh>
#include <XAUUSD_Scalper/UI/CChartDrawer.mqh>

// Thin coordinator over CDashboard + CChartDrawer. The EA holds a single
// CVisualizer and forwards events and ticks through it.

class CVisualizer
  {
private:
   CDashboard   m_dash;
   CChartDrawer m_draw;
   bool         m_enabled;

public:
                    CVisualizer() : m_enabled(true) {}

   void             Init(const ENUM_DASH_LAYOUT layout = DASH_COMPACT)
     {
      m_dash.Init("XAUUSD_DASH", layout);
      m_draw.Init("XAUUSD_DRAW");
     }

   void             SetEnabled(const bool v) { m_enabled = v; }

   void             RenderDashboard(const DashSnapshot &s, const CPerformanceTracker &pt)
     {
      if(!m_enabled) return;
      m_dash.Render(s, pt);
     }

   void             OnOrderFilled(const datetime when, const double price, const int direction)
     {
      if(!m_enabled) return;
      m_draw.DrawArrowOpen(when, price, direction);
     }

   void             OnOrderClosed(const datetime when, const double price, const double pnl)
     {
      if(!m_enabled) return;
      m_draw.DrawArrowClose(when, price, pnl);
     }

   void             OnAnomaly(const datetime when, const string tag)
     {
      if(!m_enabled) return;
      m_draw.DrawAnomaly(when, tag);
     }

   void             Clear()
     {
      m_dash.Clear();
      m_draw.Clear();
     }
  };

#endif // __XAUUSD_SCALPER_VISUALIZER_MQH__
