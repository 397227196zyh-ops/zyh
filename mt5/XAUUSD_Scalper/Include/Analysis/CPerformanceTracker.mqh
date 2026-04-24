#ifndef __XAUUSD_SCALPER_PERFORMANCE_TRACKER_MQH__
#define __XAUUSD_SCALPER_PERFORMANCE_TRACKER_MQH__

// Aggregates 5 indicator groups: returns, signal quality, execution quality,
// position management, pyramiding. Pure in-memory; producers feed events via
// the Record* methods and readers pull snapshots via Snapshot().

struct ReturnsStats
  {
   int    total_trades;
   int    wins;
   int    losses;
   double net_pnl;
   double gross_win;
   double gross_loss;
   double max_win;
   double max_loss;
  };

struct SignalQualityStats
  {
   int candidates;
   int rejected_session;
   int rejected_guard;
   int rejected_abnormal;
   int rejected_trend;
   int filled;
  };

struct ExecutionQualityStats
  {
   int    fills;
   int    rejects;
   int    limit_fills;
   int    limit_timeouts;
   double slippage_sum;
   double latency_sum_ms;
  };

struct PositionMgmtStats
  {
   int partial_triggered;
   int beaten_after_be;
   int trail_exits;
   int timeout_exits;
   double trail_pnl_sum;
   double timeout_pnl_sum;
  };

struct PyramidingStats
  {
   int    adds_done;
   int    adds_rejected_by_risk;
   double pyramid_pnl_sum;
   double pyramid_max_drawdown;
  };

class CPerformanceTracker
  {
private:
   ReturnsStats          m_r;
   SignalQualityStats    m_sq;
   ExecutionQualityStats m_eq;
   PositionMgmtStats     m_pm;
   PyramidingStats       m_py;

public:
                     CPerformanceTracker() { Reset(); }

   void              Reset()
     {
      m_r.total_trades = 0; m_r.wins = 0; m_r.losses = 0;
      m_r.net_pnl = 0; m_r.gross_win = 0; m_r.gross_loss = 0;
      m_r.max_win = 0; m_r.max_loss = 0;

      m_sq.candidates = 0; m_sq.rejected_session = 0; m_sq.rejected_guard = 0;
      m_sq.rejected_abnormal = 0; m_sq.rejected_trend = 0; m_sq.filled = 0;

      m_eq.fills = 0; m_eq.rejects = 0; m_eq.limit_fills = 0; m_eq.limit_timeouts = 0;
      m_eq.slippage_sum = 0; m_eq.latency_sum_ms = 0;

      m_pm.partial_triggered = 0; m_pm.beaten_after_be = 0;
      m_pm.trail_exits = 0; m_pm.timeout_exits = 0;
      m_pm.trail_pnl_sum = 0; m_pm.timeout_pnl_sum = 0;

      m_py.adds_done = 0; m_py.adds_rejected_by_risk = 0;
      m_py.pyramid_pnl_sum = 0; m_py.pyramid_max_drawdown = 0;
     }

   // --- Returns --------------------------------------------------------
   void              RecordTradeClosed(const double pnl)
     {
      m_r.total_trades++;
      m_r.net_pnl += pnl;
      if(pnl > 0)
        {
         m_r.wins++; m_r.gross_win += pnl;
         if(pnl > m_r.max_win) m_r.max_win = pnl;
        }
      else
        {
         m_r.losses++; m_r.gross_loss += -pnl;
         if(-pnl > m_r.max_loss) m_r.max_loss = -pnl;
        }
     }

   ReturnsStats      Returns() const { return m_r; }

   double            WinRate() const
     {
      return m_r.total_trades > 0 ? (double)m_r.wins / (double)m_r.total_trades : 0.0;
     }

   double            PayoffRatio() const
     {
      double avg_w = m_r.wins   > 0 ? m_r.gross_win  / (double)m_r.wins   : 0.0;
      double avg_l = m_r.losses > 0 ? m_r.gross_loss / (double)m_r.losses : 0.0;
      return avg_l > 0 ? avg_w / avg_l : 0.0;
     }

   // --- Signal quality -------------------------------------------------
   void              RecordCandidate()       { m_sq.candidates++; }
   void              RecordRejectSession()   { m_sq.rejected_session++; }
   void              RecordRejectGuard()     { m_sq.rejected_guard++; }
   void              RecordRejectAbnormal()  { m_sq.rejected_abnormal++; }
   void              RecordRejectTrend()     { m_sq.rejected_trend++; }
   void              RecordFilled()          { m_sq.filled++; }
   SignalQualityStats SignalQuality() const  { return m_sq; }

   // --- Execution quality ----------------------------------------------
   void              RecordFill(const double slippage, const int latency_ms, const bool was_limit)
     {
      m_eq.fills++;
      m_eq.slippage_sum   += slippage;
      m_eq.latency_sum_ms += latency_ms;
      if(was_limit) m_eq.limit_fills++;
     }
   void              RecordReject()          { m_eq.rejects++; }
   void              RecordLimitTimeout()    { m_eq.limit_timeouts++; }
   ExecutionQualityStats ExecutionQuality() const { return m_eq; }

   double            AvgSlippage() const
     {
      return m_eq.fills > 0 ? m_eq.slippage_sum / m_eq.fills : 0.0;
     }

   double            RejectRate() const
     {
      int total = m_eq.fills + m_eq.rejects;
      return total > 0 ? (double)m_eq.rejects / (double)total : 0.0;
     }

   // --- Position management --------------------------------------------
   void              RecordPartial()         { m_pm.partial_triggered++; }
   void              RecordBeatenAfterBE()   { m_pm.beaten_after_be++; }
   void              RecordTrailExit(const double pnl)
     {
      m_pm.trail_exits++; m_pm.trail_pnl_sum += pnl;
     }
   void              RecordTimeoutExit(const double pnl)
     {
      m_pm.timeout_exits++; m_pm.timeout_pnl_sum += pnl;
     }
   PositionMgmtStats PositionManagement() const { return m_pm; }

   // --- Pyramiding -----------------------------------------------------
   void              RecordAdd(const double pnl_contrib)
     {
      m_py.adds_done++; m_py.pyramid_pnl_sum += pnl_contrib;
     }
   void              RecordAddRejected()     { m_py.adds_rejected_by_risk++; }
   void              RecordPyramidDrawdown(const double dd)
     {
      if(dd > m_py.pyramid_max_drawdown) m_py.pyramid_max_drawdown = dd;
     }
   PyramidingStats   Pyramiding() const { return m_py; }
  };

#endif // __XAUUSD_SCALPER_PERFORMANCE_TRACKER_MQH__
