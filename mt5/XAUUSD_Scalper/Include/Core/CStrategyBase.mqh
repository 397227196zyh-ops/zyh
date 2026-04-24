#ifndef __XAUUSD_SCALPER_STRATEGY_BASE_MQH__
#define __XAUUSD_SCALPER_STRATEGY_BASE_MQH__

#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>

enum ENUM_SIGNAL_DIRECTION
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
  };

struct StrategyContext
  {
   CIndicatorManager *im;
   CTickCollector    *tc;
   ENUM_MARKET_STATE  state;
   double             bid;
   double             ask;
   datetime           time;
  };

struct SignalResult
  {
   ENUM_SIGNAL_DIRECTION direction;
   double                stop_loss;
   double                take_profit;
  };

class CStrategyBase
  {
protected:
   string            m_name;
   ulong             m_magic;
   int               m_trades;
   int               m_wins;
   double            m_gross_pnl;
   double            m_gross_win;
   double            m_gross_loss;

public:
                     CStrategyBase() : m_name(""), m_magic(0), m_trades(0), m_wins(0),
                                       m_gross_pnl(0), m_gross_win(0), m_gross_loss(0) {}
   virtual          ~CStrategyBase() {}

   string            Name() const  { return m_name; }
   ulong             Magic() const { return m_magic; }
   int               Trades() const { return m_trades; }
   int               Wins() const   { return m_wins; }
   double            GrossPnL() const { return m_gross_pnl; }

   void              OnTradeClosed(const double pnl)
     {
      m_trades++;
      m_gross_pnl += pnl;
      if(pnl > 0) { m_wins++; m_gross_win += pnl; }
      else        { m_gross_loss += -pnl; }
     }

   double            WinRate() const
     {
      return m_trades > 0 ? (double)m_wins / (double)m_trades : 0.0;
     }

   double            PayoffRatio() const
     {
      double avg_w = m_wins > 0 ? m_gross_win / (double)m_wins : 0.0;
      int losses = m_trades - m_wins;
      double avg_l = losses > 0 ? m_gross_loss / (double)losses : 0.0;
      return avg_l > 0 ? avg_w / avg_l : 0.0;
     }

   double            CalculateKellyFraction(const int min_trades,
                                            const double cold_p, const double cold_b) const
     {
      double p, b;
      if(m_trades < min_trades) { p = cold_p; b = cold_b; }
      else                      { p = WinRate(); b = PayoffRatio(); }
      if(b <= 0.0) return 0.0;
      double f = (p * b - (1.0 - p)) / b;
      if(f < 0.0) f = 0.0;
      return f;
     }

   virtual SignalResult CheckSignal(const StrategyContext &ctx) = 0;
  };

#endif // __XAUUSD_SCALPER_STRATEGY_BASE_MQH__
