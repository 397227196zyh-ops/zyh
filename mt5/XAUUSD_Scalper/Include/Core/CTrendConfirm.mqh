#ifndef __XAUUSD_SCALPER_TREND_CONFIRM_MQH__
#define __XAUUSD_SCALPER_TREND_CONFIRM_MQH__

#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBase.mqh>

enum ENUM_TREND_STATE
  {
   TREND_NEUTRAL = 0,
   TREND_BULLISH = 1,
   TREND_BEARISH = 2
  };

class CTrendConfirm
  {
private:
   double            m_far_threshold;

public:
                     CTrendConfirm() : m_far_threshold(1.0) {}

   void              Configure(const double far_threshold) { m_far_threshold = far_threshold; }

   ENUM_TREND_STATE  Classify(const CIndicatorManager &im, const double bid) const
     {
      double e20_0 = im.EMA20_M5(0);
      double e20_1 = im.EMA20_M5(1);
      double e20_2 = im.EMA20_M5(2);
      double e50   = im.EMA50_M5(0);
      if(e20_0 > e50 && e20_0 > e20_1 && e20_1 > e20_2 && bid > e20_0) return TREND_BULLISH;
      if(e20_0 < e50 && e20_0 < e20_1 && e20_1 < e20_2 && bid < e20_0) return TREND_BEARISH;
      return TREND_NEUTRAL;
     }

   ENUM_TREND_STATE  ClassifyH1(const CIndicatorManager &im, const double bid) const
     {
      double e20 = im.EMA20_H1(0);
      double e50 = im.EMA50_H1(0);
      if(e20 > e50 && bid > e20) return TREND_BULLISH;
      if(e20 < e50 && bid < e20) return TREND_BEARISH;
      return TREND_NEUTRAL;
     }

   bool              Allows(const string strat_name, const ENUM_SIGNAL_DIRECTION dir,
                            const ENUM_TREND_STATE  state,
                            const double bid, const double ema20_m5) const
     {
      if(dir == SIGNAL_NONE) return false;
      if(strat_name == "EMA")
        {
         if(dir == SIGNAL_BUY)  return state == TREND_BULLISH || state == TREND_NEUTRAL;
         if(dir == SIGNAL_SELL) return state == TREND_BEARISH || state == TREND_NEUTRAL;
        }
      else if(strat_name == "BOLL")
        {
         if(dir == SIGNAL_BUY)  return state == TREND_BULLISH;
         if(dir == SIGNAL_SELL) return state == TREND_BEARISH;
        }
      else if(strat_name == "RSI")
        {
         double dist = MathAbs(bid - ema20_m5);
         if(dir == SIGNAL_BUY)
           {
            if(state == TREND_BEARISH) return false;
            if(state == TREND_BULLISH) return dist <= m_far_threshold;
            return true;
           }
         if(dir == SIGNAL_SELL)
           {
            if(state == TREND_BULLISH) return false;
            if(state == TREND_BEARISH) return dist <= m_far_threshold;
            return true;
           }
        }
      else if(strat_name == "BRK")
        {
         // Donchian breakout: only confirm trades that line up with the
         // higher-timeframe trend. A long break against a bearish EMA20_M5
         // structure is exactly the false-breakout pattern we want to skip.
         if(dir == SIGNAL_BUY)  return state == TREND_BULLISH || state == TREND_NEUTRAL;
         if(dir == SIGNAL_SELL) return state == TREND_BEARISH || state == TREND_NEUTRAL;
        }
      return false;
     }
  };

#endif // __XAUUSD_SCALPER_TREND_CONFIRM_MQH__
