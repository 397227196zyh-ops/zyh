#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Core/CRiskManager.mqh>

void FillDefaults(RiskInputs &in)
{
   in.account_equity     = 10000.0;
   in.base_risk_pct      = 0.5;     // 50 USD base risk
   in.total_risk_cap_pct = 5.0;     // 500 USD cap
   in.sl_distance        = 1.0;     // informational
   in.sl_per_lot_ccy     = 100.0;   // 1 lot costs 100 USD at stop
   in.kelly_fraction     = 0.5;     // half-Kelly
   in.open_risk_ccy      = 0.0;
   in.min_lot            = 0.01;
   in.max_lot            = 5.0;
   in.lot_step           = 0.01;
}

void OnStart()
{
   CTestRunner tr; tr.Begin("Test_RiskManager");

   CRiskManager rm;

   // Baseline: base_lots = 50/100 = 0.5, * 0.5 kelly = 0.25, passes.
   RiskInputs in; FillDefaults(in);
   RiskDecision d = rm.Size(in);
   tr.AssertTrue        ("baseline allowed",             d.allowed);
   tr.AssertEqualDouble ("baseline lot = 0.25",          0.25, d.lot, 1e-9);

   // Kelly 0 -> NON_POSITIVE_KELLY
   FillDefaults(in); in.kelly_fraction = 0.0;
   d = rm.Size(in);
   tr.AssertTrue        ("kelly 0 rejected",             !d.allowed);
   tr.AssertTrue        ("kelly 0 reason NON_POSITIVE_KELLY", d.reason == "NON_POSITIVE_KELLY");

   // Invalid SL -> INVALID_SL
   FillDefaults(in); in.sl_per_lot_ccy = 0.0;
   d = rm.Size(in);
   tr.AssertTrue        ("invalid SL rejected",          !d.allowed);
   tr.AssertTrue        ("invalid SL reason INVALID_SL", d.reason == "INVALID_SL");

   // Projected risk over 5 % cap -> rejected. open_risk = 499, new lot risks 25, sum 524 > 500.
   FillDefaults(in); in.open_risk_ccy = 499.0;
   d = rm.Size(in);
   tr.AssertTrue        ("over cap rejected",            !d.allowed);
   tr.AssertTrue        ("over cap reason TOTAL_RISK_CAP", d.reason == "TOTAL_RISK_CAP");

   // Exactly at 5 % cap: open_risk 475, lot 0.25 * 100 = 25, sum 500 == 500 -> allowed.
   FillDefaults(in); in.open_risk_ccy = 475.0;
   d = rm.Size(in);
   tr.AssertTrue        ("boundary at cap allowed",      d.allowed);

   // Below min lot: shrink Kelly so final lot rounds below 0.01.
   FillDefaults(in); in.kelly_fraction = 0.001; // base_lots 0.5 * 0.001 = 0.0005
   d = rm.Size(in);
   tr.AssertTrue        ("below min rejected",           !d.allowed);
   tr.AssertTrue        ("below min reason BELOW_MIN_LOT", d.reason == "BELOW_MIN_LOT");

   tr.End();
}
