#property strict
#property description "XAUUSD Scalper Phase 1 - foundation only"

#include <XAUUSD_Scalper/Data/CTickCollector.mqh>
#include <XAUUSD_Scalper/Data/CIndicatorManager.mqh>
#include <XAUUSD_Scalper/Core/CMarketAnalyzer.mqh>
#include <XAUUSD_Scalper/Core/CStrategyEMA.mqh>
#include <XAUUSD_Scalper/Core/CStrategyBollinger.mqh>
#include <XAUUSD_Scalper/Core/CStrategyRSI.mqh>
#include <XAUUSD_Scalper/Analysis/CLoggerStub.mqh>

input bool   InpEnableEMA   = true;
input bool   InpEnableBoll  = true;
input bool   InpEnableRSI   = true;
input int    InpTickBuffer  = 10000;

CTickCollector     g_tc;
CIndicatorManager  g_im;
CStrategyEMA       g_sema;
CStrategyBollinger g_sboll;
CStrategyRSI       g_srsi;
CLoggerStub        g_log;

int OnInit()
{
   g_tc.Init(InpTickBuffer);
   if(!g_im.Init(_Symbol))
   {
      g_log.Error("init", "indicator manager init failed");
      return INIT_FAILED;
   }
   g_log.Info("init", "Init OK");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_im.Shutdown();
   g_log.Info("deinit", StringFormat("reason=%d", reason));
}

void OnTick()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   g_tc.OnTick(t);
   g_im.Update();

   MarketInputs mi;
   mi.adx         = g_im.ADX(0);
   mi.atr         = g_im.ATR(0);
   mi.atr_avg     = g_im.ATR(0); // replaced with rolling avg in P3
   mi.bb_width    = g_im.BBWidth(0);
   mi.last_spread = g_tc.LastSpread();
   mi.max_jump    = g_tc.MaxJump();
   mi.ticks_per_s = g_tc.TicksPerSecondEstimate();
   mi.breakouts   = 0; // fully wired in P3
   ENUM_MARKET_STATE state = CMarketAnalyzer::Classify(mi);

   StrategyContext ctx; ctx.im = &g_im; ctx.tc = &g_tc; ctx.state = state;
   ctx.bid = t.bid; ctx.ask = t.ask; ctx.time = t.time;

   if(InpEnableEMA)
   {
      SignalResult r = g_sema.CheckSignal(ctx);
      g_log.Debug("ema",  StringFormat("dir=%d", r.direction));
   }
   if(InpEnableBoll)
   {
      SignalResult r = g_sboll.CheckSignal(ctx);
      g_log.Debug("boll", StringFormat("dir=%d", r.direction));
   }
   if(InpEnableRSI)
   {
      SignalResult r = g_srsi.CheckSignal(ctx);
      g_log.Debug("rsi",  StringFormat("dir=%d", r.direction));
   }
}
