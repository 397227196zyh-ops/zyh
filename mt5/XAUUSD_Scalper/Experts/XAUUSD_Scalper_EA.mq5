#property strict
#property description "XAUUSD Scalper Phase 1 - P4 persistence + dashboard + report"

#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Data/CTradeLedger.mqh>
#include <XAUUSD_Scalper/Data/CDecisionSnapshot.mqh>
#include <XAUUSD_Scalper/Data/CExecutionQuality.mqh>
#include <XAUUSD_Scalper/Data/CTradeHistory.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>
#include <XAUUSD_Scalper/Core/CMarketContext.mqh>
#include <XAUUSD_Scalper/Core/CSessionFilter.mqh>
#include <XAUUSD_Scalper/Core/CExecutionGuard.mqh>
#include <XAUUSD_Scalper/Core/CTrendConfirm.mqh>
#include <XAUUSD_Scalper/Core/CRiskManager.mqh>
#include <XAUUSD_Scalper/Core/CExecutionEngine.mqh>
#include <XAUUSD_Scalper/Core/CPositionManager.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBollinger.mqh>
#include <XAUUSD_Scalper/Core/CStrategyRSI.mqh>
#include <XAUUSD_Scalper/Analysis/CLogger.mqh>
#include <XAUUSD_Scalper/Analysis/CPerformanceTracker.mqh>
#include <XAUUSD_Scalper/Analysis/CReportGenerator.mqh>
#include <XAUUSD_Scalper/UI/CVisualizer.mqh>

input bool   InpEnableEMA        = true;
input bool   InpEnableBoll       = true;
input bool   InpEnableRSI        = true;
input int    InpTickBuffer       = 10000;

// A/B toggles
input bool   InpEnableGuard         = true;
input bool   InpEnableTrendConfirm  = true;
input bool   InpEnableUnifiedExit   = true;
// Even when Guard is off as an A/B experiment, abnormal market state usually
// still has to block new entries — that's a hard safety, not just a gate.
// Set to false only if you really want to ignore MARKET_ABNORMAL too.
input bool   InpRespectAbnormal     = true;

// Sessions / guard. Hours are UTC; broker GMT offset is auto-detected.
input int    InpLonStartHour     = 7;   // UTC
input int    InpLonEndHour       = 16;  // UTC
input int    InpNYStartHour      = 12;  // UTC (NY pre-open)
input int    InpNYEndHour        = 21;  // UTC
input double InpMaxSpread        = 0.08;
input double InpMaxStopLevel     = 0.1;
input int    InpCoolOffSec       = 60;
input double InpDailyLossLimit   = 2.0;
input int    InpConsecLossLimit  = 5;
input double InpTrendFarThresh   = 1.0;

// Risk
input double InpBaseRiskPct      = 0.5;
input double InpTotalRiskCapPct  = 5.0;
input double InpMaxLot           = 2.0;
input double InpKellyMultiplier  = 0.5;   // 0.5 = half-kelly; 1.0 = full kelly
input bool   InpAllowMinLotFallback = false; // if true, BELOW_MIN_LOT promotes to min_lot
// Broker SL/TP minimum distance (USD price units). 0 = auto-read from
// SYMBOL_TRADE_STOPS_LEVEL on init. Some XAUUSD brokers require ≥ 1.0 USD.
input double InpMinStopLevel     = 0.0;
// Per-lot commission charged by broker (account currency). Subtracted from
// kelly base risk so position sizing matches realised PnL.
input double InpCommissionPerLot = 3.0;

// Execution
input int    InpMaxRetries       = 3;
input int    InpRetrySleepMs     = 100;
input double InpLimitOffset      = 0.10;
input int    InpLimitTimeoutSec  = 5;

// Strategy thresholds (loosened on 2026-04-28 demo retro)
input double InpEMASlMult        = 1.5;
input double InpEMATpMult        = 1.2;
input double InpEMASlMin         = 0.5;
input double InpEMASlMax         = 2.0;
input double InpBollPullback     = 0.5;
input double InpBollSL           = 1.0;
input double InpBollTP           = 0.8;
input double InpRSILo            = 25.0;
input double InpRSIHi            = 75.0;
input double InpRSIDistEMA50     = 5.0;
input double InpRSISL            = 0.6;
input double InpRSITP            = 0.5;

// Position manager
input double InpPartialRThresh   = 1.0;
input double InpPartialFraction  = 0.5;
input double InpBreakevenBuffer  = 0.10;
input double InpTrailAtrMult     = 1.0;
input int    InpMaxHoldBars      = 60;
input int    InpMaxAdds          = 2;
input double InpPyramidRThresh   = 0.5;
input double InpPyramidMinDist   = 0.20;

// Misc
input bool   InpDryRun           = false;
input int    InpReportIntervalSec = 60;
input ENUM_DASH_LAYOUT InpDashLayout = DASH_COMPACT;
input int    InpAbnormalEnterStreak = 10; // need N consecutive ticks to flag abnormal
input int    InpAbnormalExitStreak  = 5;  // need N consecutive normal ticks to recover

// MarketAnalyzer thresholds (overridable; defaults loosened for XAUUSD demo)
input double InpAbnATRMult       = 2.5;
input double InpAbnMaxSpread     = 0.15;
input double InpAbnMaxJump       = 5.0;   // was 0.5 — single-tick 1-2 USD jumps are routine on XAUUSD demo
input double InpAbnMinTicksPerS  = 0.5;   // was 3.0 — quiet demo books frequently dip below 3
input int    InpJumpWindowSec    = 30;    // CTickCollector MaxJump sliding window length

input double InpTrendingADX      = 25.0;
input double InpBreakoutBBWidth  = 2.0;
input int    InpBreakoutCount    = 2;

CTickCollector     g_tc;
CIndicatorManager  g_im;
CTradeLedger       g_ledger;
CMarketContext     g_mc;
CSessionFilter     g_sf;
CExecutionGuard    g_eg;
CTrendConfirm      g_tcf;
CRiskManager       g_rm;
CExecutionEngine   g_exec;
CPositionManager   g_pm;
CStrategyEMA       g_sema;
CStrategyBollinger g_sboll;
CStrategyRSI       g_srsi;
CLogger            g_log;
CDecisionSnapshot  g_csv_dec;
CExecutionQuality  g_csv_exec;
CTradeHistory      g_csv_trades;
CPerformanceTracker g_pt;
CReportGenerator   g_report;
CVisualizer        g_ui;

datetime g_last_fail_time = 0;
datetime g_last_report    = 0;
datetime g_last_bar_time  = 0;
double   g_min_stop_level_usd = 0.0; // resolved on init from input or SYMBOL_TRADE_STOPS_LEVEL

// Snapshot of the most recent MarketAnalyzer inputs so WriteDecisionRow can
// add max_jump / ticks_per_s / atr_avg diagnostic columns without changing
// every call site signature.
double   g_dbg_max_jump    = 0.0;
double   g_dbg_ticks_per_s = 0.0;
double   g_dbg_atr_avg     = 0.0;

int      g_abnormal_streak = 0;
int      g_normal_streak   = 0;
bool     g_abnormal_active = false;

int OnInit()
{
   g_tc.Init(InpTickBuffer);
   g_tc.SetJumpWindowSeconds(InpJumpWindowSec);
   if(!g_im.Init(_Symbol))
     { PrintFormat("indicator manager init failed"); return INIT_FAILED; }
   g_ledger.Init();
   g_mc.Init(50, 20);
   g_sf.Configure(InpLonStartHour, InpLonEndHour, InpNYStartHour, InpNYEndHour);
   g_sf.CalibrateBrokerOffset();
   g_eg.Configure(InpMaxSpread, InpMaxStopLevel, InpCoolOffSec, InpDailyLossLimit, InpConsecLossLimit);
   g_tcf.Configure(InpTrendFarThresh);

   g_exec.SetSymbol(_Symbol);
   g_exec.SetMagic(7010000);
   g_exec.Configure(InpMaxRetries, InpRetrySleepMs, InpLimitOffset, InpLimitTimeoutSec);
   g_exec.SetDryRun(InpDryRun);

   g_sema.Configure(InpEMASlMult, InpEMATpMult, InpEMASlMin, InpEMASlMax);
   g_sboll.Configure(InpBollPullback, InpBollSL, InpBollTP);
   g_srsi.Configure(InpRSILo, InpRSIHi, InpRSIDistEMA50, InpRSISL, InpRSITP);

   PosMgrConfig cfg;
   cfg.partial_r_threshold    = InpPartialRThresh;
   cfg.partial_close_fraction = InpPartialFraction;
   cfg.breakeven_buffer       = InpBreakevenBuffer;
   cfg.trail_atr_mult         = InpTrailAtrMult;
   cfg.max_hold_bars          = InpMaxHoldBars;
   cfg.max_adds               = InpMaxAdds;
   cfg.pyramid_r_threshold    = InpPyramidRThresh;
   cfg.pyramid_min_distance   = InpPyramidMinDist;
   g_pm.Configure(cfg);

   g_log.Init("XAUUSD_Scalper/Logs");
   g_log.SetLevel(LOGX_INFO);
   g_csv_dec.Open   ("XAUUSD_Scalper/decision_snapshots.csv");
   g_csv_exec.Open  ("XAUUSD_Scalper/execution_quality.csv");
   g_csv_trades.Open("XAUUSD_Scalper/trade_history.csv");
   g_ui.Init(InpDashLayout);

   g_last_report = TimeCurrent();
   EventSetTimer(InpReportIntervalSec);

   if(InpMinStopLevel > 0.0)
      g_min_stop_level_usd = InpMinStopLevel;
   else
     {
      long stops_pts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double point   = SymbolInfoDouble (_Symbol, SYMBOL_POINT);
      g_min_stop_level_usd = (double)stops_pts * point;
     }

   g_log.Info("main", StringFormat(
     "Init OK enableEMA=%d enableBoll=%d enableRSI=%d enableGuard=%d enableTrend=%d enableExit=%d min_stop_usd=%.5f",
      InpEnableEMA, InpEnableBoll, InpEnableRSI,
      InpEnableGuard, InpEnableTrendConfirm, InpEnableUnifiedExit, g_min_stop_level_usd));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   g_im.Shutdown();
   g_csv_dec.Close();
   g_csv_exec.Close();
   g_csv_trades.Close();
   g_log.Info("main", StringFormat("deinit reason=%d", reason));
   g_log.Shutdown();
   g_ui.Clear();
}

// ------------ helpers --------------------------------------------------

void WriteDecisionRow(const string strat, const int dir, const bool session_open,
                      const int guard_reason, const int trend_state,
                      const bool allowed, const string reason,
                      const double spread, const double atr, const double adx,
                      const double sl_distance, const double planned_lot,
                      const bool is_pyramid)
{
   DecisionRow r;
   r.time = TimeCurrent(); r.strat = strat; r.dir = dir;
   r.session_open = session_open; r.guard_reason = guard_reason;
   r.trend_state = trend_state; r.allowed = allowed; r.reason = reason;
   r.spread = spread; r.atr = atr; r.adx = adx;
   r.sl_distance = sl_distance; r.planned_lot = planned_lot;
   r.is_pyramid = is_pyramid;
   r.max_jump    = g_dbg_max_jump;
   r.ticks_per_s = g_dbg_ticks_per_s;
   r.atr_avg     = g_dbg_atr_avg;
   g_csv_dec.Write(r);
}

void LogGate(const string strat, const ENUM_SIGNAL_DIRECTION dir,
             const bool session_open, const GuardDecision &gd,
             const ENUM_TREND_STATE ts, const bool allowed, const string reason)
{
   g_log.Info("gate",
      StringFormat("strat=%s dir=%d session=%d guard=%d trend=%d allowed=%d reason=%s",
                   strat, (int)dir, session_open ? 1 : 0,
                   (int)gd.reason, (int)ts, allowed ? 1 : 0, reason));
}

double SlPerLotCcy(const double sl_distance)
{
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0) return 0.0;
   return sl_distance / tick_size * tick_value;
}

double SumOpenRiskCcy()
{
   double total = 0.0;
   for(int i = 0; i < g_pm.Count(); i++)
     {
      ManagedPosition p = g_pm.At(i);
      if(!p.active) continue;
      double dist = MathAbs(p.entry_price - p.current_sl);
      total += p.volume * SlPerLotCcy(dist);
     }
   return total;
}

void MaybePlaceOrder(const string name, CStrategyBase &s, const StrategyContext &ctx,
                     const SignalResult &sr, const ENUM_MARKET_STATE state,
                     const double bid, const double ask, const ulong magic,
                     const double spread, const double atr, const double adx)
{
   double sl_distance = MathAbs(ctx.bid - sr.stop_loss);
   if(sl_distance <= 0.0)
     {
      WriteDecisionRow(name, sr.direction, true, 0, 0, false, "ZERO_SL",
                       spread, atr, adx, 0.0, 0.0, false);
      return;
     }

   // Push SL and TP out to the broker's minimum stop distance independently;
   // otherwise OrderSend is rejected with INVALID_STOPS. BOLL has TP=0.8 USD
   // by default, which is below Doo Prime's 1.0 USD stops level even when
   // its SL=1.0 USD already meets the bar.
   double sr_sl = sr.stop_loss;
   double sr_tp = sr.take_profit;
   if(g_min_stop_level_usd > 0.0)
     {
      if(sr.direction == SIGNAL_BUY)
        {
         if(sl_distance < g_min_stop_level_usd)
           {
            sl_distance = g_min_stop_level_usd;
            sr_sl = ctx.bid - sl_distance;
           }
         if(sr_tp > 0 && sr_tp - ctx.bid < g_min_stop_level_usd)
            sr_tp = ctx.bid + g_min_stop_level_usd;
        }
      else
        {
         if(sl_distance < g_min_stop_level_usd)
           {
            sl_distance = g_min_stop_level_usd;
            sr_sl = ctx.ask + sl_distance;
           }
         if(sr_tp > 0 && ctx.ask - sr_tp < g_min_stop_level_usd)
            sr_tp = ctx.ask - g_min_stop_level_usd;
        }
     }

   double per_lot = SlPerLotCcy(sl_distance);
   if(per_lot <= 0.0)
     {
      WriteDecisionRow(name, sr.direction, true, 0, 0, false, "NO_TICK_VALUE",
                       spread, atr, adx, sl_distance, 0.0, false);
      return;
     }

   RiskInputs ri;
   ri.account_equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   ri.base_risk_pct      = InpBaseRiskPct;
   ri.total_risk_cap_pct = InpTotalRiskCapPct;
   ri.sl_distance        = sl_distance;
   ri.sl_per_lot_ccy     = per_lot;
   double cold_p = 0.55, cold_b = 1.2;
   if(name == "BOLL")     { cold_p = 0.48; cold_b = 1.5; }
   else if(name == "RSI") { cold_p = 0.60; cold_b = 0.9; }
   ri.kelly_fraction = InpKellyMultiplier * s.CalculateKellyFraction(30, cold_p, cold_b);
   ri.open_risk_ccy  = SumOpenRiskCcy();
   ri.min_lot        = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   ri.max_lot        = MathMin(InpMaxLot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   ri.lot_step       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   ri.commission_per_lot = InpCommissionPerLot;
   ri.allow_min_lot_fallback = InpAllowMinLotFallback;

   RiskDecision rd = g_rm.Size(ri);
   if(!rd.allowed)
     {
      g_log.Info("main", StringFormat("risk reject strat=%s reason=%s", name, rd.reason));
      WriteDecisionRow(name, sr.direction, true, 0, 0, false, rd.reason,
                       spread, atr, adx, sl_distance, 0.0, false);
      g_pt.RecordReject();
      return;
     }

   const int dir = (sr.direction == SIGNAL_BUY) ? +1 : -1;
   ExecutionResult er;
   uint t_start = GetTickCount();

   bool is_limit = (state == MARKET_RANGING);
   if(is_limit)
     {
      // Clamp limit offset above broker stops_level; otherwise BUY/SELL LIMIT
      // returns retcode 10015 and the failure pins guard cooldown for 60 s.
      double safe_offset = MathMax(InpLimitOffset, g_min_stop_level_usd + 0.05);
      double price = dir > 0 ? ask - safe_offset : bid + safe_offset;
      g_exec.SetMagic(magic);
      er = g_exec.PlaceLimit(dir, rd.lot, price, sr_sl, sr_tp);
     }
   else
     {
      g_exec.SetMagic(magic);
      er = g_exec.PlaceMarket(dir, rd.lot, sr_sl, sr_tp,
                               dir > 0 ? ask : bid);
     }
   int latency_ms = (int)(GetTickCount() - t_start);

   WriteDecisionRow(name, sr.direction, true, 0, 0, er.filled, er.reason_str,
                    spread, atr, adx, sl_distance, rd.lot, false);

   if(er.filled)
     {
      g_log.Info("order", StringFormat(
         "strat=%s dir=%d lot=%.2f entry=%.5f sl=%.5f tp=%.5f slip=%.5f ticket=%I64u",
         name, dir, rd.lot, er.filled_price, sr_sl, sr_tp,
         er.slippage, er.ticket));

      ExecQualityRow eqr;
      eqr.time = TimeCurrent(); eqr.strat = name; eqr.side = dir;
      eqr.requested_price = dir > 0 ? ask : bid; eqr.fill_price = er.filled_price;
      eqr.slippage = er.slippage; eqr.retries = 0;
      eqr.latency_ms = latency_ms; eqr.order_type = is_limit ? "limit" : "market";
      g_csv_exec.Write(eqr);

      g_pm.OnFill(er.ticket, magic, name, dir, er.filled_price, sr_sl,
                  sr_tp, rd.lot, TimeCurrent(), /*is_head*/true);
      g_pt.RecordFill(er.slippage, latency_ms, is_limit);
      g_pt.RecordFilled();
      g_ui.OnOrderFilled(TimeCurrent(), er.filled_price, dir);
     }
   else
     {
      g_log.Warn("order", StringFormat(
         "strat=%s reason=%s retcode=%d dir=%d lot=%.2f bid=%.5f ask=%.5f sl=%.5f tp=%.5f sl_dist=%.5f min_stop=%.5f",
         name, er.reason_str, er.retcode, dir, rd.lot, bid, ask,
         sr_sl, sr_tp, sl_distance, g_min_stop_level_usd));
      g_ledger.OnTradeFailed(TimeCurrent());
      g_last_fail_time = TimeCurrent();
      g_pt.RecordReject();
     }
}

void EvalStrategy(const string name, CStrategyBase &s, const StrategyContext &ctx,
                  const bool session_open, const GuardDecision &gd, const ENUM_TREND_STATE ts,
                  const double ema20_m5, const ENUM_MARKET_STATE state,
                  const double bid, const double ask, const ulong magic,
                  const double spread, const double atr, const double adx)
{
   SignalResult r = s.CheckSignal(ctx);
   g_pt.RecordCandidate();

   if(!session_open)
     {
      // Avoid blowing up the snapshot CSV with one row per tick per strategy
      // for the 16+ hours we're outside London / NY. Out-of-session
      // rejections are still counted in PerformanceTracker and visible in
      // the main log if log level is DEBUG.
      g_pt.RecordRejectSession();
      g_log.Debug("gate", StringFormat("strat=%s SESSION", name));
      return;
     }

   if(InpEnableGuard && !gd.allowed)
     {
      LogGate(name, r.direction, session_open, gd, ts, false, EnumToString(gd.reason));
      if(gd.reason == GUARD_ABNORMAL_MARKET) g_pt.RecordRejectAbnormal();
      else g_pt.RecordRejectGuard();
      WriteDecisionRow(name, r.direction, session_open, (int)gd.reason, (int)ts,
                       false, EnumToString(gd.reason), spread, atr, adx, 0.0, 0.0, false);
      return;
     }

   // Hard safety: even if Guard is off as an A/B experiment, abnormal market
   // state still blocks new entries unless InpRespectAbnormal is explicitly
   // disabled.
   if(!InpEnableGuard && InpRespectAbnormal && state == MARKET_ABNORMAL)
     {
      LogGate(name, r.direction, session_open, gd, ts, false, "ABNORMAL_HARD_SAFETY");
      g_pt.RecordRejectAbnormal();
      WriteDecisionRow(name, r.direction, session_open, (int)gd.reason, (int)ts,
                       false, "ABNORMAL_HARD_SAFETY", spread, atr, adx, 0.0, 0.0, false);
      return;
     }

   if(r.direction == SIGNAL_NONE)
     {
      LogGate(name, r.direction, session_open, gd, ts, false, "NO_SIGNAL");
      WriteDecisionRow(name, r.direction, session_open, (int)gd.reason, (int)ts,
                       false, "NO_SIGNAL", spread, atr, adx, 0.0, 0.0, false);
      return;
     }

   if(InpEnableTrendConfirm && !g_tcf.Allows(name, r.direction, ts, ctx.bid, ema20_m5))
     {
      LogGate(name, r.direction, session_open, gd, ts, false, "TREND");
      g_pt.RecordRejectTrend();
      WriteDecisionRow(name, r.direction, session_open, (int)gd.reason, (int)ts,
                       false, "TREND", spread, atr, adx, 0.0, 0.0, false);
      return;
     }

   LogGate(name, r.direction, session_open, gd, ts, true,
           InpEnableGuard ? (InpEnableTrendConfirm ? "PASS" : "PASS_TREND_BYPASS")
                          : "PASS_GUARD_BYPASS");

   MaybePlaceOrder(name, s, ctx, r, state, bid, ask, magic, spread, atr, adx);
}

void UpdatePositions(const double bid, const double ask, const double atr, const int bars_delta)
{
   if(!InpEnableUnifiedExit) return;
   for(int i = 0; i < g_pm.Count(); i++)
     {
      ManagedPosition p = g_pm.At(i);
      if(!p.active) continue;
      ENUM_POSITION_STATE before = p.state;
      ENUM_POSITION_STATE after  = g_pm.Step(i, g_exec, bid, ask, atr, bars_delta);
      if(before != after && after == POS_STATE_PARTIAL_DONE) g_pt.RecordPartial();
     }
}

void OnTick()
{
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   g_tc.OnTick(t);
   g_im.Update();

   double atr = g_im.ATR(0);
   // Sample ATR only on new M1 bars; that keeps ATRAverage on the same
   // sampling cadence as ATR itself so atr_avg matches the live atr scale.
   datetime bar_time = (datetime)SeriesInfoInteger(_Symbol, PERIOD_M1, SERIES_LASTBAR_DATE);
   if(bar_time != g_last_bar_time)
     {
      g_mc.PushATRSample(atr);
      g_last_bar_time = bar_time;
     }

   double adx    = g_im.ADX(0);
   double spread = g_tc.LastSpread();

   MarketInputs mi = g_mc.BuildInputs(adx, atr, g_im.BBWidth(0),
                                      spread, g_tc.MaxJump(),
                                      g_tc.TicksPerSecondEstimate());
   g_dbg_max_jump    = mi.max_jump;
   g_dbg_ticks_per_s = mi.ticks_per_s;
   g_dbg_atr_avg     = mi.atr_avg;

   MarketThresholds mt;
   mt.atr_blowup_mult   = InpAbnATRMult;
   mt.max_spread        = InpAbnMaxSpread;
   mt.max_jump          = InpAbnMaxJump;
   mt.min_ticks_per_s   = InpAbnMinTicksPerS;
   mt.trending_adx      = InpTrendingADX;
   mt.breakout_bb_width = InpBreakoutBBWidth;
   mt.breakout_count    = InpBreakoutCount;
   ENUM_MARKET_STATE raw_state = CMarketAnalyzer::ClassifyWith(mi, mt);

   // Hysteresis: only flag MARKET_ABNORMAL after a streak of abnormal ticks,
   // and only release after a streak of normal ticks. Quiet demo books
   // routinely produce a single abnormal tick (slow ticks, large bid jump
   // on the first tick of a session) that would otherwise wedge the EA into
   // ABNORMAL for the rest of the day.
   if(raw_state == MARKET_ABNORMAL)
     {
      g_abnormal_streak++;
      g_normal_streak = 0;
      if(g_abnormal_streak >= InpAbnormalEnterStreak) g_abnormal_active = true;
     }
   else
     {
      g_normal_streak++;
      g_abnormal_streak = 0;
      if(g_normal_streak >= InpAbnormalExitStreak) g_abnormal_active = false;
     }
   ENUM_MARKET_STATE state = g_abnormal_active ? MARKET_ABNORMAL : raw_state;

   const bool session_open = g_sf.IsOpen(t.time);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   GuardInputs gin;
   gin.session_open   = session_open;
   gin.spread         = spread;
   gin.stops_level    = 0.0;
   gin.freeze_level   = 0.0;
   gin.market_state   = state;
   gin.now            = t.time;
   gin.last_fail_time = g_last_fail_time;
   gin.daily_loss_pct = g_ledger.DailyLossPct(equity);
   gin.consec_losses  = g_ledger.ConsecLosses("EMA")
                       + g_ledger.ConsecLosses("BOLL")
                       + g_ledger.ConsecLosses("RSI");
   GuardDecision gd = g_eg.Evaluate(gin);

   const ENUM_TREND_STATE ts = g_tcf.Classify(g_im, t.bid);

   StrategyContext ctx; ctx.im = &g_im; ctx.tc = &g_tc; ctx.state = state;
   ctx.bid = t.bid; ctx.ask = t.ask; ctx.time = t.time;

   if(InpEnableEMA)  EvalStrategy("EMA",  g_sema,  ctx, session_open, gd, ts, g_im.EMA20_M5(0), state, t.bid, t.ask, 7010001, spread, atr, adx);
   if(InpEnableBoll) EvalStrategy("BOLL", g_sboll, ctx, session_open, gd, ts, g_im.EMA20_M5(0), state, t.bid, t.ask, 7010002, spread, atr, adx);
   if(InpEnableRSI)  EvalStrategy("RSI",  g_srsi,  ctx, session_open, gd, ts, g_im.EMA20_M5(0), state, t.bid, t.ask, 7010003, spread, atr, adx);

   UpdatePositions(t.bid, t.ask, atr, /*bars_delta*/0);

   DashSnapshot ds;
   ds.equity       = equity;
   ds.floating_pnl = AccountInfoDouble(ACCOUNT_PROFIT);
   ds.open_positions = PositionsTotal();
   ds.spread       = spread;
   ds.atr          = atr;
   ds.adx          = adx;
   ds.market_state = (int)state;
   ds.trend_state  = (int)ts;
   ds.session_open = session_open;
   ds.guard_reason = (int)gd.reason;
   ds.liquidity_score = 100.0;
   ds.ticks_per_sec   = g_tc.TicksPerSecondEstimate();
   g_ui.RenderDashboard(ds, g_pt);
}

// Hook deal closures into the ledger / performance tracker / trade history.
void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;

   double pnl        = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   double swap       = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   double exit_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double volume     = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   datetime when     = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   long deal_type    = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   long magic        = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   ulong position_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

   string strat = "UNK";
   if(magic == 7010001) strat = "EMA";
   else if(magic == 7010002) strat = "BOLL";
   else if(magic == 7010003) strat = "RSI";

   // The closing deal is the opposite side of the original position. So a
   // closing SELL deal means the position was a LONG (+1), and a closing
   // BUY deal means the position was a SHORT (-1).
   int row_dir = (deal_type == DEAL_TYPE_SELL) ? +1 : -1;

   // Walk all deals on this position to find the original entry deal so the
   // CSV captures the real entry price + open time, not zeros.
   double entry_price = 0.0;
   datetime open_time = when;
   if(position_id != 0 && HistorySelectByPosition(position_id))
     {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN)
           {
            entry_price = HistoryDealGetDouble(d, DEAL_PRICE);
            open_time   = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
            break;
           }
        }
     }

   TradeRow row;
   row.open_time = open_time; row.close_time = when;
   row.strat = strat; row.dir = row_dir;
   row.entry = entry_price; row.exit = exit_price; row.lots = volume;
   row.pnl = pnl; row.commission = commission; row.swap = swap;
   row.market_state_on_open = 0; row.liquidity_score_on_open = 0.0;
   row.slippage = 0.0; row.exec_ms = 0; row.was_limit = false;
   g_csv_trades.Write(row);

   g_ledger.OnTradeClosed(strat, pnl + commission + swap, when);
   g_pt.RecordTradeClosed(pnl + commission + swap);
   g_ui.OnOrderClosed(when, exit_price, pnl);
}

void RebuildReport()
{
   EquityPoint eq[]; ArrayResize(eq, 1);
   eq[0].time   = TimeCurrent();
   eq[0].equity = AccountInfoDouble(ACCOUNT_EQUITY);

   TradeReportRow trades[]; // empty snapshot; real data is in trade_history.csv
   GuardBar guard[]; ArrayResize(guard, 4);
   SignalQualityStats sq = g_pt.SignalQuality();
   guard[0].reason = "SESSION";  guard[0].count = sq.rejected_session;
   guard[1].reason = "GUARD";    guard[1].count = sq.rejected_guard;
   guard[2].reason = "ABNORMAL"; guard[2].count = sq.rejected_abnormal;
   guard[3].reason = "TREND";    guard[3].count = sq.rejected_trend;

   string html = g_report.BuildHTML(g_pt, eq, trades, guard);
   MqlDateTime d; TimeToStruct(TimeCurrent(), d);
   string path = StringFormat("XAUUSD_Scalper/Reports/report-%04d%02d%02d.html",
                              d.year, d.mon, d.day);
   g_report.Write(path, html);
}

void OnTimer()
{
   datetime now = TimeCurrent();
   if(now - g_last_report >= InpReportIntervalSec)
     {
      RebuildReport();
      g_last_report = now;
     }
}
