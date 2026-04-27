#ifndef __XAUUSD_SCALPER_TICK_COLLECTOR_MQH__
#define __XAUUSD_SCALPER_TICK_COLLECTOR_MQH__

struct TickRecord
  {
   datetime          time;
   double            bid;
   double            ask;
   double            last;
   ulong             volume;
   uint              flags;
   double            spread;
   double            jump;        // |bid - prev_bid|
  };

class CTickCollector
  {
private:
   TickRecord        m_buf[];
   int               m_cap;
   int               m_size;
   int               m_head;
   double            m_last_spread;
   datetime          m_first_time;
   datetime          m_last_time;
   double            m_global_max_jump; // never resets, kept for diagnostics

public:
                     CTickCollector() : m_cap(0), m_size(0), m_head(0),
                                        m_last_spread(0), m_first_time(0), m_last_time(0),
                                        m_global_max_jump(0) {}

   void              Init(const int capacity)
     {
      m_cap = capacity > 0 ? capacity : 1000;
      ArrayResize(m_buf, m_cap);
      m_size = 0;
      m_head = 0;
      m_last_spread = 0;
      m_first_time = 0;
      m_last_time = 0;
      m_global_max_jump = 0;
     }

   void              OnTick(const MqlTick &t)
     {
      TickRecord r;
      r.time   = t.time;
      r.bid    = t.bid;
      r.ask    = t.ask;
      r.last   = t.last;
      r.volume = t.volume;
      r.flags  = t.flags;
      r.spread = t.ask - t.bid;
      r.jump   = 0.0;

      if(m_size > 0)
        {
         int prev_idx = (m_head - 1 + m_cap) % m_cap;
         r.jump = MathAbs(r.bid - m_buf[prev_idx].bid);
         if(r.jump > m_global_max_jump) m_global_max_jump = r.jump;
        }
      else
         m_first_time = r.time;

      // Once the ring buffer wraps, recompute first_time from the oldest
      // tick we still hold so TicksPerSecondEstimate sees a fresh window.
      if(m_size >= m_cap)
        {
         int oldest_idx = m_head; // about to be overwritten
         m_first_time = m_buf[oldest_idx].time;
        }

      m_buf[m_head] = r;
      m_head = (m_head + 1) % m_cap;
      if(m_size < m_cap) m_size++;

      m_last_spread = r.spread;
      m_last_time = r.time;
     }

   int               Count() const { return m_size; }
   double            LastSpread() const { return m_last_spread; }

   // Largest |Δbid| among the ticks currently in the ring buffer. Old
   // out-of-buffer spikes naturally drop out as the buffer rolls — that
   // matters because previously this metric was monotonic, latched the EA
   // into MARKET_ABNORMAL forever after the first 0.5+ jump of the day.
   double            MaxJump() const
     {
      double mx = 0.0;
      for(int i = 0; i < m_size; i++)
        {
         if(m_buf[i].jump > mx) mx = m_buf[i].jump;
        }
      return mx;
     }

   double            GlobalMaxJump() const { return m_global_max_jump; }

   double            TicksPerSecondEstimate() const
     {
      if(m_size < 2 || m_last_time == m_first_time) return 0.0;
      return (double)m_size / (double)(m_last_time - m_first_time);
     }
  };

#endif // __XAUUSD_SCALPER_TICK_COLLECTOR_MQH__
