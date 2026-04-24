#property strict
#property description "XAUUSD Scalper Phase 1 - P2 gated signals"

#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>
#include <XAUUSD_Scalper/Core/CMarketContext.mqh>
#include <XAUUSD_Scalper/Core/CSessionFilter.mqh>
#include <XAUUSD_Scalper/Core/CExecutionGuard.mqh>
#include <XAUUSD_Scalper/Core/CTrendConfirm.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBollinger.mqh>
#include <XAUUSD_Scalper/Core/CStrategyRSI.mqh>
#include <XAUUSD_Scalper/Analysis/CLoggerStub.mqh>

input bool   InpEnableEMA        = true;
input bool   InpEnableBoll       = true;
input bool   InpEnableRSI        = true;
input int    InpTickBuffer       = 10000;
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

CTickCollector     g_tc;
CIndicatorManager  g_im;
CMarketContext     g_mc;
CSessionFilter     g_sf;
CExecutionGuard    g_eg;
CTrendConfirm      g_tcf;
CStrategyEMA       g_sema;
CStrategyBollinger g_sboll;
CStrategyRSI       g_srsi;
CLoggerStub        g_log;

datetime g_last_fail_time = 0;

int OnInit()
{
   g_tc.Init(InpTickBuffer);
   if(!g_im.Init(_Symbol))
     { g_log.Error("init", "indicator manager init failed"); return INIT_FAILED; }
   g_mc.Init(50, 20);
   g_sf.Configure(InpLonStartHour, InpLonEndHour, InpNYStartHour, InpNYEndHour);
   g_eg.Configure(InpMaxSpread, InpMaxStopLevel, InpCoolOffSec, InpDailyLossLimit, InpConsecLossLimit);
   g_tcf.Configure(InpTrendFarThresh);
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

void EvalStrategy(const string name, CStrategyBase &s, const StrategyContext &ctx,
                  const bool session_open, const GuardDecision &gd, const ENUM_TREND_STATE ts,
                  const double ema20_m5)
{
   SignalResult r = s.CheckSignal(ctx);
   if(!session_open)              { LogGate(name, r.direction, session_open, gd, ts, false, "SESSION"); return; }
   if(!gd.allowed)                { LogGate(name, r.direction, session_open, gd, ts, false, EnumToString(gd.reason)); return; }
   if(r.direction == SIGNAL_NONE) { LogGate(name, r.direction, session_open, gd, ts, false, "NO_SIGNAL"); return; }
   bool trend_ok = g_tcf.Allows(name, r.direction, ts, ctx.bid, ema20_m5);
   if(!trend_ok)                  { LogGate(name, r.direction, session_open, gd, ts, false, "TREND"); return; }
   LogGate(name, r.direction, session_open, gd, ts, true, "PASS");
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

   GuardInputs gin;
   gin.session_open   = session_open;
   gin.spread         = g_tc.LastSpread();
   gin.stops_level    = 0.0;
   gin.freeze_level   = 0.0;
   gin.market_state   = state;
   gin.now            = t.time;
   gin.last_fail_time = g_last_fail_time;
   gin.daily_loss_pct = 0.0;
   gin.consec_losses  = 0;
   GuardDecision gd = g_eg.Evaluate(gin);

   const ENUM_TREND_STATE ts = g_tcf.Classify(g_im, t.bid);

   StrategyContext ctx; ctx.im = &g_im; ctx.tc = &g_tc; ctx.state = state;
   ctx.bid = t.bid; ctx.ask = t.ask; ctx.time = t.time;

   if(InpEnableEMA)  EvalStrategy("EMA",  g_sema,  ctx, session_open, gd, ts, g_im.EMA20_M5(0));
   if(InpEnableBoll) EvalStrategy("BOLL", g_sboll, ctx, session_open, gd, ts, g_im.EMA20_M5(0));
   if(InpEnableRSI)  EvalStrategy("RSI",  g_srsi,  ctx, session_open, gd, ts, g_im.EMA20_M5(0));
}
