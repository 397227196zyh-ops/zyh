#ifndef __XAUUSD_SCALPER_SESSION_FILTER_MQH__
#define __XAUUSD_SCALPER_SESSION_FILTER_MQH__

class CSessionFilter
  {
private:
   int               m_lon_start_h;
   int               m_lon_end_h;
   int               m_ny_start_h;
   int               m_ny_end_h;

public:
                     CSessionFilter() : m_lon_start_h(7), m_lon_end_h(16),
                                        m_ny_start_h(13), m_ny_end_h(22) {}

   void              Configure(const int lon_start, const int lon_end,
                               const int ny_start,  const int ny_end)
     {
      m_lon_start_h = lon_start; m_lon_end_h = lon_end;
      m_ny_start_h  = ny_start;  m_ny_end_h  = ny_end;
     }

   bool              IsOpen(const datetime server_time) const
     {
      MqlDateTime d; TimeToStruct(server_time, d);
      if(d.day_of_week == 0 || d.day_of_week == 6) return false;
      const int h = d.hour;
      const bool in_lon = h >= m_lon_start_h && h < m_lon_end_h;
      const bool in_ny  = h >= m_ny_start_h  && h < m_ny_end_h;
      return in_lon || in_ny;
     }
  };

#endif // __XAUUSD_SCALPER_SESSION_FILTER_MQH__
