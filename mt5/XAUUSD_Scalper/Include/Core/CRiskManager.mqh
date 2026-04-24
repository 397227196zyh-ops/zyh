#ifndef __XAUUSD_SCALPER_RISK_MANAGER_MQH__
#define __XAUUSD_SCALPER_RISK_MANAGER_MQH__

// CRiskManager sizes positions from the 0.5 % base risk anchor scaled by
// half-Kelly, and rejects anything that would push total open risk above
// the total_risk_cap_pct.
//
// All inputs are plain values so the class can be unit-tested without
// touching the MT5 trade context.

struct RiskInputs
  {
   double account_equity;
   double base_risk_pct;      // e.g. 0.5 for 0.5 %
   double total_risk_cap_pct; // e.g. 5.0 for 5 %
   double sl_distance;        // price units, only used for informational logging
   double sl_per_lot_ccy;     // loss at stop for 1.0 lot, account currency
   double kelly_fraction;     // already half-Kelly, clamped externally
   double open_risk_ccy;      // sum of open positions' theoretical max loss
   double min_lot;
   double max_lot;
   double lot_step;
  };

struct RiskDecision
  {
   bool   allowed;
   double lot;
   string reason;
  };

class CRiskManager
  {
private:
   static double Clamp(const double x, const double lo, const double hi)
     {
      if(x < lo) return lo;
      if(x > hi) return hi;
      return x;
     }

   static double FloorToStep(const double value, const double step)
     {
      if(step <= 0.0) return value;
      double k = MathFloor(value / step);
      return k * step;
     }

public:
   RiskDecision Size(const RiskInputs &in) const
     {
      RiskDecision d; d.allowed = false; d.lot = 0.0; d.reason = "";

      if(in.kelly_fraction <= 0.0)
        { d.reason = "NON_POSITIVE_KELLY"; return d; }

      if(in.sl_per_lot_ccy <= 0.0)
        { d.reason = "INVALID_SL"; return d; }

      if(in.account_equity <= 0.0)
        { d.reason = "INVALID_EQUITY"; return d; }

      double base_risk_ccy = in.account_equity * in.base_risk_pct / 100.0;
      double base_lots     = base_risk_ccy / in.sl_per_lot_ccy;
      double kelly_scaled  = base_lots * Clamp(in.kelly_fraction, 0.0, 1.0);

      double lot = FloorToStep(kelly_scaled, in.lot_step);
      lot = MathMin(lot, in.max_lot);

      if(lot < in.min_lot)
        { d.reason = "BELOW_MIN_LOT"; return d; }

      double projected = in.open_risk_ccy + lot * in.sl_per_lot_ccy;
      double cap       = in.account_equity * in.total_risk_cap_pct / 100.0;
      if(projected > cap + 1e-9)
        { d.reason = "TOTAL_RISK_CAP"; return d; }

      d.allowed = true;
      d.lot     = lot;
      d.reason  = "OK";
      return d;
     }
  };

#endif // __XAUUSD_SCALPER_RISK_MANAGER_MQH__
