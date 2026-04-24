#property strict
#property description "XAUUSD Scalper Phase 1 - P3 live trading"

#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Data/CTradeLedger.mqh>
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
#include <XAUUSD_Scalper/Analysis/CLoggerStub.mqh>

input bool   InpEnableEMA        = true;
input bool   InpEnableBoll       = true;
input bool   InpEnableRSI        = true;
input int    InpTickBuffer       = 10000;

// Sessions / guard
input int    InpLonStartHour     = 7;
input int    InpLonEndHour       = 16;
input int    InpNYStartHour      = 13;
input int    InpNYEndHour        = 22;
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

// Execution
input int    InpMaxRetries       = 3;
input int    InpRetrySleepMs     = 100;
input double InpLimitOffset      = 0.10;
input int    InpLimitTimeoutSec  = 5;

// Position manager
input double InpPartialRThresh   = 1.0;
input double InpPartialFraction  = 0.5;
input double InpBreakevenBuffer  = 0.10;
input double InpTrailAtrMult     = 1.0;
input int    InpMaxHoldBars      = 60;
input int    InpMaxAdds          = 2;
input double InpPyramidRThresh   = 0.5;
input double InpPyramidMinDist   = 0.20;

// Dry-run switch for broker-free smoke tests.
input bool   InpDryRun           = false;

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
CLoggerStub        g_log;

datetime g_last_fail_time = 0;
datetime g_last_day       = 0;

int OnInit()
{
   g_tc.Init(InpTickBuffer);
   if(!g_im.Init(_Symbol))
     { g_log.Error("init", "indicator manager init failed"); return INIT_FAILED; }
   g_ledger.Init();
   g_mc.Init(50, 20);
   g_sf.Configure(InpLonStartHour, InpLonEndHour, InpNYStartHour, InpNYEndHour);
   g_eg.Configure(InpMaxSpread, InpMaxStopLevel, InpCoolOffSec, InpDailyLossLimit, InpConsecLossLimit);
   g_tcf.Configure(InpTrendFarThresh);

   g_exec.SetSymbol(_Symbol);
   g_exec.SetMagic(7010000);
   g_exec.Configure(InpMaxRetries, InpRetrySleepMs, InpLimitOffset, InpLimitTimeoutSec);
   g_exec.SetDryRun(InpDryRun);

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

   g_log.Info("init", "Init OK");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_im.Shutdown();
   g_log.Info("deinit", StringFormat("reason=%d", reason));
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

// Returns account-currency loss for 1 lot at the given SL distance.
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
      double per_lot = SlPerLotCcy(dist);
      total += p.volume * per_lot;
     }
   return total;
}

void MaybePlaceOrder(const string name, CStrategyBase &s, const StrategyContext &ctx,
                     const SignalResult &sr, const ENUM_MARKET_STATE state,
                     const double bid, const double ask, const ulong magic)
{
   double sl_distance = MathAbs(ctx.bid - sr.stop_loss);
   if(sl_distance <= 0.0) { g_log.Warn("order", "zero SL distance, abort"); return; }

   double per_lot = SlPerLotCcy(sl_distance);
   if(per_lot <= 0.0) { g_log.Warn("order", "cannot compute SL cost per lot"); return; }

   RiskInputs ri;
   ri.account_equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   ri.base_risk_pct      = InpBaseRiskPct;
   ri.total_risk_cap_pct = InpTotalRiskCapPct;
   ri.sl_distance        = sl_distance;
   ri.sl_per_lot_ccy     = per_lot;
   // Use existing base-class Kelly with phase-1 cold-start defaults.
   // EMA: p=0.55/b=1.2, BOLL: p=0.48/b=1.5, RSI: p=0.60/b=0.9
   double cold_p = 0.55, cold_b = 1.2;
   if(name == "BOLL") { cold_p = 0.48; cold_b = 1.5; }
   else if(name == "RSI") { cold_p = 0.60; cold_b = 0.9; }
   ri.kelly_fraction = 0.5 * s.CalculateKellyFraction(30, cold_p, cold_b);
   ri.open_risk_ccy  = SumOpenRiskCcy();
   ri.min_lot        = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   ri.max_lot        = MathMin(InpMaxLot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   ri.lot_step       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   RiskDecision rd = g_rm.Size(ri);
   if(!rd.allowed)
     {
      g_log.Info("risk", StringFormat("strat=%s reason=%s", name, rd.reason));
      return;
     }

   const int dir = (sr.direction == SIGNAL_BUY) ? +1 : -1;

   ExecutionResult er;
   if(state == MARKET_RANGING)
     {
      double price = dir > 0 ? ask - InpLimitOffset : bid + InpLimitOffset;
      g_exec.SetMagic(magic);
      er = g_exec.PlaceLimit(dir, rd.lot, price, sr.stop_loss, sr.take_profit);
     }
   else
     {
      g_exec.SetMagic(magic);
      er = g_exec.PlaceMarket(dir, rd.lot, sr.stop_loss, sr.take_profit,
                               dir > 0 ? ask : bid);
     }

   if(er.filled)
     {
      g_log.Info("order",
         StringFormat("strat=%s dir=%d lot=%.2f entry=%.5f sl=%.5f tp=%.5f slip=%.5f ticket=%I64u",
                      name, dir, rd.lot, er.filled_price, sr.stop_loss, sr.take_profit,
                      er.slippage, er.ticket));
      g_pm.OnFill(er.ticket, magic, name, dir, er.filled_price, sr.stop_loss,
                  sr.take_profit, rd.lot, TimeCurrent(), /*is_head*/true);
     }
   else
     {
      g_log.Warn("order",
         StringFormat("strat=%s reason=%s retcode=%d", name, er.reason_str, er.retcode));
      g_ledger.OnTradeFailed(TimeCurrent());
      g_last_fail_time = TimeCurrent();
     }
}

void EvalStrategy(const string name, CStrategyBase &s, const StrategyContext &ctx,
                  const bool session_open, const GuardDecision &gd, const ENUM_TREND_STATE ts,
                  const double ema20_m5, const ENUM_MARKET_STATE state,
                  const double bid, const double ask, const ulong magic)
{
   SignalResult r = s.CheckSignal(ctx);
   if(!session_open)              { LogGate(name, r.direction, session_open, gd, ts, false, "SESSION"); return; }
   if(!gd.allowed)                { LogGate(name, r.direction, session_open, gd, ts, false, EnumToString(gd.reason)); return; }
   if(r.direction == SIGNAL_NONE) { LogGate(name, r.direction, session_open, gd, ts, false, "NO_SIGNAL"); return; }
   if(!g_tcf.Allows(name, r.direction, ts, ctx.bid, ema20_m5))
     { LogGate(name, r.direction, session_open, gd, ts, false, "TREND"); return; }
   LogGate(name, r.direction, session_open, gd, ts, true, "PASS");

   MaybePlaceOrder(name, s, ctx, r, state, bid, ask, magic);
}

void UpdatePositions(const double bid, const double ask, const double atr,
                     const int bars_delta)
{
   for(int i = 0; i < g_pm.Count(); i++)
     {
      ManagedPosition p = g_pm.At(i);
      if(!p.active) continue;
      g_pm.Step(i, g_exec, bid, ask, atr, bars_delta);
     }
}

void OnTick()
{
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   g_tc.OnTick(t);
   g_im.Update();

   g_mc.PushATRSample(g_im.ATR(0));

   MarketInputs mi = g_mc.BuildInputs(g_im.ADX(0), g_im.ATR(0), g_im.BBWidth(0),
                                      g_tc.LastSpread(), g_tc.MaxJump(),
                                      g_tc.TicksPerSecondEstimate());
   ENUM_MARKET_STATE state = CMarketAnalyzer::Classify(mi);

   const bool session_open = g_sf.IsOpen(t.time);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   GuardInputs gin;
   gin.session_open   = session_open;
   gin.spread         = g_tc.LastSpread();
   gin.stops_level    = 0.0;
   gin.freeze_level   = 0.0;
   gin.market_state   = state;
   gin.now            = t.time;
   gin.last_fail_time = g_last_fail_time;
   gin.daily_loss_pct = g_ledger.DailyLossPct(equity);
   gin.consec_losses  = g_ledger.ConsecLosses("EMA") + g_ledger.ConsecLosses("BOLL") + g_ledger.ConsecLosses("RSI");
   GuardDecision gd = g_eg.Evaluate(gin);

   const ENUM_TREND_STATE ts = g_tcf.Classify(g_im, t.bid);

   StrategyContext ctx; ctx.im = &g_im; ctx.tc = &g_tc; ctx.state = state;
   ctx.bid = t.bid; ctx.ask = t.ask; ctx.time = t.time;

   if(InpEnableEMA)  EvalStrategy("EMA",  g_sema,  ctx, session_open, gd, ts, g_im.EMA20_M5(0), state, t.bid, t.ask, 7010001);
   if(InpEnableBoll) EvalStrategy("BOLL", g_sboll, ctx, session_open, gd, ts, g_im.EMA20_M5(0), state, t.bid, t.ask, 7010002);
   if(InpEnableRSI)  EvalStrategy("RSI",  g_srsi,  ctx, session_open, gd, ts, g_im.EMA20_M5(0), state, t.bid, t.ask, 7010003);

   UpdatePositions(t.bid, t.ask, g_im.ATR(0), /*bars_delta*/0);
}
