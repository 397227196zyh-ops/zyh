#ifndef __XAUUSD_SCALPER_LOGGER_MQH__
#define __XAUUSD_SCALPER_LOGGER_MQH__

// Full file-based logger replacing CLoggerStub. Writes to six per-category
// files under MQL5/Files/XAUUSD_Scalper/Logs/ and rotates on day change.
//
// API keeps the same Info/Warn/Error/Debug(tag, msg) shape so existing call
// sites only swap the type.

enum ENUM_LOG_LEVEL_FULL
  {
   LOGX_DEBUG = 0,
   LOGX_INFO  = 1,
   LOGX_WARN  = 2,
   LOGX_ERROR = 3
  };

enum ENUM_LOG_CATEGORY
  {
   LOGX_CAT_MAIN          = 0,
   LOGX_CAT_TRADES        = 1,
   LOGX_CAT_EXECUTION     = 2,
   LOGX_CAT_MARKET_EVENTS = 3,
   LOGX_CAT_GUARD         = 4,
   LOGX_CAT_ERRORS        = 5,
   LOGX_CAT_COUNT         = 6
  };

class CLogger
  {
private:
   string              m_base_dir;        // "XAUUSD_Scalper/Logs"
   string              m_current_day;     // YYYYMMDD
   int                 m_handles[LOGX_CAT_COUNT];
   ENUM_LOG_LEVEL_FULL m_level;

   string              CatName(const ENUM_LOG_CATEGORY c) const
     {
      switch(c)
        {
         case LOGX_CAT_MAIN:          return "main";
         case LOGX_CAT_TRADES:        return "trades";
         case LOGX_CAT_EXECUTION:     return "execution";
         case LOGX_CAT_MARKET_EVENTS: return "market_events";
         case LOGX_CAT_GUARD:         return "guard";
         case LOGX_CAT_ERRORS:        return "errors";
        }
      return "main";
     }

   string              DayString(const datetime t) const
     {
      MqlDateTime d; TimeToStruct(t, d);
      return StringFormat("%04d%02d%02d", d.year, d.mon, d.day);
     }

   string              FilePath(const ENUM_LOG_CATEGORY c, const string day) const
     {
      return StringFormat("%s/%s_%s.log", m_base_dir, CatName(c), day);
     }

   void                OpenAll(const string day)
     {
      m_current_day = day;
      for(int i = 0; i < LOGX_CAT_COUNT; i++)
        {
         if(m_handles[i] != INVALID_HANDLE) FileClose(m_handles[i]);
         string path = FilePath((ENUM_LOG_CATEGORY)i, day);
         m_handles[i] = FileOpen(path, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
         if(m_handles[i] != INVALID_HANDLE) FileSeek(m_handles[i], 0, SEEK_END);
        }
     }

   void                CloseAll()
     {
      for(int i = 0; i < LOGX_CAT_COUNT; i++)
        {
         if(m_handles[i] != INVALID_HANDLE) { FileClose(m_handles[i]); m_handles[i] = INVALID_HANDLE; }
        }
     }

   void                RotateIfNeeded(const datetime t)
     {
      string d = DayString(t);
      if(d != m_current_day) OpenAll(d);
     }

   string              LevelPrefix(const ENUM_LOG_LEVEL_FULL lvl) const
     {
      switch(lvl)
        {
         case LOGX_DEBUG: return "DBG";
         case LOGX_INFO:  return "INF";
         case LOGX_WARN:  return "WRN";
         case LOGX_ERROR: return "ERR";
        }
      return "???";
     }

   ENUM_LOG_CATEGORY   CatFromTag(const string tag) const
     {
      if(tag == "trades" || tag == "order")  return LOGX_CAT_TRADES;
      if(tag == "exec"   || tag == "execution") return LOGX_CAT_EXECUTION;
      if(tag == "market" || tag == "abnormal" || tag == "regime") return LOGX_CAT_MARKET_EVENTS;
      if(tag == "gate"   || tag == "guard")  return LOGX_CAT_GUARD;
      if(tag == "error"  || tag == "err")    return LOGX_CAT_ERRORS;
      return LOGX_CAT_MAIN;
     }

   void                Emit(const string tag, const ENUM_LOG_LEVEL_FULL lvl, const string msg)
     {
      if(lvl < m_level) return;
      RotateIfNeeded(TimeCurrent());

      string line = StringFormat("[%s] %s | %s | %s", LevelPrefix(lvl),
                                  TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                  tag, msg);
      PrintFormat("%s", line); // mirror to terminal
      ENUM_LOG_CATEGORY c = CatFromTag(tag);
      int h = m_handles[c];
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, line + "\n");
         FileFlush(h);
        }
      if(lvl == LOGX_ERROR)
        {
         int he = m_handles[LOGX_CAT_ERRORS];
         if(he != INVALID_HANDLE && he != h)
           {
            FileWriteString(he, line + "\n");
            FileFlush(he);
           }
        }
      if(lvl == LOGX_DEBUG) { /* keep only in main */ }
     }

public:
                       CLogger() : m_base_dir("XAUUSD_Scalper/Logs"),
                                   m_current_day(""), m_level(LOGX_INFO)
     {
      for(int i = 0; i < LOGX_CAT_COUNT; i++) m_handles[i] = INVALID_HANDLE;
     }
                      ~CLogger() { CloseAll(); }

   void                Init(const string base_dir = "XAUUSD_Scalper/Logs")
     {
      m_base_dir = base_dir;
      FolderCreate(m_base_dir);
      OpenAll(DayString(TimeCurrent()));
     }

   void                Shutdown() { CloseAll(); }

   void                SetLevel(const ENUM_LOG_LEVEL_FULL lvl) { m_level = lvl; }
   ENUM_LOG_LEVEL_FULL Level() const { return m_level; }

   void                Debug(const string tag, const string msg) { Emit(tag, LOGX_DEBUG, msg); }
   void                Info (const string tag, const string msg) { Emit(tag, LOGX_INFO,  msg); }
   void                Warn (const string tag, const string msg) { Emit(tag, LOGX_WARN,  msg); }
   void                Error(const string tag, const string msg) { Emit(tag, LOGX_ERROR, msg); }

   void                CleanupOldLogs(const datetime today, const int keep_days = 30)
     {
      // MQL5 portable installs forbid deleting Files/ entries that are
      // currently open; full retention pruning is left to a user-run
      // housekeeping script. This hook is intentionally a no-op for now.
     }
  };

#endif // __XAUUSD_SCALPER_LOGGER_MQH__
