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
  };

class CTickCollector
  {
private:
   TickRecord        m_buf[];
   int               m_cap;
   int               m_size;
   int               m_head;
   double            m_max_jump;
   double            m_last_spread;
   datetime          m_first_time;
   datetime          m_last_time;

public:
                     CTickCollector() : m_cap(0), m_size(0), m_head(0), m_max_jump(0), m_last_spread(0), m_first_time(0), m_last_time(0) {}

   void              Init(const int capacity)
     {
      m_cap = capacity > 0 ? capacity : 1000;
      ArrayResize(m_buf, m_cap);
      m_size = 0;
      m_head = 0;
      m_max_jump = 0;
      m_last_spread = 0;
      m_first_time = 0;
      m_last_time = 0;
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

      if(m_size > 0)
        {
         int prev_idx = (m_head - 1 + m_cap) % m_cap;
         double jump = MathAbs(r.bid - m_buf[prev_idx].bid);
         if(jump > m_max_jump) m_max_jump = jump;
        }
      else
         m_first_time = r.time;

      m_buf[m_head] = r;
      m_head = (m_head + 1) % m_cap;
      if(m_size < m_cap) m_size++;

      m_last_spread = r.spread;
      m_last_time = r.time;
     }

   int               Count() const { return m_size; }
   double            LastSpread() const { return m_last_spread; }
   double            MaxJump() const { return m_max_jump; }

   double            TicksPerSecondEstimate() const
     {
      if(m_size < 2 || m_last_time == m_first_time) return 0.0;
      return (double)m_size / (double)(m_last_time - m_first_time);
     }
  };

#endif // __XAUUSD_SCALPER_TICK_COLLECTOR_MQH__
