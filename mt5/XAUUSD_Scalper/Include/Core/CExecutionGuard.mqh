#ifndef __XAUUSD_SCALPER_EXECUTION_GUARD_MQH__
#define __XAUUSD_SCALPER_EXECUTION_GUARD_MQH__

#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

enum ENUM_GUARD_REASON
  {
   GUARD_OK               = 0,
   GUARD_SESSION_CLOSED   = 1,
   GUARD_SPREAD           = 2,
   GUARD_STOPS_LEVEL      = 3,
   GUARD_ABNORMAL_MARKET  = 4,
   GUARD_COOLDOWN         = 5,
   GUARD_CONSEC_LOSSES    = 6,
   GUARD_DAILY_LOSS       = 7
  };

struct GuardInputs
  {
   bool              session_open;
   double            spread;
   double            stops_level;
   double            freeze_level;
   ENUM_MARKET_STATE market_state;
   datetime          now;
   datetime          last_fail_time;
   double            daily_loss_pct;
   int               consec_losses;
  };

struct GuardDecision
  {
   bool              allowed;
   ENUM_GUARD_REASON reason;
  };

class CExecutionGuard
  {
private:
   double            m_max_spread;
   double            m_max_stop_level;
   int               m_cool_off_sec;
   double            m_daily_loss_limit_pct;
   int               m_consec_loss_limit;

public:
                     CExecutionGuard() : m_max_spread(0.08), m_max_stop_level(0.1),
                                         m_cool_off_sec(60), m_daily_loss_limit_pct(2.0),
                                         m_consec_loss_limit(5) {}

   void              Configure(const double max_spread, const double max_stop_level,
                               const int cool_off_sec,  const double daily_loss_limit_pct,
                               const int consec_loss_limit)
     {
      m_max_spread = max_spread; m_max_stop_level = max_stop_level;
      m_cool_off_sec = cool_off_sec;
      m_daily_loss_limit_pct = daily_loss_limit_pct;
      m_consec_loss_limit = consec_loss_limit;
     }

   GuardDecision     Evaluate(const GuardInputs &in) const
     {
      GuardDecision d; d.allowed = false; d.reason = GUARD_OK;
      if(!in.session_open)                              { d.reason = GUARD_SESSION_CLOSED;  return d; }
      if(in.spread > m_max_spread)                      { d.reason = GUARD_SPREAD;          return d; }
      if(in.stops_level > m_max_stop_level ||
         in.freeze_level > m_max_stop_level)            { d.reason = GUARD_STOPS_LEVEL;     return d; }
      if(in.market_state == MARKET_ABNORMAL)            { d.reason = GUARD_ABNORMAL_MARKET; return d; }
      if(in.consec_losses >= m_consec_loss_limit)       { d.reason = GUARD_CONSEC_LOSSES;   return d; }
      if(in.daily_loss_pct >= m_daily_loss_limit_pct)   { d.reason = GUARD_DAILY_LOSS;      return d; }
      if(in.last_fail_time != 0 &&
         in.now - in.last_fail_time < m_cool_off_sec)   { d.reason = GUARD_COOLDOWN;        return d; }
      d.allowed = true;
      return d;
     }
  };

#endif // __XAUUSD_SCALPER_EXECUTION_GUARD_MQH__
