#property strict
#include <XAUUSD_Scalper/Tests/TestRunner.mqh>
#include <XAUUSD_Scalper/Analysis/CLoggerStub.mqh>

void OnStart()
{
   CTestRunner tr;
   tr.Begin("Test_LoggerStub");

   CLoggerStub log;
   log.SetLevel(LOG_LEVEL_DEBUG);

   log.Info ("alpha",  "hello %s", "world");
   log.Warn ("alpha",  "warn=%d", 42);
   log.Error("alpha",  "err=%s",  "boom");
   log.Debug("alpha",  "dbg=%.2f", 1.25);

   tr.AssertTrue("logger level is DEBUG",  log.Level() == LOG_LEVEL_DEBUG);
   log.SetLevel(LOG_LEVEL_WARN);
   tr.AssertTrue("logger level changed to WARN", log.Level() == LOG_LEVEL_WARN);

   tr.End();
}
