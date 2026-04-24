#ifndef __XAUUSD_SCALPER_MARKET_CONTEXT_MQH__
#define __XAUUSD_SCALPER_MARKET_CONTEXT_MQH__

#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

class CMarketContext
  {
private:
   double            m_atr_ring[];
   int               m_atr_cap;
   int               m_atr_size;
   int               m_atr_head;
   double            m_atr_sum;

   int               m_breakout_win;
   int               m_breakouts[];

public:
                     CMarketContext() : m_atr_cap(0), m_atr_size(0), m_atr_head(0),
                                        m_atr_sum(0), m_breakout_win(0) {}

   void              Init(const int atr_window, const int breakout_window)
     {
      m_atr_cap = atr_window > 0 ? atr_window : 50;
      ArrayResize(m_atr_ring, m_atr_cap);
      m_atr_size = 0; m_atr_head = 0; m_atr_sum = 0.0;
      m_breakout_win = breakout_window > 0 ? breakout_window : 20;
      ArrayResize(m_breakouts, 0);
     }

   void              PushATRSample(const double v)
     {
      if(m_atr_size < m_atr_cap)
        {
         m_atr_ring[m_atr_head] = v;
         m_atr_head = (m_atr_head + 1) % m_atr_cap;
         m_atr_size++;
         m_atr_sum += v;
         return;
        }
      double old = m_atr_ring[m_atr_head];
      m_atr_ring[m_atr_head] = v;
      m_atr_head = (m_atr_head + 1) % m_atr_cap;
      m_atr_sum += (v - old);
     }

   double            ATRAverage() const
     { return m_atr_size > 0 ? m_atr_sum / (double)m_atr_size : 0.0; }

   void              PushBreakout()
     {
      int n = ArraySize(m_breakouts);
      ArrayResize(m_breakouts, n + 1);
      m_breakouts[n] = 1;
      if(ArraySize(m_breakouts) > m_breakout_win)
        {
         int drop = ArraySize(m_breakouts) - m_breakout_win;
         for(int i = 0; i < m_breakout_win; i++) m_breakouts[i] = m_breakouts[i + drop];
         ArrayResize(m_breakouts, m_breakout_win);
        }
     }

   int               BreakoutCount() const
     {
      int n = ArraySize(m_breakouts);
      int s = 0;
      for(int i = 0; i < n; i++) s += m_breakouts[i];
      return s;
     }

   MarketInputs      BuildInputs(const double adx, const double atr, const double bb_width,
                                 const double last_spread, const double max_jump,
                                 const double ticks_per_s) const
     {
      MarketInputs mi;
      mi.adx         = adx;
      mi.atr         = atr;
      mi.atr_avg     = ATRAverage();
      mi.bb_width    = bb_width;
      mi.last_spread = last_spread;
      mi.max_jump    = max_jump;
      mi.ticks_per_s = ticks_per_s;
      mi.breakouts   = BreakoutCount();
      return mi;
     }
  };

#endif // __XAUUSD_SCALPER_MARKET_CONTEXT_MQH__
