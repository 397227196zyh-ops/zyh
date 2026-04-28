#ifndef __XAUUSD_SCALPER_STRATEGY_EMA_MQH__
#define __XAUUSD_SCALPER_STRATEGY_EMA_MQH__

#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

// EMA fast crossover. Cross is detected on closed M1 bars (shift 1 vs 2),
// and the strategy only fires once per new bar to avoid re-emitting the
// same signal every tick within the same minute.
class CStrategyEMA : public CStrategyBase
  {
private:
   double            m_sl_mult;
   double            m_tp_mult;
   double            m_sl_min;
   double            m_sl_max;
   datetime          m_last_signal_bar;

   double            ClampSL(const double sl_dist) const
     {
      double d = sl_dist;
      if(d < m_sl_min) d = m_sl_min;
      if(d > m_sl_max) d = m_sl_max;
      return d;
     }

public:
                     CStrategyEMA() : m_sl_mult(1.5), m_tp_mult(1.2),
                                      m_sl_min(0.5), m_sl_max(2.0),
                                      m_last_signal_bar(0)
     {
      m_name = "EMA";
      m_magic = 7010001;
     }

   void              Configure(const double sl_mult, const double tp_mult,
                               const double sl_min,  const double sl_max)
     {
      m_sl_mult = sl_mult; m_tp_mult = tp_mult;
      m_sl_min  = sl_min;  m_sl_max  = sl_max;
     }

   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r; r.direction = SIGNAL_NONE; r.stop_loss = 0; r.take_profit = 0;
      if(ctx.im == NULL) return r;

      // Compare two closed bars: the most recently closed (shift=1) vs the
      // bar before it (shift=2). This is what "EMA(5) crosses EMA(10)"
      // operationally means without retriggering on every intra-bar tick.
      double e5_prev  = ctx.im.EMA(5,  2);
      double e5_curr  = ctx.im.EMA(5,  1);
      double e10_prev = ctx.im.EMA(10, 2);
      double e10_curr = ctx.im.EMA(10, 1);
      double e20      = ctx.im.EMA(20, 1);
      double atr      = ctx.im.ATR(1);

      double sl_dist = ClampSL(atr * m_sl_mult);
      double tp_dist = atr * m_tp_mult;

      bool bull_cross = (e5_prev <= e10_prev) && (e5_curr > e10_curr) && (ctx.bid > e20);
      bool bear_cross = (e5_prev >= e10_prev) && (e5_curr < e10_curr) && (ctx.bid < e20);

      if(!(bull_cross || bear_cross)) return r;

      // Only fire once per closed bar. ctx.time is the broker server time
      // of the live tick; we collapse it to the most recent minute.
      datetime bar_time = ctx.time - (ctx.time % 60);
      if(bar_time == m_last_signal_bar) return r;
      m_last_signal_bar = bar_time;

      if(bull_cross)
        {
         r.direction   = SIGNAL_BUY;
         r.stop_loss   = ctx.bid - sl_dist;
         r.take_profit = ctx.bid + tp_dist;
        }
      else if(bear_cross)
        {
         r.direction   = SIGNAL_SELL;
         r.stop_loss   = ctx.ask + sl_dist;
         r.take_profit = ctx.ask - tp_dist;
        }
      return r;
     }
  };

#endif // __XAUUSD_SCALPER_STRATEGY_EMA_MQH__
