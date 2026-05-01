#ifndef __XAUUSD_SCALPER_POSITION_MANAGER_MQH__
#define __XAUUSD_SCALPER_POSITION_MANAGER_MQH__

#include <XAUUSD_Scalper/Core/CExecutionEngine.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>
#include <XAUUSD_Scalper/Core/CTrendConfirm.mqh>

// Per-position state for the unified 4-stage exit.
enum ENUM_POSITION_STATE
  {
   POS_STATE_OPEN          = 0,
   POS_STATE_PARTIAL_DONE  = 1,
   POS_STATE_TRAILING      = 2,
   POS_STATE_CLOSED        = 3
  };

struct ManagedPosition
  {
   ulong               ticket;
   ulong               magic;
   string              strat;
   int                 direction;      // +1 long, -1 short
   double              entry_price;
   double              initial_sl;
   double              initial_tp;
   double              current_sl;
   double              volume;
   double              initial_volume;
   datetime            opened_at;
   int                 bars_in_trade;
   int                 adds_done;
   ENUM_POSITION_STATE state;
   bool                active;
   bool                is_head;        // first leg of a pyramiding campaign
  };

// Configuration snapshot for the PositionManager — easier to test than pulling
// inputs straight from the EA.
struct PosMgrConfig
  {
   double partial_r_threshold;   // default 1.0  -> close half at +1.0R
   double partial_close_fraction;// default 0.5  -> close 50 %
   double breakeven_buffer;      // default 0.1  USD
   double trail_atr_mult;        // default 1.0
   int    max_hold_bars;         // default 60
   int    max_adds;              // default 2
   double pyramid_r_threshold;   // default 0.5  -> first add once first leg is +0.5R
   double pyramid_min_distance;  // default 0.2  USD between adds
  };

// Callback interface: the PositionManager calls these when events happen, so
// the EA can feed the TradeLedger without PositionManager knowing about it.
class IPositionCallback
  {
public:
   virtual void OnTradeClosed(const string strat, const double realized_pnl, const datetime when) {}
  };

class CPositionManager
  {
private:
   ManagedPosition   m_pos[];
   int               m_count;
   PosMgrConfig      m_cfg;

   int               FindByTicket(const ulong ticket) const
     {
      for(int i = 0; i < m_count; i++)
         if(m_pos[i].active && m_pos[i].ticket == ticket) return i;
      return -1;
     }

   double            ComputeR(const ManagedPosition &p, const double bid, const double ask) const
     {
      double risk = MathAbs(p.entry_price - p.initial_sl);
      if(risk <= 0.0) return 0.0;
      double current = p.direction > 0 ? bid : ask;
      double move    = (current - p.entry_price) * p.direction;
      return move / risk;
     }

public:
                     CPositionManager() : m_count(0)
     {
      m_cfg.partial_r_threshold    = 1.0;
      m_cfg.partial_close_fraction = 0.5;
      m_cfg.breakeven_buffer       = 0.10;
      m_cfg.trail_atr_mult         = 1.0;
      m_cfg.max_hold_bars          = 60;
      m_cfg.max_adds               = 2;
      m_cfg.pyramid_r_threshold    = 0.5;
      m_cfg.pyramid_min_distance   = 0.2;
     }

   void              Configure(const PosMgrConfig &cfg) { m_cfg = cfg; }
   PosMgrConfig      Config() const { return m_cfg; }

   int               Count() const { return m_count; }

   // Called by OnTradeTransaction when a position is closed by the broker
   // (SL/TP/manual). Without this, broker-closed positions linger in m_pos
   // with active=true and SumOpenRiskCcy keeps adding their risk forever,
   // eventually wedging TOTAL_RISK_CAP for every new entry.
   bool              MarkClosedByTicket(const ulong ticket)
     {
      int idx = FindByTicket(ticket);
      if(idx < 0) return false;
      m_pos[idx].active = false;
      m_pos[idx].state  = POS_STATE_CLOSED;
      return true;
     }

   // Returns the internal index so harnesses / EA can reach back.
   int               OnFill(const ulong ticket, const ulong magic, const string strat,
                            const int direction, const double entry, const double sl,
                            const double tp, const double volume, const datetime when,
                            const bool is_head)
     {
      ArrayResize(m_pos, m_count + 1);
      ManagedPosition p;
      p.ticket         = ticket;
      p.magic          = magic;
      p.strat          = strat;
      p.direction      = direction;
      p.entry_price    = entry;
      p.initial_sl     = sl;
      p.initial_tp     = tp;
      p.current_sl     = sl;
      p.volume         = volume;
      p.initial_volume = volume;
      p.opened_at      = when;
      p.bars_in_trade  = 0;
      p.adds_done      = 0;
      p.state          = POS_STATE_OPEN;
      p.active         = true;
      p.is_head        = is_head;
      m_pos[m_count]   = p;
      m_count++;
      return m_count - 1;
     }

   // Progress the exit state machine. Returns the current state of idx.
   ENUM_POSITION_STATE Step(const int idx, CExecutionEngine &engine,
                            const double bid, const double ask, const double atr,
                            const int new_bars, IPositionCallback *cb = NULL)
     {
      if(idx < 0 || idx >= m_count || !m_pos[idx].active) return POS_STATE_CLOSED;
      ManagedPosition p = m_pos[idx];
      p.bars_in_trade += new_bars;

      // 1) timeout
      if(p.state == POS_STATE_OPEN && p.bars_in_trade > m_cfg.max_hold_bars)
        {
         engine.Close(p.ticket);
         p.state  = POS_STATE_CLOSED;
         p.active = false;
         m_pos[idx] = p;
         if(cb != NULL) cb.OnTradeClosed(p.strat, 0.0, TimeCurrent());
         return POS_STATE_CLOSED;
        }

      const double r = ComputeR(p, bid, ask);

      // 2) partial TP + breakeven
      if(p.state == POS_STATE_OPEN && r >= m_cfg.partial_r_threshold)
        {
         double half = p.volume * m_cfg.partial_close_fraction;
         engine.ClosePartial(p.ticket, half);
         p.volume -= half;

         double be = p.direction > 0
                     ? p.entry_price + m_cfg.breakeven_buffer
                     : p.entry_price - m_cfg.breakeven_buffer;
         p.current_sl = be;
         engine.ModifyStops(p.ticket, be, p.initial_tp);
         p.state = POS_STATE_PARTIAL_DONE;
         m_pos[idx] = p;
         return POS_STATE_PARTIAL_DONE;
        }

      // 3) trailing stop after partial
      if(p.state == POS_STATE_PARTIAL_DONE || p.state == POS_STATE_TRAILING)
        {
         double new_sl;
         if(p.direction > 0)
           {
            new_sl = bid - atr * m_cfg.trail_atr_mult;
            if(new_sl > p.current_sl)
              {
               p.current_sl = new_sl;
               engine.ModifyStops(p.ticket, new_sl, p.initial_tp);
               p.state = POS_STATE_TRAILING;
              }
           }
         else
           {
            new_sl = ask + atr * m_cfg.trail_atr_mult;
            if(new_sl < p.current_sl)
              {
               p.current_sl = new_sl;
               engine.ModifyStops(p.ticket, new_sl, p.initial_tp);
               p.state = POS_STATE_TRAILING;
              }
           }
         m_pos[idx] = p;
         return p.state;
        }

      m_pos[idx] = p;
      return p.state;
     }

   // Returns true if the caller is allowed to pyramid onto the head position.
   bool              AllowPyramid(const int idx, const int candidate_direction,
                                   const double candidate_price, const ENUM_MARKET_STATE state,
                                   const ENUM_TREND_STATE trend, const double bid, const double ask) const
     {
      if(idx < 0 || idx >= m_count) return false;
      if(!m_pos[idx].active) return false;
      ManagedPosition p = m_pos[idx];
      if(!p.is_head) return false;
      if(p.direction != candidate_direction) return false;
      if(p.adds_done >= m_cfg.max_adds) return false;

      const double r = ComputeR(p, bid, ask);
      if(r < m_cfg.pyramid_r_threshold) return false;

      if(state == MARKET_ABNORMAL) return false;

      // Trend must still support this direction.
      if(candidate_direction > 0 && trend == TREND_BEARISH) return false;
      if(candidate_direction < 0 && trend == TREND_BULLISH) return false;

      // Minimum distance from the head entry (or most recent add — head only
      // for now; richer tracking can land in P4 if needed).
      if(MathAbs(candidate_price - p.entry_price) < m_cfg.pyramid_min_distance) return false;

      return true;
     }

   void              OnPyramidAdded(const int head_idx)
     {
      if(head_idx < 0 || head_idx >= m_count) return;
      m_pos[head_idx].adds_done += 1;
     }

   // Test accessors
   ManagedPosition   At(const int idx) const
     {
      ManagedPosition empty; empty.active = false; empty.ticket = 0;
      if(idx < 0 || idx >= m_count) return empty;
      return m_pos[idx];
     }
  };

#endif // __XAUUSD_SCALPER_POSITION_MANAGER_MQH__
