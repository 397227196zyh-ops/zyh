#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CExecutionGuard.mqh>

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_ExecutionGuard");

   CExecutionGuard g;
   g.Configure(/*max_spread*/0.08, /*max_stop_level*/0.1, /*cool_off_sec*/60,
               /*daily_loss_limit_pct*/2.0, /*consec_loss_limit*/5);

   GuardInputs in;
   in.session_open   = true;
   in.spread         = 0.05;
   in.stops_level    = 0.02;
   in.freeze_level   = 0.01;
   in.market_state   = MARKET_TRENDING;
   in.now            = (datetime)1000;
   in.last_fail_time = 0;
   in.daily_loss_pct = 0.0;
   in.consec_losses  = 0;

   GuardDecision d = g.Evaluate(in);
   tr.AssertTrue("all good -> allowed",                   d.allowed);
   tr.AssertEqualInt("reason_code OK",                    (int)GUARD_OK, (int)d.reason);

   in.session_open = false;
   d = g.Evaluate(in);
   tr.AssertEqualInt("session closed -> SESSION",         (int)GUARD_SESSION_CLOSED, (int)d.reason);

   in.session_open = true; in.spread = 0.20;
   d = g.Evaluate(in);
   tr.AssertEqualInt("spread high -> SPREAD",             (int)GUARD_SPREAD, (int)d.reason);

   in.spread = 0.05; in.market_state = MARKET_ABNORMAL;
   d = g.Evaluate(in);
   tr.AssertEqualInt("abnormal state -> ABNORMAL",        (int)GUARD_ABNORMAL_MARKET, (int)d.reason);

   in.market_state = MARKET_TRENDING; in.consec_losses = 10;
   d = g.Evaluate(in);
   tr.AssertEqualInt("consec losses -> CONSEC",           (int)GUARD_CONSEC_LOSSES, (int)d.reason);

   in.consec_losses = 0; in.daily_loss_pct = 5.0;
   d = g.Evaluate(in);
   tr.AssertEqualInt("daily loss -> DAILY",               (int)GUARD_DAILY_LOSS, (int)d.reason);

   in.daily_loss_pct = 0.0; in.last_fail_time = (datetime)995; in.now = (datetime)1000;
   d = g.Evaluate(in);
   tr.AssertEqualInt("cooldown -> COOLDOWN",              (int)GUARD_COOLDOWN, (int)d.reason);

   tr.End();
}
