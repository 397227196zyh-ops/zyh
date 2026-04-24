//+------------------------------------------------------------------+
//| TestRunner.mqh                                                   |
//+------------------------------------------------------------------+
#ifndef __XAUUSD_SCALPER_TEST_RUNNER_MQH__
#define __XAUUSD_SCALPER_TEST_RUNNER_MQH__

class CTestRunner
  {
private:
   string            m_suite;
   int               m_passed;
   int               m_failed;

public:
                     CTestRunner() : m_suite(""), m_passed(0), m_failed(0) {}

   void              Begin(const string suite_name)
     {
      m_suite  = suite_name;
      m_passed = 0;
      m_failed = 0;
      PrintFormat("TEST: BEGIN %s", m_suite);
     }

   void              End()
     {
      PrintFormat("TEST: END   %s passed=%d failed=%d", m_suite, m_passed, m_failed);
     }

   void              AssertTrue(const string name, const bool cond)
     {
      if(cond) { m_passed++; PrintFormat("TEST: PASS %s/%s", m_suite, name); }
      else     { m_failed++; PrintFormat("TEST: FAIL %s/%s expected=true got=false", m_suite, name); }
     }

   void              AssertFalse(const string name, const bool cond)
     {
      AssertTrue(name, !cond);
     }

   void              AssertEqualInt(const string name, const long expected, const long actual)
     {
      if(expected == actual) { m_passed++; PrintFormat("TEST: PASS %s/%s", m_suite, name); }
      else { m_failed++; PrintFormat("TEST: FAIL %s/%s expected=%I64d got=%I64d", m_suite, name, expected, actual); }
     }

   void              AssertEqualDouble(const string name, const double expected, const double actual, const double eps)
     {
      if(MathAbs(expected - actual) <= eps) { m_passed++; PrintFormat("TEST: PASS %s/%s", m_suite, name); }
      else { m_failed++; PrintFormat("TEST: FAIL %s/%s expected=%.8f got=%.8f", m_suite, name, expected, actual); }
     }

   int               Failed() const { return m_failed; }
  };

#endif // __XAUUSD_SCALPER_TEST_RUNNER_MQH__
