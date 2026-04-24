# XAUUSD MT5 Hybrid Scalper EA Design

Date: 2026-04-24
Status: Approved in conversation, pending written-spec review
Target Platform: MetaTrader 5
Target Symbol: XAUUSD

## 1. Goal

Build an MT5 Expert Advisor for XAUUSD that trades a hybrid intraday scalping style during the London and New York sessions. The EA should switch between breakout and mean-reversion behavior based on market state, use adaptive volatility-aware risk sizing, support limited pyramiding, and apply strict execution filters suitable for ECN/Raw accounts.

The target outcome is not exchange-style HFT. The target outcome is a retail-MT5, high-frequency-style scalper that is practical to backtest, optimize, and run live under realistic broker constraints.

## 2. Confirmed Design Decisions

The following decisions were confirmed during brainstorming:

- Strategy type: hybrid breakout + mean reversion
- Trading sessions: London + New York
- Risk model: volatility-adaptive
- Per-trade risk: 0.5% to 1.0%
- Position style: allow limited pyramiding
- Account assumption: ECN/Raw
- Exit model: mixed exit with partial take profit + trailing remainder
- Timeframes: M1 execution with higher-timeframe confirmation
- Execution policy: strict filtering

## 3. Non-Goals

This EA will not:

- attempt exchange-level HFT or latency arbitrage
- use martingale, grid averaging, or unlimited recovery logic
- average down against an active move
- rely on hidden discretionary decisions at runtime
- assume zero slippage or stable spread during volatile events

## 4. System Architecture

The EA is split into six modules with clear boundaries.

### 4.1 MarketRegime
Determines whether the market is in Breakout, MeanReversion, or NoTrade state.

Inputs:
- M1 ATR(14)
- M5 ATR(14)
- M1 range compression over recent bars
- M1 short-term impulse strength
- M5 EMA trend structure
- current spread and execution conditions

Outputs:
- regime enum: Breakout / MeanReversion / NoTrade
- directional bias: Long / Short / Neutral

### 4.2 TrendFilter
Provides higher-timeframe directional context from M5.

Inputs:
- EMA20 and EMA50 on M5
- EMA20 slope on M5
- distance of price from EMA20 on M5

Outputs:
- bullish trend
- bearish trend
- weak / neutral trend

### 4.3 EntryEngine
Contains two sub-engines:
- BreakoutEntry
- MeanReversionEntry

Both consume the same regime, trend, and execution guard signals and output normalized trade intents.

### 4.4 RiskEngine
Calculates stop distance, lot size, and total exposure based on volatility and account constraints.

Inputs:
- risk percent
- ATR-based stop distance
- symbol contract parameters from MT5
- current open exposure

Outputs:
- lot size
- initial stop loss
- initial take-profit thresholds for management logic

### 4.5 TradeManager
Manages open positions.

Responsibilities:
- partial take profit
- break-even move
- ATR trailing stop
- pyramiding decisions
- timeout exit
- forced exit on regime invalidation

### 4.6 ExecutionGuard
Blocks bad trades before order placement.

Checks:
- spread threshold
- slippage threshold
- stop-level and freeze-level constraints
- session filter
- news blackout window
- daily drawdown and streak limits
- per-session trade cap

## 5. Explicit Trading Logic

To keep implementation concrete and avoid ambiguity, the first version will use the exact rule set below.

## 5.1 Higher-Timeframe Trend Filter (M5)

The M5 trend state is determined as follows:

### Bullish trend
All must be true:
- EMA20 > EMA50
- EMA20 slope over last 3 closed M5 bars is positive
- current M5 close is above EMA20

### Bearish trend
All must be true:
- EMA20 < EMA50
- EMA20 slope over last 3 closed M5 bars is negative
- current M5 close is below EMA20

### Weak / neutral trend
Any state not meeting the bullish or bearish definitions.

This filter is used as follows:
- Breakout trades only in the direction of bullish or bearish trend
- Mean-reversion trades are allowed only when the trend is weak / neutral, or when price is stretched but the trend-strength threshold is not exceeded

## 5.2 Market Regime Detection (M1)

The EA evaluates regime only on a new closed M1 bar.

### Compression measure
Compression is true when both conditions hold:
- average high-low range of the last 5 closed M1 bars is less than 0.8 x ATR(14) on M1
- the highest high minus lowest low of the last 5 closed M1 bars is less than 1.6 x ATR(14) on M1

### Expansion measure
Expansion is true when either condition holds:
- current closed M1 bar range is greater than 1.2 x ATR(14)
- current closed M1 close breaks the 5-bar compression range by more than 0.15 x ATR(14)

### Mean-reversion stretch measure
Stretch is true when both conditions hold:
- price closes outside an EMA20 +/- 1.2 x ATR(14) envelope on M1
- the candle closes in the outer 25% of its range, indicating a push rather than a balanced close

### NoTrade regime
NoTrade is active when any of the following are true:
- outside configured session window
- spread exceeds MaxSpreadPoints
- estimated slippage or last fill quality exceeds MaxSlippagePoints gate
- broker stop or freeze constraints make valid order placement impossible
- daily loss limit reached
- consecutive-loss limit reached
- cooldown window active
- news blackout active
- M1 ATR is below minimum tradable threshold or above maximum volatility threshold

### Breakout regime
Breakout is active when all of the following are true:
- NoTrade is false
- compression was true within the previous 3 closed M1 bars
- expansion is true on the latest closed M1 bar
- M5 trend is bullish or bearish

### MeanReversion regime
MeanReversion is active when all of the following are true:
- NoTrade is false
- stretch is true
- M5 trend is weak / neutral, or price stretch exceeds 1.8 x ATR from M1 EMA20 while M5 slope magnitude remains below strong-trend threshold

If neither Breakout nor MeanReversion conditions are met, regime is NoTrade.

## 5.3 Breakout Entry Logic

### Long breakout entry
All must be true:
- regime is Breakout
- M5 trend is bullish
- latest closed M1 bar closes above the recent 5-bar compression high
- breakout distance beyond that high is at least 0.15 x ATR(14)
- spread and stop-distance checks pass
- no existing long position count has reached configured limit

Entry method:
- place a market buy at the next tick after the qualifying M1 close

Initial stop:
- below the lower of:
  - breakout signal bar low
  - M1 EMA20 minus 0.4 x ATR(14)

Initial risk must still fit the risk budget after broker stop constraints.

### Short breakout entry
Mirror image of long breakout entry.

## 5.4 Mean-Reversion Entry Logic

### Long mean-reversion entry
All must be true:
- regime is MeanReversion
- price closed below the lower M1 envelope on the previous closed bar
- latest closed M1 bar closes back inside the envelope
- latest closed M1 bar closes above the midpoint of the prior bar
- M5 is not in a strong bearish trend
- no long entry is currently blocked by exposure rules

Entry method:
- place a market buy at the next tick after the qualifying M1 close

Initial stop:
- below the lower of:
  - signal swing low
  - envelope low minus 0.3 x ATR(14)

### Short mean-reversion entry
Mirror image of long mean-reversion entry.

## 5.5 Pyramiding Rules

Pyramiding is allowed only for winning positions and only in the same direction as the original trade.

Rules:
- maximum additional entries: 2
- pyramiding only after the first position reaches at least +0.5R unrealized
- each add-on requires a fresh valid signal in the same active regime and same direction
- each add-on must be at least 0.6 x ATR(14) away from the previous same-direction entry
- add-on lot size = min(initial lot size, previous add-on lot size) x AddOnLotScale
- default AddOnLotScale for v1: 0.67
- total open risk across the pyramid must never exceed 1.5 x base risk allocation for that trade campaign

Pyramiding is immediately disabled when:
- regime changes
- M5 trend filter no longer agrees
- first position has not secured break-even protection once partial profit logic is active

## 5.6 Exit and Trade Management

The exit model is mixed and deterministic.

### Partial take profit
- when open profit reaches 1.0R, close 50% of the position size
- after partial take profit, move stop loss on the remainder to break-even plus a small buffer

### Break-even rule
- trigger: 0.8R unrealized profit
- offset: +0.05R in favor of the trade, converted to price points

### Trailing rule for remainder
After partial take profit:
- use ATR(14) trailing stop on M1
- trail distance = 1.1 x ATR(14)
- long trades trail below the highest favorable close since entry
- short trades trail above the lowest favorable close since entry

### Timeout exit
Force-close any remaining position when:
- trade has been open longer than MaxHoldMinutes
- and profit has not reached at least 0.5R

Default MaxHoldMinutes for v1:
- breakout: 25 minutes
- mean-reversion: 18 minutes

### Regime invalidation exit
Force-close remaining position when either happens:
- opposite regime becomes active on a closed M1 bar
- execution guard enters NoTrade due to hard risk stop, session end, or news blackout

## 5.7 Risk Management

### Position sizing
Lot size is calculated from:
- account risk percent
- stop distance in points
- symbol tick value and contract size
- broker lot step and minimum lot

### Risk defaults
v1 defaults:
- RiskPercent = 0.75
- max allowed user range = 0.5 to 1.0
- DailyLossLimit = 2.5R
- ConsecutiveLossLimit = 3
- SessionTradeLimit = 8
- cooldown after loss streak = 30 minutes
- max same-direction live positions including add-ons = 3

### Hard prohibitions
The EA must never:
- add to losing trades
- exceed broker min stop rules by forcing invalid SL/TP
- bypass spread or news guards
- open a new campaign after daily risk lockout

## 5.8 Execution Filters

v1 defaults:
- MaxSpreadPoints: broker-quote normalized, default to 35 points on a 2-decimal XAUUSD quote and configurable by user
- MaxSlippagePoints: 20 points
- FreezeLevelBuffer: 10 points beyond broker freeze level
- MinStopDistanceBuffer: 10 points beyond broker stop level
- NewsBlockBeforeMinutes: 15
- NewsBlockAfterMinutes: 15

If broker quote format differs from 2-decimal gold pricing, all thresholds must be normalized through symbol point and digits metadata.

## 6. Inputs and Configuration Groups

### 6.1 General
- InpSymbolFilter
- InpMagicNumber
- InpEnableLong
- InpEnableShort
- InpSessionLondon
- InpSessionNewYork
- InpUseNewsBlock

### 6.2 Regime and Signal
- InpATRPeriodM1
- InpATRPeriodM5
- InpFastEMA
- InpSlowEMA
- InpCompressionBars
- InpCompressionATRFactor
- InpBreakoutConfirmATRFactor
- InpEnvelopeATRFactor
- InpStrongTrendSlopeThreshold

### 6.3 Risk and Exposure
- InpRiskPercent
- InpMinLot
- InpMaxLot
- InpDailyLossLimitR
- InpConsecutiveLossLimit
- InpSessionTradeLimit
- InpCooldownMinutes

### 6.4 Execution Guard
- InpMaxSpreadPoints
- InpMaxSlippagePoints
- InpFreezeLevelBufferPoints
- InpMinStopBufferPoints
- InpNewsBlockBeforeMinutes
- InpNewsBlockAfterMinutes

### 6.5 Position Management
- InpPartialTakeProfitR
- InpPartialClosePercent
- InpBreakEvenTriggerR
- InpBreakEvenOffsetR
- InpTrailATRMultiplier
- InpMaxHoldMinutesBreakout
- InpMaxHoldMinutesMeanReversion

### 6.6 Pyramiding
- InpAllowPyramiding
- InpMaxAddPositions
- InpAddOnMinProfitR
- InpAddOnDistanceATR
- InpAddOnLotScale

## 7. Data Flow

On each tick:
1. update symbol execution data
2. manage open positions and exits
3. if a new M1 bar has closed, refresh indicators and regime
4. if not in NoTrade and exposure limits allow, evaluate entries
5. submit order through guarded execution path
6. record structured log event

## 8. Logging and Diagnostics

The EA must produce concise structured logs for:
- regime changes
- blocked trades and exact reason
- entry signal fired
- order placement result and retcode
- partial exit
- break-even activation
- trailing stop movement
- forced timeout exit
- daily lockout activation

This is required so optimization failures can be explained rather than guessed.

## 9. Backtest and Validation Requirements

Success is not defined by net profit alone. Validation must inspect:
- profit factor
- expectancy per trade
- max drawdown and relative drawdown
- win rate
- average win / average loss
- average holding time
- consecutive losses
- results by session segment
- sensitivity to higher spreads
- sensitivity to slippage assumptions
- robustness under small parameter perturbations

The first implementation should be evaluated on at least:
- in-sample period
- out-of-sample period
- broker-spread stress scenario

## 10. Implementation Boundaries

Because this is MT5 on retail infrastructure, the first version will deliberately avoid:
- Level 2 / DOM-dependent logic
- external low-latency services
- hidden broker-specific hacks
- complex ML regime classifiers
- fully automated external-news ingestion as a hard dependency

For v1, news filtering should support a manual time-window mode and optionally use the platform calendar when available. The EA must still function without external services.

## 11. File and Code Structure Proposal

A clean MT5 source layout for implementation is:

- Experts/XAUUSD_Hybrid_Scalper.mq5
- Include/XAUUSD/Types.mqh
- Include/XAUUSD/Indicators.mqh
- Include/XAUUSD/TrendFilter.mqh
- Include/XAUUSD/MarketRegime.mqh
- Include/XAUUSD/RiskEngine.mqh
- Include/XAUUSD/ExecutionGuard.mqh
- Include/XAUUSD/EntryEngine.mqh
- Include/XAUUSD/TradeManager.mqh
- Include/XAUUSD/Logger.mqh

The final implementation may collapse some files if needed, but boundaries should remain the same.

## 12. Final Recommendation

Implement a controlled hybrid scalper, not an over-adaptive framework. Keep the regime model simple, the filters strict, and the exposure conservative. The first release should optimize for explainability, backtest repeatability, and live survivability on ECN/Raw conditions.

That is the correct foundation for a practical XAUUSD MT5 scalping EA.
