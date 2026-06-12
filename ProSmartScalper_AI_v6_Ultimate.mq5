//+------------------------------------------------------------------+
//|                                  ProSmartScalper_AI_v6_Ultimate.mq5 |
//|                          Professional Smart Money Trading Robot      |
//|  v6.0 - SMC Strategy: Accumulation, Manipulation, Distribution       |
//+------------------------------------------------------------------+
#property copyright   "ProSmartScalper AI Ultimate"
#property version     "6.00"
#property description "Smart Money Concepts + Multi-Indicator Scalper"
#property description "Real Market Optimized with Spread/Commission"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//============================================================
// INPUT PARAMETERS - OPTIMIZED FOR REAL TRADING
//============================================================

input group "=== 💰 RISK MANAGEMENT (REAL OPTIMIZED) ==="
input double   InpRiskPercent      = 0.8;    // Risk per trade % (0.5-2.0 recommended)
input double   InpMaxDailyLoss     = 3.0;    // Max daily loss % (stop trading)
input double   InpMaxDailyProfit   = 8.0;    // Max daily profit % (profit lock)
input int      InpCoolDownHours    = 4;      // Cool-down after loss (hours)
input int      InpOverrideScore    = 8;      // Perfect Signal override score (8/10)
input int      InpMaxPositions     = 1;      // Max open positions
input double   InpMaxLotSize       = 2.0;    // Maximum lot size
input double   InpMinLotSize       = 0.01;   // Minimum lot size
input double   InpMicroBalanceUSD  = 100.0;  // Micro mode threshold

input group "=== 📊 SMART MONEY CONCEPTS (SMC) ==="
input bool     InpUseSMC           = true;   // Enable Smart Money Concepts
input int      InpOrderBlockBars   = 20;     // Order Block lookback period
input int      InpFVG_MinPoints    = 30;     // Fair Value Gap minimum (points)
input int      InpBOS_ConfirmBars  = 3;      // Break of Structure confirmation
input bool     InpUseAccumulation  = true;   // Detect Accumulation phase
input bool     InpUseManipulation  = true;   // Detect Manipulation (Wyckoff)
input bool     InpUseDistribution  = true;   // Detect Distribution phase
input double   InpVolSpikeThreshold= 1.5;    // Volume spike multiplier
input int      InpSMC_HTF_Period   = PERIOD_H4; // SMC Higher Timeframe

input group "=== 🎯 SL/TP & POSITION MANAGEMENT ==="
input int      InpSL_Points        = 200;    // Stop Loss (points) - Real scalping
input int      InpTP_Points        = 400;    // Take Profit (points) - 1:2 RR
input bool     InpUseATR_SLTP      = true;   // Use ATR for dynamic SL/TP
input double   InpATR_SL_Multi     = 1.2;    // ATR SL multiplier
input double   InpATR_TP_Multi     = 2.5;    // ATR TP multiplier
input bool     InpUseTrailing      = true;   // Trailing stop
input int      InpTrailStart       = 150;    // Trailing start (points)
input int      InpTrailStep        = 40;     // Trailing step (points)
input bool     InpUseBE            = true;   // Breakeven
input int      InpBE_Activate      = 100;    // Breakeven activation (points)
input int      InpMaxHoldHours     = 24;     // Max position hold time (hours)

input group "=== 📈 MULTI-INDICATOR CONFLUENCE ==="
input int      InpFastEMA          = 8;      // Fast EMA
input int      InpMediumEMA        = 21;     // Medium EMA
input int      InpSlowEMA          = 50;     // Slow EMA
input int      InpTrendEMA         = 200;    // Trend EMA
input int      InpRSI_Period       = 14;     // RSI Period
input double   InpRSI_Oversold     = 30.0;   // RSI Oversold
input double   InpRSI_Overbought   = 70.0;   // RSI Overbought
input int      InpMACD_Fast        = 12;     // MACD Fast
input int      InpMACD_Slow        = 26;     // MACD Slow
input int      InpMACD_Signal      = 9;      // MACD Signal
input int      InpATR_Period       = 14;     // ATR Period
input int      InpBB_Period        = 20;     // Bollinger Bands Period
input double   InpBB_Deviation     = 2.0;    // BB Deviation

input group "=== 💸 SPREAD & COMMISSION (REAL COSTS) ==="
input double   InpMaxSpreadPoints  = 5.0;    // Max spread (points) - Filter wide spread
input double   InpCommissionPerLot = 7.0;    // Commission per lot (USD) - ECN brokers
input bool     InpAdjustTP_For_Cost= true;   // Adjust TP to cover spread+commission

input group "=== 📰 NEWS & SESSION FILTERS ==="
input bool     InpUseNewsFilter    = true;   // News filter (Calendar API)
input int      InpNewsMinsBefore   = 30;     // Minutes before news
input int      InpNewsMinsAfter    = 20;     // Minutes after news
input bool     InpFilterHighImpact = true;   // High impact news
input bool     InpFilterMedImpact  = true;   // Medium impact news
input string   InpNewsCurrencies   = "USD,EUR,GBP,XAU"; // Filter currencies
input bool     InpNoWeekend        = true;   // No weekend trading
input int      InpFridayCloseHour  = 23;     // Friday close hour
input int      InpFridayCloseMin   = 30;     // Friday close minute

input group "=== 🎯 SIGNAL QUALITY & CONFLUENCE ==="
input int      InpMinConfluence    = 6;      // Min confluence score (normal mode)
input int      InpSMC_BonusScore   = 2;      // SMC pattern bonus score
input int      InpMinScoreDiff     = 2;      // Min BUY/SELL score difference

input group "=== ⚙️ GENERAL SETTINGS ==="
input long     InpMagicNumber      = 202406; // Magic number
input string   InpTradeComment     = "ProSmart_v6_SMC";
input bool     InpShowDashboard    = true;   // Show dashboard
input bool     InpEnableAlerts     = true;   // Enable alerts
input bool     InpDebugMode        = false;  // Debug logs

//============================================================
// GLOBAL VARIABLES
//============================================================
CTrade         trade;
CPositionInfo  posInfo;

// Indicator handles
int handleFastEMA, handleMedEMA, handleSlowEMA, handleTrendEMA;
int handleRSI, handleMACD, handleATR, handleBB;
int handleHTF_EMA, handleHTF_RSI;
int handleVolume;

// Statistics
double dailyStartBalance  = 0;
double dailyProfit        = 0;
datetime lastBarTime      = 0;
datetime lastDayReset     = 0;
int    winTrades          = 0;
int    lossTrades         = 0;
double totalPnL           = 0;
double totalCommission    = 0;
double totalSpreadCost    = 0;

// Signal tracking
string lastSignal         = "Initializing...";
string marketPhase        = "Analyzing...";
string smcPattern         = "None";
int    confluenceScore    = 0;
bool   newsBlocking       = false;
string newsStatus         = "Checking...";
string sessionStatus      = "—";

// Cool-down system
datetime coolDownUntil    = 0;
bool   isCoolDownActive   = false;

// SMC Data Structures
struct OrderBlock
{
   datetime time;
   double   highPrice;
   double   lowPrice;
   bool     isBullish;
   int      strength;
};

struct FairValueGap
{
   datetime time;
   double   upperPrice;
   double   lowerPrice;
   bool     isBullish;
};

OrderBlock lastBullishOB;
OrderBlock lastBearishOB;
FairValueGap lastFVG;
bool hasValidOB = false;
bool hasValidFVG = false;

// Market structure
double lastHigherHigh = 0;
double lastHigherLow  = 0;
double lastLowerHigh  = 0;
double lastLowerLow   = 0;
string trendDirection = "NEUTRAL";

// News cache
struct NewsEvent
{
   datetime eventTime;
   string   currency;
   string   title;
   int      impact;
};
NewsEvent newsCache[];
datetime lastNewsFetch = 0;
int newsCacheCount = 0;

//============================================================

// INITIALIZATION
//============================================================
int OnInit()
{
   Print("╔═══════════════════════════════════════════════════════╗");
   Print("║   ProSmartScalper AI v6.0 ULTIMATE - SMC Edition      ║");
   Print("║   Smart Money Concepts + Multi-Indicator Strategy     ║");
   Print("║   Real Market Optimized | Spread & Commission Ready   ║");
   Print("╚═══════════════════════════════════════════════════════╝");
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.LogLevel(LOG_LEVEL_ERRORS);
   
   // Initialize indicators
   handleFastEMA  = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleMedEMA   = iMA(_Symbol, PERIOD_CURRENT, InpMediumEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleSlowEMA  = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleTrendEMA = iMA(_Symbol, PERIOD_CURRENT, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI      = iRSI(_Symbol, PERIOD_CURRENT, InpRSI_Period, PRICE_CLOSE);
   handleMACD     = iMACD(_Symbol, PERIOD_CURRENT, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, PRICE_CLOSE);
   handleATR      = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
   handleBB       = iBands(_Symbol, PERIOD_CURRENT, InpBB_Period, 0, InpBB_Deviation, PRICE_CLOSE);
   handleHTF_EMA  = iMA(_Symbol, InpSMC_HTF_Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleHTF_RSI  = iRSI(_Symbol, InpSMC_HTF_Period, InpRSI_Period, PRICE_CLOSE);
   handleVolume   = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
   
   if(handleFastEMA == INVALID_HANDLE || handleMedEMA == INVALID_HANDLE ||
      handleSlowEMA == INVALID_HANDLE || handleTrendEMA == INVALID_HANDLE ||
      handleRSI == INVALID_HANDLE || handleMACD == INVALID_HANDLE ||
      handleATR == INVALID_HANDLE || handleBB == INVALID_HANDLE ||
      handleHTF_EMA == INVALID_HANDLE || handleHTF_RSI == INVALID_HANDLE)
   {
      Print("❌ ERROR: Failed to create indicators!");
      return INIT_FAILED;
   }
   
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   lastDayReset = TimeCurrent();
   
   FetchNewsFromCalendar();
   
   Print("✅ Robot initialized successfully!");
   Print("💰 Initial Balance: $", dailyStartBalance);
   Print("📊 Symbol: ", _Symbol, " | TF: ", EnumToString(Period()));
   Print("🎯 Risk per trade: ", InpRiskPercent, "%");
   Print("🧠 SMC Mode: ", (InpUseSMC ? "ENABLED ✅" : "DISABLED"));
   
   return INIT_SUCCEEDED;
}

//============================================================
// DEINITIALIZATION
//============================================================
void OnDeinit(const int reason)
{
   IndicatorRelease(handleFastEMA);
   IndicatorRelease(handleMedEMA);
   IndicatorRelease(handleSlowEMA);
   IndicatorRelease(handleTrendEMA);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleMACD);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleBB);
   IndicatorRelease(handleHTF_EMA);
   IndicatorRelease(handleHTF_RSI);
   IndicatorRelease(handleVolume);
   
   Comment("");
   Print("🛑 ProSmartScalper AI v6.0 stopped. Total P&L: $", totalPnL);
}

//============================================================
// MAIN TICK FUNCTION
//============================================================
void OnTick()
{
   UpdateDailyStats();
   ManageOpenPositions();
   
   // Check for new bar
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBar == lastBarTime) return;
   lastBarTime = currentBar;
   
   // Update news cache hourly
   if(TimeCurrent() - lastNewsFetch > 3600)
      FetchNewsFromCalendar();
   
   // Check cool-down status
   CheckCoolDownStatus();
   
   // Update dashboard
   if(InpShowDashboard) DrawDashboard();
   
   // === FILTERS ===
   if(!IsMarketSessionOpen()) return;
   if(InpUseNewsFilter && IsNewsTime()) return;
   if(!CheckSpreadFilter()) return;
   
   newsBlocking = false;
   
   // Check max positions
   if(CountMyPositions() >= InpMaxPositions) return;
   
   // === ANALYZE MARKET ===
   int signal = AnalyzeMarketWithSMC();
   
   // === TRADING LOGIC ===
   bool canTrade = false;
   
   if(!isCoolDownActive)
   {
      // Normal mode
      canTrade = true;
   }
   else if(isCoolDownActive && confluenceScore >= InpOverrideScore)
   {
      // Cool-down override with perfect signal
      Print("🚀 PERFECT SIGNAL OVERRIDE! Score: ", confluenceScore, "/10");
      canTrade = true;
   }
   
   if(canTrade)
   {
      if(signal == 1)  ExecuteTrade(ORDER_TYPE_BUY);
      if(signal == -1) ExecuteTrade(ORDER_TYPE_SELL);
   }
}

//============================================================
// SMART MONEY CONCEPTS - MARKET ANALYSIS
//============================================================
int AnalyzeMarketWithSMC()
{
   // Get indicator data
   double fastEma[3], medEma[3], slowEma[3], trendEma[3];
   double rsi[3], macdMain[3], macdSig[3], atr[3];
   double bbUpper[3], bbMid[3], bbLower[3];
   double htfEma[3], htfRsi[3];
   long volume[10];
   
   if(CopyBuffer(handleFastEMA, 0, 0, 3, fastEma) < 3) return 0;
   if(CopyBuffer(handleMedEMA, 0, 0, 3, medEma) < 3) return 0;
   if(CopyBuffer(handleSlowEMA, 0, 0, 3, slowEma) < 3) return 0;
   if(CopyBuffer(handleTrendEMA, 0, 0, 3, trendEma) < 3) return 0;
   if(CopyBuffer(handleRSI, 0, 0, 3, rsi) < 3) return 0;
   if(CopyBuffer(handleMACD, 0, 0, 3, macdMain) < 3) return 0;
   if(CopyBuffer(handleMACD, 1, 0, 3, macdSig) < 3) return 0;
   if(CopyBuffer(handleATR, 0, 0, 3, atr) < 3) return 0;
   if(CopyBuffer(handleBB, 1, 0, 3, bbUpper) < 3) return 0;
   if(CopyBuffer(handleBB, 0, 0, 3, bbMid) < 3) return 0;
   if(CopyBuffer(handleBB, 2, 0, 3, bbLower) < 3) return 0;
   if(CopyBuffer(handleHTF_EMA, 0, 0, 3, htfEma) < 3) return 0;
   if(CopyBuffer(handleHTF_RSI, 0, 0, 3, htfRsi) < 3) return 0;
   if(CopyBuffer(handleVolume, 0, 0, 10, volume) < 10) return 0;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = _Point;
   
   int buyScore = 0;
   int sellScore = 0;
   
   // === 1. SMART MONEY CONCEPTS ANALYSIS ===
   if(InpUseSMC)
   {
      DetectOrderBlocks();
      DetectFairValueGaps();
      string phase = DetectMarketPhase(volume);
      marketPhase = phase;
      
      // Order Block scoring
      if(hasValidOB)
      {
         if(lastBullishOB.isBullish && bid >= lastBullishOB.lowPrice && bid <= lastBullishOB.highPrice)
         {
            buyScore += InpSMC_BonusScore;
            smcPattern = "Bullish OB ✅";
            if(InpDebugMode) Print("📊 SMC: Bullish Order Block detected");
         }
         if(!lastBearishOB.isBullish && ask >= lastBearishOB.lowPrice && ask <= lastBearishOB.highPrice)
         {
            sellScore += InpSMC_BonusScore;
            smcPattern = "Bearish OB ✅";
            if(InpDebugMode) Print("📊 SMC: Bearish Order Block detected");
         }
      }
      
      // Fair Value Gap scoring
      if(hasValidFVG)
      {
         if(lastFVG.isBullish && bid <= lastFVG.lowerPrice)
         {
            buyScore += 1;
            smcPattern += " + FVG";
         }
         if(!lastFVG.isBullish && ask >= lastFVG.upperPrice)
         {
            sellScore += 1;
            smcPattern += " + FVG";
         }
      }
      
      // Market Phase scoring
      if(phase == "ACCUMULATION" && InpUseAccumulation)
      {
         buyScore += 1;
         if(InpDebugMode) Print("📊 SMC: Accumulation phase detected");
      }
      else if(phase == "MANIPULATION" && InpUseManipulation)
      {
         // Manipulation favors reversal
         if(trendDirection == "DOWN") buyScore += 1;
         if(trendDirection == "UP") sellScore += 1;
      }
      else if(phase == "DISTRIBUTION" && InpUseDistribution)
      {
         sellScore += 1;
         if(InpDebugMode) Print("📊 SMC: Distribution phase detected");
      }
   }
   
   // === 2. EMA TREND ANALYSIS ===
   if(fastEma[1] > medEma[1] && medEma[1] > slowEma[1])
      buyScore += 2;
   else if(fastEma[1] < medEma[1] && medEma[1] < slowEma[1])
      sellScore += 2;
   
   // EMA crossover
   if(fastEma[1] > medEma[1] && fastEma[2] <= medEma[2]) buyScore++;
   if(fastEma[1] < medEma[1] && fastEma[2] >= medEma[2]) sellScore++;
   
   // Trend EMA 200
   if(bid > trendEma[1]) buyScore++;
   else sellScore++;
   
   // === 3. RSI ANALYSIS ===
   if(rsi[1] > 40 && rsi[1] < InpRSI_Overbought) buyScore++;
   if(rsi[1] < 60 && rsi[1] > InpRSI_Oversold) sellScore++;
   
   // RSI reversal
   if(rsi[2] < InpRSI_Oversold && rsi[1] > InpRSI_Oversold) buyScore++;
   if(rsi[2] > InpRSI_Overbought && rsi[1] < InpRSI_Overbought) sellScore++;
   
   // === 4. MACD ANALYSIS ===
   if(macdMain[1] > macdSig[1] && macdMain[1] > 0) buyScore++;
   if(macdMain[1] < macdSig[1] && macdMain[1] < 0) sellScore++;
   
   // MACD crossover
   if(macdMain[1] > macdSig[1] && macdMain[2] <= macdSig[2]) buyScore++;
   if(macdMain[1] < macdSig[1] && macdMain[2] >= macdSig[2]) sellScore++;
   
   // === 5. BOLLINGER BANDS ===
   if(bid < bbLower[1]) buyScore++;
   if(ask > bbUpper[1]) sellScore++;
   
   if(bid > bbMid[1]) buyScore++;
   else sellScore++;
   
   // === 6. HIGHER TIMEFRAME CONFIRMATION ===
   if(ask > htfEma[1]) buyScore++;
   else sellScore++;
   
   if(htfRsi[1] < 50) buyScore++;
   else if(htfRsi[1] > 50) sellScore++;
   
   confluenceScore = MathMax(buyScore, sellScore);
   int scoreDiff = MathAbs(buyScore - sellScore);
   
   // === DECISION LOGIC ===
   int requiredScore = isCoolDownActive ? InpOverrideScore : InpMinConfluence;
   
   if(buyScore >= requiredScore && scoreDiff >= InpMinScoreDiff && buyScore > sellScore)
   {
      lastSignal = "BUY ✅ (" + IntegerToString(buyScore) + "/10)";
      return 1;
   }
   
   if(sellScore >= requiredScore && scoreDiff >= InpMinScoreDiff && sellScore > buyScore)
   {
      lastSignal = "SELL ✅ (" + IntegerToString(sellScore) + "/10)";
      return -1;
   }
   
   lastSignal = "No Signal (B:" + IntegerToString(buyScore) + " S:" + IntegerToString(sellScore) + ")";
   return 0;
}


//============================================================
// DETECT ORDER BLOCKS (SMART MONEY FOOTPRINTS)
//============================================================
void DetectOrderBlocks()
{
   double highs[], lows[], opens[], closes[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(opens, true);
   ArraySetAsSeries(closes, true);
   
   int bars = InpOrderBlockBars + 5;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, highs) < bars) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, lows) < bars) return;
   if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, bars, opens) < bars) return;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, bars, closes) < bars) return;
   
   // Scan for bullish order block (last down candle before strong up move)
   for(int i = 2; i < InpOrderBlockBars; i++)
   {
      // Bearish candle (order block candle)
      if(closes[i] < opens[i])
      {
         // Check if followed by strong bullish move
         double upMove = 0;
         for(int j = i - 1; j >= MathMax(0, i - 3); j--)
         {
            if(closes[j] > opens[j])
               upMove += (closes[j] - opens[j]);
         }
         
         double obSize = (opens[i] - closes[i]);
         if(upMove > obSize * 2) // Strong rejection
         {
            lastBullishOB.time = iTime(_Symbol, PERIOD_CURRENT, i);
            lastBullishOB.highPrice = highs[i];
            lastBullishOB.lowPrice = lows[i];
            lastBullishOB.isBullish = true;
            lastBullishOB.strength = (int)(upMove / obSize);
            hasValidOB = true;
            if(InpDebugMode) Print("📦 Bullish Order Block found at bar ", i);
            break;
         }
      }
   }
   
   // Scan for bearish order block (last up candle before strong down move)
   for(int i = 2; i < InpOrderBlockBars; i++)
   {
      if(closes[i] > opens[i])
      {
         double downMove = 0;
         for(int j = i - 1; j >= MathMax(0, i - 3); j--)
         {
            if(closes[j] < opens[j])
               downMove += (opens[j] - closes[j]);
         }
         
         double obSize = (closes[i] - opens[i]);
         if(downMove > obSize * 2)
         {
            lastBearishOB.time = iTime(_Symbol, PERIOD_CURRENT, i);
            lastBearishOB.highPrice = highs[i];
            lastBearishOB.lowPrice = lows[i];
            lastBearishOB.isBullish = false;
            lastBearishOB.strength = (int)(downMove / obSize);
            hasValidOB = true;
            if(InpDebugMode) Print("📦 Bearish Order Block found at bar ", i);
            break;
         }
      }
   }
}

//============================================================
// DETECT FAIR VALUE GAPS (IMBALANCES)
//============================================================
void DetectFairValueGaps()
{
   double highs[5], lows[5];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 5, highs) < 5) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 5, lows) < 5) return;
   
   double point = _Point;
   
   // Bullish FVG: Gap between bar[2].high and bar[0].low
   double bullishGap = lows[0] - highs[2];
   if(bullishGap > InpFVG_MinPoints * point)
   {
      lastFVG.time = iTime(_Symbol, PERIOD_CURRENT, 1);
      lastFVG.upperPrice = lows[0];
      lastFVG.lowerPrice = highs[2];
      lastFVG.isBullish = true;
      hasValidFVG = true;
      if(InpDebugMode) Print("📊 Bullish FVG detected: ", bullishGap / point, " points");
   }
   
   // Bearish FVG: Gap between bar[2].low and bar[0].high
   double bearishGap = lows[2] - highs[0];
   if(bearishGap > InpFVG_MinPoints * point)
   {
      lastFVG.time = iTime(_Symbol, PERIOD_CURRENT, 1);
      lastFVG.upperPrice = lows[2];
      lastFVG.lowerPrice = highs[0];
      lastFVG.isBullish = false;
      hasValidFVG = true;
      if(InpDebugMode) Print("📊 Bearish FVG detected: ", bearishGap / point, " points");
   }
}

//============================================================
// DETECT MARKET PHASE (WYCKOFF METHOD)
//============================================================
string DetectMarketPhase(const long &volume[])
{
   // Calculate average volume
   double avgVol = 0;
   for(int i = 1; i < 10; i++) avgVol += volume[i];
   avgVol /= 9;
   
   double currentVol = (double)volume[0];
   double recentVol = (double)((volume[1] + volume[2]) / 2.0);
   
   double highs[20], lows[20], closes[20];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(closes, true);
   
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 20, highs) < 20) return "UNKNOWN";
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 20, lows) < 20) return "UNKNOWN";
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 20, closes) < 20) return "UNKNOWN";
   
   // Calculate volatility (ATR-like)
   double volatility = 0;
   for(int i = 0; i < 10; i++)
      volatility += (highs[i] - lows[i]);
   volatility /= 10;
   
   // ACCUMULATION: Low volatility + Low volume + Ranging price
   double priceRange = highs[0] - lows[0];
   for(int i = 1; i < 10; i++)
   {
      if(highs[i] > highs[0]) highs[0] = highs[i];
      if(lows[i] < lows[0]) lows[0] = lows[i];
   }
   double rangeWidth = highs[0] - lows[0];
   
   if(currentVol < avgVol * 0.8 && volatility < rangeWidth * 0.3)
      return "ACCUMULATION";
   
   // MANIPULATION: Volume spike + Price rejection (fake breakout)
   bool volumeSpike = (currentVol > avgVol * InpVolSpikeThreshold);
   bool priceRejection = false;
   
   // Check for rejection candle (long wick)
   double bodySize = MathAbs(closes[1] - iOpen(_Symbol, PERIOD_CURRENT, 1));
   double upperWick = highs[1] - MathMax(closes[1], iOpen(_Symbol, PERIOD_CURRENT, 1));
   double lowerWick = MathMin(closes[1], iOpen(_Symbol, PERIOD_CURRENT, 1)) - lows[1];
   
   if(upperWick > bodySize * 2 || lowerWick > bodySize * 2)
      priceRejection = true;
   
   if(volumeSpike && priceRejection)
      return "MANIPULATION";
   
   // DISTRIBUTION: High volatility + High volume + Trending
   if(currentVol > avgVol * 1.5 && volatility > rangeWidth * 0.5)
      return "DISTRIBUTION";
   
   return "NEUTRAL";
}

//============================================================
// EXECUTE TRADE WITH REAL COST ADJUSTMENT
//============================================================
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = _Point;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // Calculate SL/TP
   double slPoints, tpPoints;
   
   if(InpUseATR_SLTP)
   {
      double atrBuf[1];
      if(CopyBuffer(handleATR, 0, 1, 1, atrBuf) < 1) return;
      slPoints = atrBuf[0] * InpATR_SL_Multi;
      tpPoints = atrBuf[0] * InpATR_TP_Multi;
   }
   else
   {
      slPoints = InpSL_Points * point;
      tpPoints = InpTP_Points * point;
   }
   
   // Adjust for minimum stop level
   double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   if(slPoints < minStop * 2) slPoints = minStop * 2;
   if(tpPoints < minStop * 2) tpPoints = minStop * 2;
   
   double entryPrice, sl, tp;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      entryPrice = ask;
      sl = NormalizeDouble(entryPrice - slPoints, digits);
      tp = NormalizeDouble(entryPrice + tpPoints, digits);
   }
   else
   {
      entryPrice = bid;
      sl = NormalizeDouble(entryPrice + slPoints, digits);
      tp = NormalizeDouble(entryPrice - tpPoints, digits);
   }
   
   // Calculate lot size
   double lotSize = CalculateLotSize(slPoints);
   if(lotSize <= 0)
   {
      if(InpDebugMode) Print("❌ Lot size calculation failed");
      return;
   }
   
   // === ADJUST TP FOR SPREAD & COMMISSION ===
   if(InpAdjustTP_For_Cost)
   {
      double spread = (ask - bid);
      double commission = InpCommissionPerLot * lotSize;
      double totalCost = spread + (commission / lotSize); // Cost per unit
      
      if(orderType == ORDER_TYPE_BUY)
         tp = NormalizeDouble(tp + totalCost, digits);
      else
         tp = NormalizeDouble(tp - totalCost, digits);
      
      totalSpreadCost += spread * lotSize;
      totalCommission += commission;
      
      if(InpDebugMode) Print("💸 Cost adjustment: Spread=", spread, " Comm=$", commission);
   }
   
   // Send order
   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
      result = trade.Buy(lotSize, _Symbol, entryPrice, sl, tp, InpTradeComment);
   else
      result = trade.Sell(lotSize, _Symbol, entryPrice, sl, tp, InpTradeComment);
   
   if(result)
   {
      string dir = (orderType == ORDER_TYPE_BUY) ? "BUY ✅" : "SELL ✅";
      Print("═══════════════════════════════════════");
      Print("🚀 TRADE OPENED: ", dir);
      Print("   Symbol: ", _Symbol);
      Print("   Lot: ", lotSize);
      Print("   Entry: ", entryPrice);
      Print("   SL: ", sl, " | TP: ", tp);
      Print("   Score: ", confluenceScore, "/10");
      Print("   SMC: ", smcPattern);
      Print("   Phase: ", marketPhase);
      Print("═══════════════════════════════════════");
      
      if(InpEnableAlerts)
         Alert("ProSmart v6.0 | ", dir, " | ", _Symbol, " | Score: ", confluenceScore);
   }
   else
   {
      Print("❌ Trade failed! Error: ", GetLastError());
   }
}

//============================================================
// CALCULATE LOT SIZE WITH RISK MANAGEMENT
//============================================================
double CalculateLotSize(double slPoints)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(tickValue == 0 || tickSize == 0 || slPoints == 0) return minLot;
   
   // Micro account mode
   if(balance <= InpMicroBalanceUSD) return minLot;
   
   // Calculate risk amount
   double riskAmount = balance * (InpRiskPercent / 100.0);
   
   // Calculate lot size
   double slInTicks = slPoints / tickSize;
   double lotSize = riskAmount / (slInTicks * tickValue);
   
   // Apply limits
   lotSize = MathMin(lotSize, InpMaxLotSize);
   lotSize = MathMin(lotSize, maxLot);
   lotSize = MathMax(lotSize, InpMinLotSize);
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   if(InpDebugMode)
      Print("💰 Lot calc: Risk=$", riskAmount, " SL=", slPoints, " → Lot=", lotSize);
   
   return NormalizeDouble(lotSize, 2);
}


//============================================================
// MANAGE OPEN POSITIONS (TRAILING, BREAKEVEN, MAX HOLD TIME)
//============================================================
void ManageOpenPositions()
{
   double point = _Point;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != _Symbol) continue;
      
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double currentTP = posInfo.TakeProfit();
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      ulong ticket = posInfo.Ticket();
      datetime openTime = posInfo.Time();
      
      // === MAX HOLD TIME CHECK ===
      if(InpMaxHoldHours > 0)
      {
         datetime currentTime = TimeCurrent();
         int hoursOpen = (int)((currentTime - openTime) / 3600);
         
         if(hoursOpen >= InpMaxHoldHours)
         {
            Print("⏰ Max hold time reached (", hoursOpen, "h). Closing position #", ticket);
            trade.PositionClose(ticket);
            continue;
         }
      }
      
      // === POSITION MANAGEMENT ===
      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double profit = bid - openPrice;
         double profitPoints = profit / point;
         
         // Breakeven
         if(InpUseBE && profitPoints >= InpBE_Activate)
         {
            double newSL = NormalizeDouble(openPrice + (point * 10), digits);
            if(currentSL < openPrice)
            {
               trade.PositionModify(ticket, newSL, currentTP);
               if(InpDebugMode) Print("🎯 Breakeven activated for #", ticket);
            }
         }
         
         // Trailing Stop
         if(InpUseTrailing && profitPoints >= InpTrailStart)
         {
            double newSL = NormalizeDouble(bid - (InpTrailStart * point), digits);
            if(newSL > currentSL + (InpTrailStep * point))
            {
               trade.PositionModify(ticket, newSL, currentTP);
               if(InpDebugMode) Print("📈 Trailing stop updated for #", ticket);
            }
         }
      }
      else if(posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double profit = openPrice - ask;
         double profitPoints = profit / point;
         
         // Breakeven
         if(InpUseBE && profitPoints >= InpBE_Activate)
         {
            double newSL = NormalizeDouble(openPrice - (point * 10), digits);
            if(currentSL > openPrice || currentSL == 0)
            {
               trade.PositionModify(ticket, newSL, currentTP);
               if(InpDebugMode) Print("🎯 Breakeven activated for #", ticket);
            }
         }
         
         // Trailing Stop
         if(InpUseTrailing && profitPoints >= InpTrailStart)
         {
            double newSL = NormalizeDouble(ask + (InpTrailStart * point), digits);
            if(newSL < currentSL - (InpTrailStep * point) || currentSL == 0)
            {
               trade.PositionModify(ticket, newSL, currentTP);
               if(InpDebugMode) Print("📉 Trailing stop updated for #", ticket);
            }
         }
      }
   }
}

//============================================================
// COOL-DOWN STATUS CHECK
//============================================================
void CheckCoolDownStatus()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyLossLimit = dailyStartBalance * (InpMaxDailyLoss / 100.0);
   double dailyLoss = dailyStartBalance - balance;
   
   // Activate cool-down if daily loss limit hit
   if(dailyLoss >= dailyLossLimit && !isCoolDownActive)
   {
      isCoolDownActive = true;
      coolDownUntil = TimeCurrent() + (InpCoolDownHours * 3600);
      Print("╔═══════════════════════════════════════╗");
      Print("║   ⚠️  DAILY LOSS LIMIT REACHED!      ║");
      Print("║   Robot entering COOL-DOWN mode       ║");
      Print("║   Duration: ", InpCoolDownHours, " hours                 ║");
      Print("║   Resume at: ", coolDownUntil, "    ║");
      Print("╚═══════════════════════════════════════╝");
   }
   
   // Check for profit lock
   if(dailyProfit >= dailyStartBalance * (InpMaxDailyProfit / 100.0))
   {
      Print("✅ Daily profit target reached! Locking profits for today.");
      isCoolDownActive = true;
      coolDownUntil = GetEndOfDay();
   }
   
   // Deactivate cool-down if time expired
   if(isCoolDownActive && TimeCurrent() >= coolDownUntil)
   {
      isCoolDownActive = false;
      coolDownUntil = 0;
      Print("✅ Cool-down period ended. Robot resumed normal operation.");
   }
}

//============================================================
// UPDATE DAILY STATISTICS
//============================================================
void UpdateDailyStats()
{
   MqlDateTime dt, lastDt;
   TimeToStruct(TimeCurrent(), dt);
   TimeToStruct(lastDayReset, lastDt);
   
   if(dt.day != lastDt.day)
   {
      // New day - reset statistics
      dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      lastDayReset = TimeCurrent();
      winTrades = 0;
      lossTrades = 0;
      totalPnL = 0;
      totalCommission = 0;
      totalSpreadCost = 0;
      isCoolDownActive = false;
      coolDownUntil = 0;
      FetchNewsFromCalendar();
      
      Print("╔═══════════════════════════════════════╗");
      Print("║      🌅 NEW TRADING DAY STARTED       ║");
      Print("║   Robot statistics have been reset    ║");
      Print("╚═══════════════════════════════════════╝");
   }
   
   dailyProfit = AccountInfoDouble(ACCOUNT_BALANCE) - dailyStartBalance;
}

//============================================================
// TRADE TRANSACTION HANDLER
//============================================================
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
         double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
         double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
         
         if(profit != 0)
         {
            totalPnL += profit;
            totalCommission += MathAbs(commission);
            
            if(profit > 0)
            {
               winTrades++;
               Print("✅ WIN Trade | P&L: $", profit, " | Comm: $", MathAbs(commission));
            }
            else
            {
               lossTrades++;
               Print("❌ LOSS Trade | P&L: $", profit, " | Comm: $", MathAbs(commission));
            }
         }
      }
   }
}

//============================================================
// HELPER FUNCTIONS
//============================================================
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == _Symbol)
         count++;
   }
   return count;
}

bool CheckSpreadFilter()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (ask - bid) / _Point;
   
   if(spread > InpMaxSpreadPoints)
   {
      if(InpDebugMode) Print("⚠️ Spread too wide: ", spread, " points");
      return false;
   }
   
   return true;
}

bool IsMarketSessionOpen()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dow = dt.day_of_week;
   
   // Weekend filter
   if(InpNoWeekend && (dow == 0 || dow == 6))
   {
      sessionStatus = "WEEKEND CLOSED ✗";
      return false;
   }
   
   // Friday close filter
   if(dow == 5)
   {
      int nowMin = dt.hour * 60 + dt.min;
      int closeMin = InpFridayCloseHour * 60 + InpFridayCloseMin;
      if(nowMin >= closeMin)
      {
         sessionStatus = "FRIDAY CLOSING ✗";
         return false;
      }
   }
   
   sessionStatus = "MARKET OPEN ✅";
   return true;
}

datetime GetEndOfDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 23;
   dt.min = 59;
   dt.sec = 59;
   return StructToTime(dt);
}

//============================================================
// NEWS FILTER - CALENDAR API
//============================================================
void FetchNewsFromCalendar()
{
   newsCacheCount = 0;
   ArrayResize(newsCache, 0);
   
   datetime now = TimeCurrent();
   MqlCalendarValue values[];
   
   int count = CalendarValueHistory(values, now - 3600, now + 172800);
   if(count <= 0)
   {
      newsStatus = "Calendar: No data";
      lastNewsFetch = now;
      return;
   }
   
   string filterCurr[];
   int filterCount = StringSplit(InpNewsCurrencies, ',', filterCurr);
   
   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event)) continue;
      
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country)) continue;
      
      int impact = 0;
      if(event.importance == CALENDAR_IMPORTANCE_HIGH) impact = 3;
      if(event.importance == CALENDAR_IMPORTANCE_MODERATE) impact = 2;
      if(event.importance == CALENDAR_IMPORTANCE_LOW) impact = 1;
      
      bool shouldFilter = false;
      if(InpFilterHighImpact && impact == 3) shouldFilter = true;
      if(InpFilterMedImpact && impact == 2) shouldFilter = true;
      if(!shouldFilter) continue;
      
      bool currMatch = false;
      for(int c = 0; c < filterCount; c++)
      {
         string fc = filterCurr[c];
         StringTrimLeft(fc);
         StringTrimRight(fc);
         if(fc == country.currency || fc == "ALL")
         {
            currMatch = true;
            break;
         }
      }
      if(!currMatch) continue;
      
      int idx = newsCacheCount;
      ArrayResize(newsCache, idx + 1);
      newsCache[idx].eventTime = values[i].time;
      newsCache[idx].currency = country.currency;
      newsCache[idx].title = event.name;
      newsCache[idx].impact = impact;
      newsCacheCount++;
   }
   
   lastNewsFetch = now;
   newsStatus = "Calendar: " + IntegerToString(newsCacheCount) + " events";
}

bool IsNewsTime()
{
   if(newsCacheCount == 0) return false;
   
   datetime now = TimeCurrent();
   for(int i = 0; i < newsCacheCount; i++)
   {
      datetime t = newsCache[i].eventTime;
      if(now >= t - (InpNewsMinsBefore * 60) && now <= t + (InpNewsMinsAfter * 60))
      {
         newsStatus = "⛔ NEWS: " + newsCache[i].title;
         return true;
      }
   }
   
   newsStatus = "✅ No news";
   return false;
}


//============================================================
// DASHBOARD - REAL-TIME MONITORING
//============================================================
void DrawDashboard()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   int pos = CountMyPositions();
   int total = winTrades + lossTrades;
   double wr = (total > 0) ? (double)winTrades / total * 100.0 : 0.0;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string timeStr = StringFormat("%02d:%02d  %02d.%02d.%d", dt.hour, dt.min, dt.day, dt.mon, dt.year);
   
   // Mode indicator
   string modeStr = "";
   if(isCoolDownActive)
   {
      int remainMin = (int)((coolDownUntil - TimeCurrent()) / 60);
      modeStr = "⛔ COOL-DOWN (" + IntegerToString(remainMin) + " min)";
   }
   else
   {
      modeStr = (balance <= InpMicroBalanceUSD) ? "⚠️ MICRO MODE" : "✅ ACTIVE";
   }
   
   // Daily profit status
   string profitStatus = "";
   double profitPct = (dailyStartBalance > 0) ? (dailyProfit / dailyStartBalance * 100.0) : 0;
   if(profitPct >= 3.0) profitStatus = "🔥 GREAT!";
   else if(profitPct >= 1.0) profitStatus = "✅ GOOD";
   else if(profitPct >= 0) profitStatus = "➡️ OK";
   else if(profitPct >= -2.0) profitStatus = "⚠️ WATCH";
   else profitStatus = "❌ DANGER";
   
   // Net P&L after costs
   double netPnL = totalPnL - totalCommission - totalSpreadCost;
   
   string info = "";
   info += "╔═══════════════════════════════════════════════╗\n";
   info += "║   ProSmartScalper AI v6.0 ULTIMATE - SMC     ║\n";
   info += "╠═══════════════════════════════════════════════╣\n";
   info += "║ " + _Symbol + " " + EnumToString(Period()) + "    " + timeStr + "\n";
   info += "║ Status: " + modeStr + "\n";
   info += "╠═══════════════════════════════════════════════╣\n";
   info += "║ 💰 ACCOUNT STATUS\n";
   info += "║ Balance   : $" + DoubleToString(balance, 2) + "\n";
   info += "║ Equity    : $" + DoubleToString(equity, 2) + "\n";
   info += "║ Day P&L   : $" + DoubleToString(dailyProfit, 2) + " (" + DoubleToString(profitPct, 1) + "%) " + profitStatus + "\n";
   info += "╠═══════════════════════════════════════════════╣\n";
   info += "║ 🎯 SIGNAL STATUS\n";
   info += "║ Signal    : " + lastSignal + "\n";
   info += "║ SMC       : " + smcPattern + "\n";
   info += "║ Phase     : " + marketPhase + "\n";
   info += "║ Score     : " + IntegerToString(confluenceScore) + "/10\n";
   info += "╠═══════════════════════════════════════════════╣\n";
   info += "║ 📊 MARKET INFO\n";
   info += "║ " + newsStatus + "\n";
   info += "║ " + sessionStatus + "\n";
   
   // Spread info
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   info += "║ Spread    : " + DoubleToString(spread, 1) + " points\n";
   
   info += "╠═══════════════════════════════════════════════╣\n";
   info += "║ 📈 PERFORMANCE\n";
   info += "║ Positions : " + IntegerToString(pos) + "/" + IntegerToString(InpMaxPositions) + "\n";
   info += "║ Trades    : " + IntegerToString(total) + " (W:" + IntegerToString(winTrades) + " L:" + IntegerToString(lossTrades) + ")\n";
   info += "║ Win Rate  : " + DoubleToString(wr, 1) + "%\n";
   info += "║ Gross P&L : $" + DoubleToString(totalPnL, 2) + "\n";
   info += "║ Commission: $" + DoubleToString(totalCommission, 2) + "\n";
   info += "║ Spread    : $" + DoubleToString(totalSpreadCost, 2) + "\n";
   info += "║ Net P&L   : $" + DoubleToString(netPnL, 2) + "\n";
   info += "╠═══════════════════════════════════════════════╣\n";
   info += "║ ⚙️  SETTINGS\n";
   info += "║ Risk      : " + DoubleToString(InpRiskPercent, 1) + "% per trade\n";
   info += "║ Min Score : " + IntegerToString(InpMinConfluence) + " (Normal) | " + IntegerToString(InpOverrideScore) + " (Override)\n";
   info += "║ Max Loss  : " + DoubleToString(InpMaxDailyLoss, 1) + "% daily\n";
   info += "║ SMC Mode  : " + (InpUseSMC ? "ENABLED ✅" : "DISABLED") + "\n";
   info += "╚═══════════════════════════════════════════════╝\n";
   
   Comment(info);
}

//+------------------------------------------------------------------+
//| END OF EXPERT ADVISOR                                             |
//+------------------------------------------------------------------+
