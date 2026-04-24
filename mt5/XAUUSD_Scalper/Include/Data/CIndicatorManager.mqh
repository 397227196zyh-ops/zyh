#ifndef __XAUUSD_SCALPER_INDICATOR_MANAGER_MQH__
#define __XAUUSD_SCALPER_INDICATOR_MANAGER_MQH__

class CIndicatorManager
  {
private:
   string            m_symbol;

   int               h_ema5, h_ema10, h_ema20, h_ema50;
   int               h_bb, h_rsi, h_atr, h_adx;
   int               h_ema20_m5, h_ema50_m5;

   double            b_ema5[], b_ema10[], b_ema20[], b_ema50[];
   double            b_bb_up[], b_bb_mid[], b_bb_lo[];
   double            b_rsi[], b_atr[], b_adx[], b_plus_di[], b_minus_di[];
   double            b_ema20_m5[], b_ema50_m5[];

   bool              CopyOne(const int handle, const int buffer_index, double &dst[])
     {
      if(handle == INVALID_HANDLE) return false;
      if(CopyBuffer(handle, buffer_index, 0, 5, dst) < 5) return false;
      ArraySetAsSeries(dst, true);
      return true;
     }

public:
                     CIndicatorManager() : m_symbol(""),
                                           h_ema5(INVALID_HANDLE),  h_ema10(INVALID_HANDLE),
                                           h_ema20(INVALID_HANDLE), h_ema50(INVALID_HANDLE),
                                           h_bb(INVALID_HANDLE),    h_rsi(INVALID_HANDLE),
                                           h_atr(INVALID_HANDLE),   h_adx(INVALID_HANDLE),
                                           h_ema20_m5(INVALID_HANDLE), h_ema50_m5(INVALID_HANDLE) {}

   bool              Init(const string symbol)
     {
      m_symbol = symbol;
      h_ema5      = iMA (m_symbol, PERIOD_M1,  5, 0, MODE_EMA, PRICE_CLOSE);
      h_ema10     = iMA (m_symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
      h_ema20     = iMA (m_symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
      h_ema50     = iMA (m_symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
      h_bb        = iBands(m_symbol, PERIOD_M1, 20, 0, 2.0, PRICE_CLOSE);
      h_rsi       = iRSI  (m_symbol, PERIOD_M1, 14, PRICE_CLOSE);
      h_atr       = iATR  (m_symbol, PERIOD_M1, 14);
      h_adx       = iADX  (m_symbol, PERIOD_M1, 14);
      h_ema20_m5  = iMA (m_symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
      h_ema50_m5  = iMA (m_symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
      return h_ema5  != INVALID_HANDLE && h_ema10 != INVALID_HANDLE &&
             h_ema20 != INVALID_HANDLE && h_ema50 != INVALID_HANDLE &&
             h_bb    != INVALID_HANDLE && h_rsi   != INVALID_HANDLE &&
             h_atr   != INVALID_HANDLE && h_adx   != INVALID_HANDLE &&
             h_ema20_m5 != INVALID_HANDLE && h_ema50_m5 != INVALID_HANDLE;
     }

   void              Shutdown()
     {
      if(h_ema5  != INVALID_HANDLE) IndicatorRelease(h_ema5);
      if(h_ema10 != INVALID_HANDLE) IndicatorRelease(h_ema10);
      if(h_ema20 != INVALID_HANDLE) IndicatorRelease(h_ema20);
      if(h_ema50 != INVALID_HANDLE) IndicatorRelease(h_ema50);
      if(h_bb    != INVALID_HANDLE) IndicatorRelease(h_bb);
      if(h_rsi   != INVALID_HANDLE) IndicatorRelease(h_rsi);
      if(h_atr   != INVALID_HANDLE) IndicatorRelease(h_atr);
      if(h_adx   != INVALID_HANDLE) IndicatorRelease(h_adx);
      if(h_ema20_m5 != INVALID_HANDLE) IndicatorRelease(h_ema20_m5);
      if(h_ema50_m5 != INVALID_HANDLE) IndicatorRelease(h_ema50_m5);
     }

   void              Update()
     {
      CopyOne(h_ema5, 0, b_ema5);
      CopyOne(h_ema10,0, b_ema10);
      CopyOne(h_ema20,0, b_ema20);
      CopyOne(h_ema50,0, b_ema50);
      CopyOne(h_bb,   0, b_bb_mid);
      CopyOne(h_bb,   1, b_bb_up);
      CopyOne(h_bb,   2, b_bb_lo);
      CopyOne(h_rsi,  0, b_rsi);
      CopyOne(h_atr,  0, b_atr);
      CopyOne(h_adx,  0, b_adx);
      CopyOne(h_adx,  1, b_plus_di);
      CopyOne(h_adx,  2, b_minus_di);
      CopyOne(h_ema20_m5, 0, b_ema20_m5);
      CopyOne(h_ema50_m5, 0, b_ema50_m5);
     }

   double            EMA(const int period, const int shift) const
     {
      switch(period)
        {
         case 5:  return shift < ArraySize(b_ema5)  ? b_ema5[shift]  : 0.0;
         case 10: return shift < ArraySize(b_ema10) ? b_ema10[shift] : 0.0;
         case 20: return shift < ArraySize(b_ema20) ? b_ema20[shift] : 0.0;
         case 50: return shift < ArraySize(b_ema50) ? b_ema50[shift] : 0.0;
         default: return 0.0;
        }
     }

   double            BBUpper(const int shift) const { return shift < ArraySize(b_bb_up)  ? b_bb_up[shift]  : 0.0; }
   double            BBMiddle(const int shift) const{ return shift < ArraySize(b_bb_mid) ? b_bb_mid[shift] : 0.0; }
   double            BBLower(const int shift) const { return shift < ArraySize(b_bb_lo)  ? b_bb_lo[shift]  : 0.0; }
   double            RSI(const int shift) const { return shift < ArraySize(b_rsi) ? b_rsi[shift] : 0.0; }
   double            ATR(const int shift) const { return shift < ArraySize(b_atr) ? b_atr[shift] : 0.0; }
   double            ADX(const int shift) const { return shift < ArraySize(b_adx) ? b_adx[shift] : 0.0; }
   double            PlusDI(const int shift) const { return shift < ArraySize(b_plus_di) ? b_plus_di[shift] : 0.0; }
   double            MinusDI(const int shift) const { return shift < ArraySize(b_minus_di) ? b_minus_di[shift] : 0.0; }

   double            EMA20_M5(const int shift) const { return shift < ArraySize(b_ema20_m5) ? b_ema20_m5[shift] : 0.0; }
   double            EMA50_M5(const int shift) const { return shift < ArraySize(b_ema50_m5) ? b_ema50_m5[shift] : 0.0; }

   double            BBWidth(const int shift) const { return BBUpper(shift) - BBLower(shift); }
   double            PriceInBand(const double price, const int shift) const
     {
      double w = BBWidth(shift);
      if(w <= 0.0) return 0.5;
      return (price - BBLower(shift)) / w;
     }
  };

#endif // __XAUUSD_SCALPER_INDICATOR_MANAGER_MQH__
