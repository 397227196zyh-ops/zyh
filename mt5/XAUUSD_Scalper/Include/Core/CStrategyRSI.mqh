#ifndef __XAUUSD_SCALPER_STRATEGY_RSI_MQH__
#define __XAUUSD_SCALPER_STRATEGY_RSI_MQH__

#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

class CStrategyRSI : public CStrategyBase
  {
private:
   double            m_lo;
   double            m_hi;
   double            m_dist;
   double            m_sl;
   double            m_tp;

public:
                     CStrategyRSI() : m_lo(25), m_hi(75), m_dist(5.0), m_sl(0.6), m_tp(0.5)
     {
      m_name  = "RSI";
      m_magic = 7010003;
     }

   void              Configure(const double lo, const double hi, const double dist,
                               const double sl, const double tp)
     {
      m_lo = lo; m_hi = hi; m_dist = dist; m_sl = sl; m_tp = tp;
     }

   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r; r.direction = SIGNAL_NONE; r.stop_loss = 0; r.take_profit = 0;
      if(ctx.im == NULL) return r;

      double rsi_prev = ctx.im.RSI(1);
      double rsi_curr = ctx.im.RSI(0);
      double e50      = ctx.im.EMA(50, 0);
      double dist     = MathAbs(ctx.bid - e50);

      if(dist > m_dist) return r;

      bool over_sold_up   = rsi_prev < m_lo && rsi_curr > rsi_prev;
      bool over_bought_dn = rsi_prev > m_hi && rsi_curr < rsi_prev;

      if(over_sold_up)
        {
         r.direction   = SIGNAL_BUY;
         r.stop_loss   = ctx.bid - m_sl;
         r.take_profit = ctx.bid + m_tp;
        }
      else if(over_bought_dn)
        {
         r.direction   = SIGNAL_SELL;
         r.stop_loss   = ctx.ask + m_sl;
         r.take_profit = ctx.ask - m_tp;
        }
      return r;
     }
  };

#endif // __XAUUSD_SCALPER_STRATEGY_RSI_MQH__
