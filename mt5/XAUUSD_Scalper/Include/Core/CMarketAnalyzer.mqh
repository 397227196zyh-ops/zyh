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

class CMarketAnalyzer
  {
public:
   static ENUM_MARKET_STATE Classify(const MarketInputs &in)
     {
      if(in.atr > in.atr_avg * 2.5) return MARKET_ABNORMAL;
      if(in.last_spread > 0.15)     return MARKET_ABNORMAL;
      if(in.max_jump    > 0.5)      return MARKET_ABNORMAL;
      if(in.ticks_per_s < 3.0)      return MARKET_ABNORMAL;

      if(in.adx >= 25.0 && in.atr > in.atr_avg) return MARKET_TRENDING;

      if(in.breakouts >= 2 && in.bb_width > 2.0) return MARKET_BREAKOUT;

      return MARKET_RANGING;
     }
  };

#endif // __XAUUSD_SCALPER_MARKET_ANALYZER_MQH__
