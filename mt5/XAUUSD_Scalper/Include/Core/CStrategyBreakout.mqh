#ifndef __XAUUSD_SCALPER_STRATEGY_BREAKOUT_MQH__
#define __XAUUSD_SCALPER_STRATEGY_BREAKOUT_MQH__

#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

// Donchian-style N-period high/low breakout. The strategy is long when the
// most recently closed M1 bar takes out the highest high of the prior N
// bars; short on the inverse. Designed as a momentum-scalper companion to
// the mean-reversion EMA: opposite signal pattern, same SL/TP scale.
//
// Re-entry suppression is per closed bar (matches CStrategyEMA), so a
// long-running breakout fires once when the bar closes above the prior
// extreme rather than every tick after.
class CStrategyBreakout : public CStrategyBase
  {
private:
   int               m_lookback_bars;
   double            m_sl_atr_mult;
   double            m_tp_atr_mult;
   double            m_sl_min;
   double            m_sl_max;
   double            m_tp_min;
   double            m_tp_max;
   datetime          m_last_signal_bar;

public:
                     CStrategyBreakout() : m_lookback_bars(20),
                                           m_sl_atr_mult(0.0), m_tp_atr_mult(0.0),
                                           m_sl_min(0.5), m_sl_max(1.5),
                                           m_tp_min(0.5), m_tp_max(1.5),
                                           m_last_signal_bar(0)
     {
      m_name = "BRK";
      m_magic = 7010004;
     }

   void              Configure(const int lookback_bars,
                               const double sl_atr_mult, const double tp_atr_mult,
                               const double sl_min, const double sl_max,
                               const double tp_min, const double tp_max)
     {
      m_lookback_bars = lookback_bars > 1 ? lookback_bars : 2;
      m_sl_atr_mult = sl_atr_mult;
      m_tp_atr_mult = tp_atr_mult;
      m_sl_min = sl_min > 0.0 ? sl_min : 0.5;
      m_sl_max = sl_max > 0.0 ? sl_max : 3.0;
      m_tp_min = tp_min > 0.0 ? tp_min : 0.5;
      m_tp_max = tp_max > 0.0 ? tp_max : 3.0;
     }

   virtual SignalResult CheckSignal(const StrategyContext &ctx) override
     {
      SignalResult r; r.direction = SIGNAL_NONE; r.stop_loss = 0; r.take_profit = 0;

      // Need N+1 bars of history: N for the lookback window plus the closed
      // bar that is doing the breaking out (shift=1).
      const int needed = m_lookback_bars + 2;
      if(Bars(_Symbol, _Period) < needed) return r;

      // Closed bar's H/L (shift=1).
      double last_high = iHigh(_Symbol, _Period, 1);
      double last_low  = iLow(_Symbol,  _Period, 1);
      if(last_high <= 0.0 || last_low <= 0.0) return r;

      // Highest high / lowest low of the N bars BEFORE the closed one
      // (shift range [2 .. N+1]). iHighest/iLowest count is from `start`.
      int hi_shift = iHighest(_Symbol, _Period, MODE_HIGH, m_lookback_bars, 2);
      int lo_shift = iLowest (_Symbol, _Period, MODE_LOW,  m_lookback_bars, 2);
      if(hi_shift < 0 || lo_shift < 0) return r;

      double prior_high = iHigh(_Symbol, _Period, hi_shift);
      double prior_low  = iLow(_Symbol,  _Period, lo_shift);
      if(prior_high <= 0.0 || prior_low <= 0.0) return r;

      const bool long_break  = last_high > prior_high;
      const bool short_break = last_low  < prior_low;
      if(!(long_break || short_break)) return r;
      if(long_break && short_break) return r; // freak bar straddles both ends — skip

      // One signal per closed bar.
      datetime bar_time = ctx.time - (ctx.time % 60);
      if(bar_time == m_last_signal_bar) return r;
      m_last_signal_bar = bar_time;

      double sl_dist, tp_dist;
      if(m_sl_atr_mult > 0.0 && ctx.im != NULL)
        {
         double atr = ctx.im.ATR(1);
         sl_dist = MathMax(m_sl_min, MathMin(atr * m_sl_atr_mult, m_sl_max));
         tp_dist = MathMax(m_tp_min, MathMin(atr * m_tp_atr_mult, m_tp_max));
        }
      else
        {
         sl_dist = m_sl_max;
         tp_dist = m_tp_max;
        }

      if(long_break)
        {
         r.direction   = SIGNAL_BUY;
         r.stop_loss   = ctx.bid - sl_dist;
         r.take_profit = ctx.bid + tp_dist;
        }
      else
        {
         r.direction   = SIGNAL_SELL;
         r.stop_loss   = ctx.ask + sl_dist;
         r.take_profit = ctx.ask - tp_dist;
        }
      return r;
     }
  };

#endif // __XAUUSD_SCALPER_STRATEGY_BREAKOUT_MQH__
