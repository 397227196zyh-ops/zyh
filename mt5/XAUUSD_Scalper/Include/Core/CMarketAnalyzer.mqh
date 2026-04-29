#ifndef __XAUUSD_SCALPER_MARKET_ANALYZER_MQH__
#define __XAUUSD_SCALPER_MARKET_ANALYZER_MQH__

enum ENUM_MARKET_STATE
  {
   MARKET_RANGING  = 0,
   MARKET_TRENDING = 1,
   MARKET_BREAKOUT = 2,
   MARKET_ABNORMAL = 3
  };

struct MarketInputs
  {
   double adx;
   double atr;
   double atr_avg;
   double bb_width;
   double last_spread;
   double max_jump;
   double ticks_per_s;
   int    breakouts;
  };

struct MarketThresholds
  {
   double atr_blowup_mult;     // atr / atr_avg ratio → ABNORMAL
   double max_spread;          // USD → ABNORMAL
   double max_jump;            // USD → ABNORMAL
   double min_ticks_per_s;     // ticks/s threshold → ABNORMAL
   double trending_adx;
   double breakout_bb_width;
   int    breakout_count;
  };

class CMarketAnalyzer
  {
public:
   // Legacy entry point kept for unit tests (uses spec defaults).
   static ENUM_MARKET_STATE Classify(const MarketInputs &in)
     {
      MarketThresholds t;
      t.atr_blowup_mult   = 2.5;
      t.max_spread        = 0.15;
      t.max_jump          = 0.5;
      t.min_ticks_per_s   = 3.0;
      t.trending_adx      = 25.0;
      t.breakout_bb_width = 2.0;
      t.breakout_count    = 2;
      return ClassifyWith(in, t);
     }

   // Threshold-aware entry point so brokers with wider tick jumps can be
   // accommodated without forking the rule.
   static ENUM_MARKET_STATE ClassifyWith(const MarketInputs &in, const MarketThresholds &t)
     {
      if(in.atr_avg > 0.0 && in.atr > in.atr_avg * t.atr_blowup_mult) return MARKET_ABNORMAL;
      if(in.last_spread > t.max_spread)                                return MARKET_ABNORMAL;
      if(in.max_jump    > t.max_jump)                                  return MARKET_ABNORMAL;
      if(in.ticks_per_s > 0.0 && in.ticks_per_s < t.min_ticks_per_s)   return MARKET_ABNORMAL;

      if(in.adx >= t.trending_adx && in.atr > in.atr_avg) return MARKET_TRENDING;
      if(in.breakouts >= t.breakout_count && in.bb_width > t.breakout_bb_width)
         return MARKET_BREAKOUT;
      return MARKET_RANGING;
     }
  };

#endif // __XAUUSD_SCALPER_MARKET_ANALYZER_MQH__
