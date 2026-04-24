#ifndef __XAUUSD_SCALPER_REPORT_GENERATOR_MQH__
#define __XAUUSD_SCALPER_REPORT_GENERATOR_MQH__

#include <XAUUSD_Scalper/Analysis/CPerformanceTracker.mqh>

// Self-contained HTML report. Loads Chart.js from cdn.jsdelivr.net at
// render time (no external dependency embedded in the repo).

struct EquityPoint
  {
   datetime time;
   double   equity;
  };

struct TradeReportRow
  {
   datetime time;
   string   strat;
   int      dir;
   double   entry;
   double   exit;
   double   pnl;
  };

struct GuardBar
  {
   string reason;
   int    count;
  };

class CReportGenerator
  {
private:
   // Pure helpers: kept free of FileOpen so unit tests can exercise the
   // HTML body assembly without touching disk.

   string JoinEquityArray(const EquityPoint &pts[]) const
     {
      string s = "";
      int n = ArraySize(pts);
      for(int i = 0; i < n; i++)
        {
         if(i > 0) s += ",";
         s += StringFormat("{t:\"%s\",y:%.2f}",
                           TimeToString(pts[i].time, TIME_DATE|TIME_SECONDS),
                           pts[i].equity);
        }
      return s;
     }

   string JoinTradeRows(const TradeReportRow &rows[]) const
     {
      string s = "";
      int n = ArraySize(rows);
      for(int i = 0; i < n; i++)
        {
         s += StringFormat("<tr><td>%s</td><td>%s</td><td>%d</td>"
                           "<td>%.2f</td><td>%.2f</td><td>%.2f</td></tr>",
                           TimeToString(rows[i].time, TIME_DATE|TIME_SECONDS),
                           rows[i].strat, rows[i].dir,
                           rows[i].entry, rows[i].exit, rows[i].pnl);
        }
      return s;
     }

   string JoinGuardBars(const GuardBar &bars[]) const
     {
      string labels = "";
      string counts = "";
      int n = ArraySize(bars);
      for(int i = 0; i < n; i++)
        {
         if(i > 0) { labels += ","; counts += ","; }
         labels += "\"" + bars[i].reason + "\"";
         counts += IntegerToString(bars[i].count);
        }
      return "{labels:[" + labels + "],counts:[" + counts + "]}";
     }

public:
   string            BuildHTML(const CPerformanceTracker &pt,
                               const EquityPoint &equity[],
                               const TradeReportRow &trades[],
                               const GuardBar &guard[]) const
     {
      ReturnsStats          r  = pt.Returns();
      ExecutionQualityStats eq = pt.ExecutionQuality();
      SignalQualityStats    sq = pt.SignalQuality();
      PositionMgmtStats     pm = pt.PositionManagement();
      PyramidingStats       py = pt.Pyramiding();

      string equity_js = JoinEquityArray(equity);
      string trade_html = JoinTradeRows(trades);
      string guard_js = JoinGuardBars(guard);

      string html = "";
      html += "<!DOCTYPE html><html><head><meta charset=\"UTF-8\">";
      html += "<title>XAUUSD Scalper Report</title>";
      html += "<script src=\"https://cdn.jsdelivr.net/npm/chart.js\"></script>";
      html += "<script src=\"https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns\"></script>";
      html += "<style>body{font-family:sans-serif;margin:20px;color:#222}";
      html += "table{border-collapse:collapse;margin:10px 0}";
      html += "th,td{border:1px solid #bbb;padding:4px 8px;font-size:12px}";
      html += ".card{display:inline-block;border:1px solid #ddd;padding:10px 14px;";
      html += "margin:4px;border-radius:6px;background:#fafafa}";
      html += ".pos{color:#176}.neg{color:#a33}</style></head><body>";
      html += "<h1>XAUUSD Scalper &mdash; Phase 1 Report</h1>";

      html += "<section><h2>Overview</h2>";
      html += StringFormat("<div class='card'>Net PnL: <b class='%s'>%.2f</b></div>",
                           r.net_pnl >= 0 ? "pos" : "neg", r.net_pnl);
      html += StringFormat("<div class='card'>Trades: <b>%d</b></div>", r.total_trades);
      html += StringFormat("<div class='card'>Wins: <b>%d</b></div>", r.wins);
      html += StringFormat("<div class='card'>Losses: <b>%d</b></div>", r.losses);
      html += StringFormat("<div class='card'>Win Rate: <b>%.2f%%</b></div>",
                           100.0 * pt.WinRate());
      html += StringFormat("<div class='card'>Payoff: <b>%.2f</b></div>", pt.PayoffRatio());
      html += StringFormat("<div class='card'>Avg Slippage: <b>%.3f</b></div>",
                           pt.AvgSlippage());
      html += StringFormat("<div class='card'>Pyramids: <b>%d</b></div>", py.adds_done);
      html += "</section>";

      html += "<section><h2>Signal quality</h2>";
      html += StringFormat("<div class='card'>Candidates: <b>%d</b></div>", sq.candidates);
      html += StringFormat("<div class='card'>Filled: <b>%d</b></div>", sq.filled);
      html += StringFormat("<div class='card'>Rej session: <b>%d</b></div>", sq.rejected_session);
      html += StringFormat("<div class='card'>Rej guard: <b>%d</b></div>", sq.rejected_guard);
      html += StringFormat("<div class='card'>Rej abnormal: <b>%d</b></div>", sq.rejected_abnormal);
      html += StringFormat("<div class='card'>Rej trend: <b>%d</b></div>", sq.rejected_trend);
      html += "</section>";

      html += "<section><h2>Execution quality</h2>";
      html += StringFormat("<div class='card'>Fills: <b>%d</b></div>", eq.fills);
      html += StringFormat("<div class='card'>Rejects: <b>%d</b></div>", eq.rejects);
      html += StringFormat("<div class='card'>Limit fills: <b>%d</b></div>", eq.limit_fills);
      html += StringFormat("<div class='card'>Limit timeouts: <b>%d</b></div>", eq.limit_timeouts);
      html += "</section>";

      html += "<section><h2>Position management</h2>";
      html += StringFormat("<div class='card'>Partial TP: <b>%d</b></div>", pm.partial_triggered);
      html += StringFormat("<div class='card'>Beaten after BE: <b>%d</b></div>", pm.beaten_after_be);
      html += StringFormat("<div class='card'>Trail exits: <b>%d</b></div>", pm.trail_exits);
      html += StringFormat("<div class='card'>Timeout exits: <b>%d</b></div>", pm.timeout_exits);
      html += "</section>";

      html += "<section><h2>Equity curve</h2>";
      html += "<canvas id=\"equity_chart\" width=\"800\" height=\"320\"></canvas>";
      html += "<script>";
      html += "const EQUITY_DATA = [" + equity_js + "];";
      html += "const GUARD_REASON_DISTRIBUTION = " + guard_js + ";";
      html += "window.addEventListener('load', () => {";
      html += "const ctx = document.getElementById('equity_chart').getContext('2d');";
      html += "new Chart(ctx, {type:'line', data:{datasets:[{label:'Equity',";
      html += "data:EQUITY_DATA.map(d=>({x:d.t,y:d.y})),borderColor:'#176',fill:false}]},";
      html += "options:{parsing:false,scales:{x:{type:'time'}}}});";
      html += "const gctx = document.getElementById('guard_chart').getContext('2d');";
      html += "new Chart(gctx, {type:'bar', data:{labels:GUARD_REASON_DISTRIBUTION.labels,";
      html += "datasets:[{label:'Rejections',data:GUARD_REASON_DISTRIBUTION.counts,";
      html += "backgroundColor:'#a33'}]}});";
      html += "});";
      html += "</script>";
      html += "</section>";

      html += "<section id='guard_reason_distribution'><h2>Guard rejection distribution</h2>";
      html += "<canvas id=\"guard_chart\" width=\"800\" height=\"280\"></canvas></section>";

      html += "<section><h2>Trades</h2><table><tr>";
      html += "<th>Time</th><th>Strat</th><th>Dir</th><th>Entry</th><th>Exit</th><th>PnL</th></tr>";
      html += trade_html;
      html += "</table></section>";

      html += "</body></html>";
      return html;
     }

   bool              Write(const string path, const string html) const
     {
      int fh = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(fh == INVALID_HANDLE) return false;
      FileWriteString(fh, html);
      FileClose(fh);
      return true;
     }
  };

#endif // __XAUUSD_SCALPER_REPORT_GENERATOR_MQH__
