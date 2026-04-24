#ifndef __XAUUSD_SCALPER_DECISION_SNAPSHOT_MQH__
#define __XAUUSD_SCALPER_DECISION_SNAPSHOT_MQH__

struct DecisionRow
  {
   datetime time;
   string   strat;
   int      dir;
   bool     session_open;
   int      guard_reason;
   int      trend_state;
   bool     allowed;
   string   reason;
   double   spread;
   double   atr;
   double   adx;
   double   sl_distance;
   double   planned_lot;
   bool     is_pyramid;
  };

class CDecisionSnapshot
  {
private:
   int    m_fh;
   string m_path;

public:
                     CDecisionSnapshot() : m_fh(INVALID_HANDLE), m_path("") {}
                    ~CDecisionSnapshot() { Close(); }

   bool              Open(const string path = "XAUUSD_Scalper/decision_snapshots.csv")
     {
      m_path = path;
      bool existed = FileIsExist(path);
      m_fh = FileOpen(path, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
      if(m_fh == INVALID_HANDLE) return false;
      FileSeek(m_fh, 0, SEEK_END);
      if(!existed)
         FileWrite(m_fh, "time","strat","dir","session","guard_reason","trend_state",
                         "allowed","reason","spread","atr","adx","sl_distance",
                         "planned_lot","is_pyramid");
      return true;
     }

   void              Close()
     {
      if(m_fh != INVALID_HANDLE) { FileClose(m_fh); m_fh = INVALID_HANDLE; }
     }

   bool              Write(const DecisionRow &r)
     {
      if(m_fh == INVALID_HANDLE) return false;
      FileWrite(m_fh,
                TimeToString(r.time, TIME_DATE|TIME_SECONDS),
                r.strat, r.dir,
                r.session_open ? 1 : 0,
                r.guard_reason, r.trend_state,
                r.allowed ? 1 : 0,
                r.reason,
                DoubleToString(r.spread,     5),
                DoubleToString(r.atr,        5),
                DoubleToString(r.adx,        2),
                DoubleToString(r.sl_distance,5),
                DoubleToString(r.planned_lot,2),
                r.is_pyramid ? 1 : 0);
      FileFlush(m_fh);
      return true;
     }
  };

#endif // __XAUUSD_SCALPER_DECISION_SNAPSHOT_MQH__
