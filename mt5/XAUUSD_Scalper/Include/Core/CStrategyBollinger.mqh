#ifndef __XAUUSD_SCALPER_STRATEGY_BOLL_MQH__
#define __XAUUSD_SCALPER_STRATEGY_BOLL_MQH__

#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

class CStrategyBollinger : public CStrategyBase
  {
private:
   double            m_pullback;
   double            m_sl;
   double            m_tp;

public:
                     CStrategyBollinger() : m_pullback(0.2), m_sl(1.0), m_tp(0.8)
     {
      m_name  = "BOLL";
      m_magic = 7010002;
     }

   void              Configure(const double pullback, const double sl, const double tp)
     {
      m_pullback = pullback; m_sl = sl; m_tp = tp;
     }

   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r; r.direction = SIGNAL_NONE; r.stop_loss = 0; r.take_profit = 0;
      if(ctx.im == NULL) return r;

      double up = ctx.im.BBUpper(0);
      double lo = ctx.im.BBLower(0);

      double dist_up = MathAbs(ctx.bid - up);
      double dist_lo = MathAbs(ctx.bid - lo);

      bool is_up_break = ctx.bid > up - m_pullback && ctx.bid > ctx.im.BBMiddle(0) && dist_up <= m_pullback;
      bool is_lo_break = ctx.bid < lo + m_pullback && ctx.bid < ctx.im.BBMiddle(0) && dist_lo <= m_pullback;

      if(is_up_break)
        {
         r.direction   = SIGNAL_BUY;
         r.stop_loss   = ctx.bid - m_sl;
         r.take_profit = ctx.bid + m_tp;
        }
      else if(is_lo_break)
        {
         r.direction   = SIGNAL_SELL;
         r.stop_loss   = ctx.ask + m_sl;
         r.take_profit = ctx.ask - m_tp;
        }
      return r;
     }
  };

#endif // __XAUUSD_SCALPER_STRATEGY_BOLL_MQH__
