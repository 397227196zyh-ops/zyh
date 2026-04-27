#ifndef __XAUUSD_SCALPER_SESSION_FILTER_MQH__
#define __XAUUSD_SCALPER_SESSION_FILTER_MQH__

// Window edges are configured in **UTC hours**. CSessionFilter converts UTC
// edges into broker-server hours at runtime by querying the broker's GMT
// offset, so the same defaults work across brokers regardless of their
// server timezone.
class CSessionFilter
  {
private:
   int               m_lon_start_utc;
   int               m_lon_end_utc;
   int               m_ny_start_utc;
   int               m_ny_end_utc;
   int               m_broker_gmt_offset_h; // cached broker_gmt - UTC, in hours

   int               BrokerOffset(const datetime server_time) const
     {
      // Use TimeGMT() vs TimeTradeServer() to deduce broker offset. MQL5
      // exposes TimeGMT() (UTC). server_time is broker time. Difference is
      // rounded to whole hours.
      datetime gmt = TimeGMT();
      datetime sv  = TimeTradeServer();
      long delta_s = (long)sv - (long)gmt;
      return (int)((delta_s + (delta_s >= 0 ? 1800 : -1800)) / 3600);
     }

public:
                     CSessionFilter() : m_lon_start_utc(7),  m_lon_end_utc(16),
                                        m_ny_start_utc(12),  m_ny_end_utc(21),
                                        m_broker_gmt_offset_h(0) {}

   void              Configure(const int lon_start_utc, const int lon_end_utc,
                               const int ny_start_utc,  const int ny_end_utc)
     {
      m_lon_start_utc = lon_start_utc; m_lon_end_utc = lon_end_utc;
      m_ny_start_utc  = ny_start_utc;  m_ny_end_utc  = ny_end_utc;
     }

   void              CalibrateBrokerOffset()
     {
      m_broker_gmt_offset_h = BrokerOffset(0);
     }

   int               BrokerOffsetHours() const { return m_broker_gmt_offset_h; }

   bool              IsOpen(const datetime server_time) const
     {
      MqlDateTime d; TimeToStruct(server_time, d);
      if(d.day_of_week == 0 || d.day_of_week == 6) return false;
      const int h_server = d.hour;
      const int h_utc    = (h_server - m_broker_gmt_offset_h + 24) % 24;
      const bool in_lon = h_utc >= m_lon_start_utc && h_utc < m_lon_end_utc;
      const bool in_ny  = h_utc >= m_ny_start_utc  && h_utc < m_ny_end_utc;
      return in_lon || in_ny;
     }

   // Test seam: lets unit harnesses inject a fake broker offset without
   // calling TimeTradeServer(), which is not deterministic in scripts.
   void              SetBrokerOffsetForTest(const int hours) { m_broker_gmt_offset_h = hours; }
  };

#endif // __XAUUSD_SCALPER_SESSION_FILTER_MQH__
