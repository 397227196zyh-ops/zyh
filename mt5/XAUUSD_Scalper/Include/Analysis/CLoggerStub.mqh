#ifndef __XAUUSD_SCALPER_LOGGER_STUB_MQH__
#define __XAUUSD_SCALPER_LOGGER_STUB_MQH__

enum ENUM_LOG_LEVEL
  {
   LOG_LEVEL_DEBUG = 0,
   LOG_LEVEL_INFO  = 1,
   LOG_LEVEL_WARN  = 2,
   LOG_LEVEL_ERROR = 3
  };

class CLoggerStub
  {
private:
   ENUM_LOG_LEVEL    m_level;

   void              Emit(const string tag, const ENUM_LOG_LEVEL lvl, const string msg) const
     {
      if(lvl < m_level) return;
      string prefix;
      switch(lvl)
        {
         case LOG_LEVEL_DEBUG: prefix = "DBG"; break;
         case LOG_LEVEL_INFO:  prefix = "INF"; break;
         case LOG_LEVEL_WARN:  prefix = "WRN"; break;
         case LOG_LEVEL_ERROR: prefix = "ERR"; break;
         default:              prefix = "???"; break;
        }
      PrintFormat("[%s] %s | %s", prefix, tag, msg);
     }

public:
                     CLoggerStub() : m_level(LOG_LEVEL_INFO) {}

   void              SetLevel(const ENUM_LOG_LEVEL lvl) { m_level = lvl; }
   ENUM_LOG_LEVEL    Level() const { return m_level; }

   void              Debug(const string tag, const string fmt, string a="", string b="", string c="", string d="")
     { Emit(tag, LOG_LEVEL_DEBUG, StringFormat(fmt, a, b, c, d)); }

   void              Info (const string tag, const string fmt, string a="", string b="", string c="", string d="")
     { Emit(tag, LOG_LEVEL_INFO,  StringFormat(fmt, a, b, c, d)); }

   void              Warn (const string tag, const string fmt, string a="", string b="", string c="", string d="")
     { Emit(tag, LOG_LEVEL_WARN,  StringFormat(fmt, a, b, c, d)); }

   void              Error(const string tag, const string fmt, string a="", string b="", string c="", string d="")
     { Emit(tag, LOG_LEVEL_ERROR, StringFormat(fmt, a, b, c, d)); }
  };

#endif // __XAUUSD_SCALPER_LOGGER_STUB_MQH__
