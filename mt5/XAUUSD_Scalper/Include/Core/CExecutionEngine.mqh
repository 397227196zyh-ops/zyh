#ifndef __XAUUSD_SCALPER_EXECUTION_ENGINE_MQH__
#define __XAUUSD_SCALPER_EXECUTION_ENGINE_MQH__

#include <Trade/Trade.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

// Market / limit order placement, retry, partial-fill handling, slippage
// tracking. Persistence and full reporting come in P4.

struct ExecutionResult
  {
   bool     filled;
   ulong    ticket;
   double   filled_price;
   double   slippage;
   int      retcode;
   string   reason_str;
  };

class CExecutionEngine
  {
private:
   CTrade            m_trade;
   string            m_symbol;
   ulong             m_magic;
   int               m_max_retries;
   int               m_retry_sleep_ms;
   double            m_limit_offset;   // e.g. 0.10 USD off the opposite price
   int               m_limit_timeout_s;
   bool              m_dry_run;        // true -> never call OrderSend, for smoke tests

   static bool IsRetryable(const int retcode)
     {
      return retcode == TRADE_RETCODE_REQUOTE
          || retcode == TRADE_RETCODE_PRICE_OFF
          || retcode == TRADE_RETCODE_PRICE_CHANGED
          || retcode == TRADE_RETCODE_CONNECTION
          || retcode == TRADE_RETCODE_TIMEOUT;
     }

public:
                     CExecutionEngine() : m_symbol(""), m_magic(0),
                                          m_max_retries(3), m_retry_sleep_ms(100),
                                          m_limit_offset(0.10), m_limit_timeout_s(5),
                                          m_dry_run(false) {}

   void              SetSymbol(const string sym)
     {
      m_symbol = sym;
      // Doo Prime XAUUSD requires FOK; on other brokers FOK still works as
      // long as the requested volume is exactly fillable, which is the
      // case for our 0.01-lot orders.
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
     }
   void              SetMagic(const ulong magic) { m_magic = magic; m_trade.SetExpertMagicNumber(magic); }
   void              SetDryRun(const bool v)     { m_dry_run = v; }
   void              SetTypeFilling(const ENUM_ORDER_TYPE_FILLING f) { m_trade.SetTypeFilling(f); }
   void              Configure(const int max_retries, const int retry_sleep_ms,
                               const double limit_offset, const int limit_timeout_s)
     {
      m_max_retries    = max_retries;
      m_retry_sleep_ms = retry_sleep_ms;
      m_limit_offset   = limit_offset;
      m_limit_timeout_s = limit_timeout_s;
     }

   ExecutionResult   PlaceMarket(const int direction, const double volume,
                                 const double sl, const double tp,
                                 const double requested_price)
     {
      ExecutionResult r; r.filled = false; r.ticket = 0; r.filled_price = 0.0;
      r.slippage = 0.0; r.retcode = 0; r.reason_str = "";

      if(m_dry_run) { r.reason_str = "DRY_RUN"; return r; }

      for(int attempt = 0; attempt <= m_max_retries; attempt++)
        {
         bool ok;
         if(direction > 0) ok = m_trade.Buy (volume, m_symbol, 0.0, sl, tp, "");
         else              ok = m_trade.Sell(volume, m_symbol, 0.0, sl, tp, "");

         r.retcode = (int)m_trade.ResultRetcode();
         if(ok)
           {
            r.filled       = true;
            r.ticket       = m_trade.ResultOrder();
            r.filled_price = m_trade.ResultPrice();
            r.slippage     = MathAbs(r.filled_price - requested_price);
            r.reason_str   = "FILLED";
            return r;
           }

         if(!IsRetryable(r.retcode))
           {
            r.reason_str = "FATAL";
            return r;
           }
         Sleep(m_retry_sleep_ms);
        }
      r.reason_str = "EXHAUSTED_RETRIES";
      return r;
     }

   ExecutionResult   PlaceLimit(const int direction, const double volume,
                                const double price, const double sl, const double tp)
     {
      ExecutionResult r; r.filled = false; r.ticket = 0; r.filled_price = 0.0;
      r.slippage = 0.0; r.retcode = 0; r.reason_str = "";

      if(m_dry_run) { r.reason_str = "DRY_RUN"; return r; }

      bool ok;
      if(direction > 0) ok = m_trade.BuyLimit (volume, price, m_symbol, sl, tp, ORDER_TIME_GTC, 0, "");
      else              ok = m_trade.SellLimit(volume, price, m_symbol, sl, tp, ORDER_TIME_GTC, 0, "");

      r.retcode = (int)m_trade.ResultRetcode();
      if(ok)
        {
         r.ticket     = m_trade.ResultOrder();
         r.reason_str = "LIMIT_PLACED";
         return r;
        }
      r.reason_str = "LIMIT_FAIL";
      return r;
     }

   bool              ClosePartial(const ulong ticket, const double volume)
     {
      if(m_dry_run) return true;
      return m_trade.PositionClosePartial(ticket, volume);
     }

   bool              Close(const ulong ticket)
     {
      if(m_dry_run) return true;
      return m_trade.PositionClose(ticket);
     }

   bool              ModifyStops(const ulong ticket, const double sl, const double tp)
     {
      if(m_dry_run) return true;
      return m_trade.PositionModify(ticket, sl, tp);
     }
  };

#endif // __XAUUSD_SCALPER_EXECUTION_ENGINE_MQH__
