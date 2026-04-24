#ifndef __XAUUSD_SCALPER_TRADE_HISTORY_MQH__
#define __XAUUSD_SCALPER_TRADE_HISTORY_MQH__

struct TradeRow
  {
   datetime open_time;
   datetime close_time;
   string   strat;
   int      dir;
   double   entry;
   double   exit;
   double   lots;
   double   pnl;
   double   commission;
   double   swap;
   int      market_state_on_open;
   double   liquidity_score_on_open;
   double   slippage;
   int      exec_ms;
   bool     was_limit;
  };

class CTradeHistory
  {
private:
   int    m_fh;

public:
                     CTradeHistory() : m_fh(INVALID_HANDLE) {}
                    ~CTradeHistory() { Close(); }

   bool              Open(const string path = "XAUUSD_Scalper/trade_history.csv")
     {
      bool existed = FileIsExist(path);
      m_fh = FileOpen(path, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
      if(m_fh == INVALID_HANDLE) return false;
      FileSeek(m_fh, 0, SEEK_END);
      if(!existed)
         FileWrite(m_fh, "open_time","close_time","strat","dir","entry","exit",
                         "lots","pnl","commission","swap","market_state_on_open",
                         "liquidity_score_on_open","slippage","exec_ms","was_limit");
      return true;
     }

   void              Close() { if(m_fh != INVALID_HANDLE) { FileClose(m_fh); m_fh = INVALID_HANDLE; } }

   bool              Write(const TradeRow &r)
     {
      if(m_fh == INVALID_HANDLE) return false;
      FileWrite(m_fh,
                TimeToString(r.open_time,  TIME_DATE|TIME_SECONDS),
                TimeToString(r.close_time, TIME_DATE|TIME_SECONDS),
                r.strat, r.dir,
                DoubleToString(r.entry, 5), DoubleToString(r.exit, 5),
                DoubleToString(r.lots,  2), DoubleToString(r.pnl,  2),
                DoubleToString(r.commission, 2),
                DoubleToString(r.swap, 2),
                r.market_state_on_open,
                DoubleToString(r.liquidity_score_on_open, 2),
                DoubleToString(r.slippage, 5),
                r.exec_ms,
                r.was_limit ? 1 : 0);
      FileFlush(m_fh);
      return true;
     }
  };

#endif // __XAUUSD_SCALPER_TRADE_HISTORY_MQH__
