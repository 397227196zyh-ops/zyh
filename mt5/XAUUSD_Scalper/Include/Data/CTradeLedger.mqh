#ifndef __XAUUSD_SCALPER_TRADE_LEDGER_MQH__
#define __XAUUSD_SCALPER_TRADE_LEDGER_MQH__

// In-memory, per-strategy trade stats. Feeds CRiskManager and
// CExecutionGuard. No disk IO — that ships in P4.
//
// Up to 8 strategies tracked via parallel string/int/double arrays. Linear
// lookup is fine at this scale.
#define XAUUSD_LEDGER_MAX_STRATS 8

class CTradeLedger
  {
private:
   string            m_names[XAUUSD_LEDGER_MAX_STRATS];
   int               m_consec[XAUUSD_LEDGER_MAX_STRATS];
   int               m_count;

   double            m_daily_loss_ccy;
   datetime          m_last_fail_time;

   int               FindOrAdd(const string name)
     {
      for(int i = 0; i < m_count; i++)
         if(m_names[i] == name) return i;
      if(m_count >= XAUUSD_LEDGER_MAX_STRATS) return -1;
      m_names[m_count]  = name;
      m_consec[m_count] = 0;
      m_count++;
      return m_count - 1;
     }

   int               Find(const string name) const
     {
      for(int i = 0; i < m_count; i++)
         if(m_names[i] == name) return i;
      return -1;
     }

public:
                     CTradeLedger() : m_count(0), m_daily_loss_ccy(0.0), m_last_fail_time(0) {}

   void              Init()
     {
      m_count          = 0;
      m_daily_loss_ccy = 0.0;
      m_last_fail_time = 0;
     }

   void              OnTradeClosed(const string strat, const double pnl_account_ccy, const datetime when)
     {
      int idx = FindOrAdd(strat);
      if(idx < 0) return;
      if(pnl_account_ccy < 0.0)
        {
         m_consec[idx]    += 1;
         m_daily_loss_ccy += -pnl_account_ccy;
        }
      else
        {
         m_consec[idx] = 0;
        }
     }

   void              OnTradeFailed(const datetime when)
     {
      m_last_fail_time = when;
     }

   int               ConsecLosses(const string strat) const
     {
      int idx = Find(strat);
      if(idx < 0) return 0;
      return m_consec[idx];
     }

   // Worst per-strategy consec-loss across all tracked strategies. Used by the
   // guard so that one strategy with a bad streak does not deadlock the others.
   int               MaxConsecLosses() const
     {
      int worst = 0;
      for(int i = 0; i < m_count; i++)
         if(m_consec[i] > worst) worst = m_consec[i];
      return worst;
     }

   double            DailyLossPct(const double account_equity) const
     {
      if(account_equity <= 0.0) return 0.0;
      return 100.0 * m_daily_loss_ccy / account_equity;
     }

   datetime          LastFailTime() const { return m_last_fail_time; }

   void              OnDayRollover(const datetime day_start)
     {
      m_daily_loss_ccy = 0.0;
      for(int i = 0; i < m_count; i++) m_consec[i] = 0;
     }
  };

#endif // __XAUUSD_SCALPER_TRADE_LEDGER_MQH__
