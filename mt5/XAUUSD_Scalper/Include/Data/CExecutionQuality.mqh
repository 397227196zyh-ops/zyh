#ifndef __XAUUSD_SCALPER_EXECUTION_QUALITY_MQH__
#define __XAUUSD_SCALPER_EXECUTION_QUALITY_MQH__

struct ExecQualityRow
  {
   datetime time;
   string   strat;
   int      side;              // +1 long, -1 short
   double   requested_price;
   double   fill_price;
   double   slippage;
   int      retries;
   int      latency_ms;
   string   order_type;        // "market" / "limit"
  };

class CExecutionQuality
  {
private:
   int    m_fh;

public:
                     CExecutionQuality() : m_fh(INVALID_HANDLE) {}
                    ~CExecutionQuality() { Close(); }

   bool              Open(const string path = "XAUUSD_Scalper/execution_quality.csv")
     {
      bool existed = FileIsExist(path);
      m_fh = FileOpen(path, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
      if(m_fh == INVALID_HANDLE) return false;
      FileSeek(m_fh, 0, SEEK_END);
      if(!existed)
         FileWrite(m_fh, "time","strat","side","requested_price","fill_price",
                         "slippage","retries","latency_ms","order_type");
      return true;
     }

   void              Close() { if(m_fh != INVALID_HANDLE) { FileClose(m_fh); m_fh = INVALID_HANDLE; } }

   bool              Write(const ExecQualityRow &r)
     {
      if(m_fh == INVALID_HANDLE) return false;
      FileWrite(m_fh,
                TimeToString(r.time, TIME_DATE|TIME_SECONDS),
                r.strat, r.side,
                DoubleToString(r.requested_price, 5),
                DoubleToString(r.fill_price,      5),
                DoubleToString(r.slippage,        5),
                r.retries, r.latency_ms, r.order_type);
      FileFlush(m_fh);
      return true;
     }
  };

#endif // __XAUUSD_SCALPER_EXECUTION_QUALITY_MQH__
