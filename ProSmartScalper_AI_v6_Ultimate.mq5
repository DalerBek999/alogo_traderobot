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
// INPUT PARAMETERS
//============================================================
input group "=== RISK MANAGEMENT ==="
input double   InpRiskPercent      = 0.8;
input double   InpMaxDailyLoss     = 3.0;
input double   InpMaxDailyProfit   = 8.0;
input int      InpCoolDownHours    = 4;
input int      InpOverrideScore    = 8;
input int      InpMaxPositions     = 1;
input double   InpMaxLotSize       = 2.0;
input double   InpMinLotSize       = 0.01;
input double   InpMicroBalanceUSD  = 100.0;

input group "=== SMART MONEY CONCEPTS (SMC) ==="
input bool     InpUseSMC           = true;
input int      InpOrderBlockBars   = 20;
input int      InpFVG_MinPoints    = 30;
input int      InpBOS_ConfirmBars  = 3;
input bool     InpUseAccumulation  = true;
input bool     InpUseManipulation  = true;
input bool     InpUseDistribution  = true;
input double   InpVolSpikeThreshold= 1.5;
input int      InpSMC_HTF_Period   = PERIOD_H4;

input group "=== SL/TP & POSITION MANAGEMENT ==="
input int      InpSL_Points        = 200;
input int      InpTP_Points        = 400;
input bool     InpUseATR_SLTP      = true;
input double   InpATR_SL_Multi     = 1.2;
input double   InpATR_TP_Multi     = 2.5;
input bool     InpUseTrailing      = true;
input int      InpTrailStart       = 150;
input int      InpTrailStep        = 40;
input bool     InpUseBE            = true;
input int      InpBE_Activate      = 100;
input int      InpMaxHoldHours     = 24;

input group "=== MULTI-INDICATOR CONFLUENCE ==="
input int      InpFastEMA          = 8;
input int      InpMediumEMA        = 21;
input int      InpSlowEMA          = 50;
input int      InpTrendEMA         = 200;
input int      InpRSI_Period       = 14;
input double   InpRSI_Oversold     = 30.0;
input double   InpRSI_Overbought   = 70.0;
input int      InpMACD_Fast        = 12;
input int      InpMACD_Slow        = 26;
input int      InpMACD_Signal      = 9;
input int      InpATR_Period       = 14;
input int      InpBB_Period        = 20;
input double   InpBB_Deviation     = 2.0;

input group "=== SPREAD & COMMISSION ==="
input double   InpMaxSpreadPoints  = 5.0;
input double   InpCommissionPerLot = 7.0;
input bool     InpAdjustTP_For_Cost= true;

input group "=== NEWS & SESSION FILTERS ==="
input bool     InpUseNewsFilter    = true;
input int      InpNewsMinsBefore   = 30;
input int      InpNewsMinsAfter    = 20;
input bool     InpFilterHighImpact = true;
input bool     InpFilterMedImpact  = true;
input string   InpNewsCurrencies   = "USD,EUR,GBP,XAU";
input bool     InpNoWeekend        = true;
input int      InpFridayCloseHour  = 23;
input int      InpFridayCloseMin   = 30;

input group "=== SIGNAL QUALITY ==="
input int      InpMinConfluence    = 6;
input int      InpSMC_BonusScore   = 2;
input int      InpMinScoreDiff     = 2;

input group "=== GENERAL ==="
input long     InpMagicNumber      = 202406;
input string   InpTradeComment     = "ProSmart_v6_SMC";
input bool     InpShowDashboard    = true;
input bool     InpEnableAlerts     = true;
input bool     InpDebugMode        = false;

//============================================================
// GLOBAL VARIABLES
//============================================================
CTrade        trade;
CPositionInfo posInfo;

int handleFastEMA, handleMedEMA, handleSlowEMA, handleTrendEMA;
int handleRSI, handleMACD, handleATR, handleBB;
int handleHTF_EMA, handleHTF_RSI;
// NOTE: No handleVolume -- volume read via CopyTickVolume()

double   dailyStartBalance  = 0;
double   dailyProfit        = 0;
datetime lastBarTime        = 0;
datetime lastDayReset       = 0;
int      winTrades          = 0;
int      lossTrades         = 0;
double   totalPnL           = 0;
double   totalCommission    = 0;
double   totalSpreadCost    = 0;

string   lastSignal         = "Initializing...";
string   marketPhase        = "Analyzing...";
string   smcPattern         = "None";
int      confluenceScore    = 0;
bool     newsBlocking       = false;
string   newsStatus         = "Checking...";
string   sessionStatus      = "-";

datetime coolDownUntil      = 0;
bool     isCoolDownActive   = false;

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

OrderBlock   lastBullishOB;
OrderBlock   lastBearishOB;
FairValueGap lastFVG;
bool hasValidOB  = false;
bool hasValidFVG = false;

double lastHigherHigh  = 0;
double lastHigherLow   = 0;
double lastLowerHigh   = 0;
double lastLowerLow    = 0;
string trendDirection  = "NEUTRAL";

struct NewsEvent
{
   datetime eventTime;
   string   currency;
   string   title;
   int      impact;
};
NewsEvent newsCache[];
datetime  lastNewsFetch  = 0;
int       newsCacheCount = 0;

//============================================================
// FORWARD DECLARATIONS
//============================================================
int    AnalyzeMarketWithSMC();
void   DetectOrderBlocks();
void   DetectFairValueGaps();
string DetectMarketPhase();
void   ExecuteTrade(ENUM_ORDER_TYPE orderType);
double CalculateLotSize(double slPoints);
void   ManageOpenPositions();
void   CheckCoolDownStatus();
void   UpdateDailyStats();
int    CountMyPositions();
bool   CheckSpreadFilter();
bool   IsMarketSessionOpen();
datetime GetEndOfDay();
void   FetchNewsFromCalendar();
bool   IsNewsTime();
void   DrawDashboard();

//============================================================
// OnInit
//============================================================
int OnInit()
{
   Print("=== ProSmartScalper AI v6.0 ULTIMATE - SMC Edition ===");

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.LogLevel(LOG_LEVEL_ERRORS);

   handleFastEMA  = iMA(_Symbol, PERIOD_CURRENT, InpFastEMA,   0, MODE_EMA, PRICE_CLOSE);
   handleMedEMA   = iMA(_Symbol, PERIOD_CURRENT, InpMediumEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleSlowEMA  = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMA,   0, MODE_EMA, PRICE_CLOSE);
   handleTrendEMA = iMA(_Symbol, PERIOD_CURRENT, InpTrendEMA,  0, MODE_EMA, PRICE_CLOSE);
   handleRSI      = iRSI(_Symbol, PERIOD_CURRENT, InpRSI_Period, PRICE_CLOSE);
   handleMACD     = iMACD(_Symbol, PERIOD_CURRENT, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, PRICE_CLOSE);
   handleATR      = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
   handleBB       = iBands(_Symbol, PERIOD_CURRENT, InpBB_Period, 0, InpBB_Deviation, PRICE_CLOSE);
   handleHTF_EMA  = iMA(_Symbol, (ENUM_TIMEFRAMES)InpSMC_HTF_Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleHTF_RSI  = iRSI(_Symbol, (ENUM_TIMEFRAMES)InpSMC_HTF_Period, InpRSI_Period, PRICE_CLOSE);

   if(handleFastEMA  == INVALID_HANDLE || handleMedEMA   == INVALID_HANDLE ||
      handleSlowEMA  == INVALID_HANDLE || handleTrendEMA == INVALID_HANDLE ||
      handleRSI      == INVALID_HANDLE || handleMACD     == INVALID_HANDLE ||
      handleATR      == INVALID_HANDLE || handleBB       == INVALID_HANDLE ||
      handleHTF_EMA  == INVALID_HANDLE || handleHTF_RSI  == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicators!");
      return INIT_FAILED;
   }

   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   lastDayReset      = TimeCurrent();

   FetchNewsFromCalendar();

   Print("Robot initialized. Balance=$", dailyStartBalance,
         "  Risk=", InpRiskPercent, "%  SMC=", (InpUseSMC ? "ON" : "OFF"));
   return INIT_SUCCEEDED;
}

//============================================================
// OnDeinit
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
   Comment("");
   Print("Robot stopped. Total P&L: $", totalPnL);
}

//============================================================
// OnTick
//============================================================
void OnTick()
{
   UpdateDailyStats();
   ManageOpenPositions();

   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBar == lastBarTime) return;
   lastBarTime = currentBar;

   if(TimeCurrent() - lastNewsFetch > 3600)
      FetchNewsFromCalendar();

   CheckCoolDownStatus();

   if(InpShowDashboard) DrawDashboard();

   if(!IsMarketSessionOpen()) return;
   if(InpUseNewsFilter && IsNewsTime()) return;
   if(!CheckSpreadFilter()) return;

   newsBlocking = false;

   if(CountMyPositions() >= InpMaxPositions) return;

   int signal = AnalyzeMarketWithSMC();

   bool canTrade = false;
   if(!isCoolDownActive)
      canTrade = true;
   else if(isCoolDownActive && confluenceScore >= InpOverrideScore)
   {
      Print("PERFECT SIGNAL OVERRIDE! Score:", confluenceScore, "/10");
      canTrade = true;
   }

   if(canTrade)
   {
      if(signal ==  1) ExecuteTrade(ORDER_TYPE_BUY);
      if(signal == -1) ExecuteTrade(ORDER_TYPE_SELL);
   }
}

//============================================================
// AnalyzeMarketWithSMC
// FIX: volume read via CopyTickVolume() with dynamic long[] array
//============================================================
int AnalyzeMarketWithSMC()
{
   // All CopyBuffer arrays must be dynamic (not fixed-size)
   double fastEma[], medEma[], slowEma[], trendEma[];
   double rsiArr[], macdMain[], macdSig[], atrArr[];
   double bbUpper[], bbMid[], bbLower[];
   double htfEma[], htfRsi[];

   ArraySetAsSeries(fastEma,  true); ArraySetAsSeries(medEma,   true);
   ArraySetAsSeries(slowEma,  true); ArraySetAsSeries(trendEma, true);
   ArraySetAsSeries(rsiArr,   true); ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSig,  true); ArraySetAsSeries(atrArr,   true);
   ArraySetAsSeries(bbUpper,  true); ArraySetAsSeries(bbMid,    true);
   ArraySetAsSeries(bbLower,  true); ArraySetAsSeries(htfEma,   true);
   ArraySetAsSeries(htfRsi,   true);

   if(CopyBuffer(handleFastEMA,  0, 0, 3, fastEma)  < 3) return 0;
   if(CopyBuffer(handleMedEMA,   0, 0, 3, medEma)   < 3) return 0;
   if(CopyBuffer(handleSlowEMA,  0, 0, 3, slowEma)  < 3) return 0;
   if(CopyBuffer(handleTrendEMA, 0, 0, 3, trendEma) < 3) return 0;
   if(CopyBuffer(handleRSI,      0, 0, 3, rsiArr)   < 3) return 0;
   if(CopyBuffer(handleMACD,     0, 0, 3, macdMain) < 3) return 0;
   if(CopyBuffer(handleMACD,     1, 0, 3, macdSig)  < 3) return 0;
   if(CopyBuffer(handleATR,      0, 0, 3, atrArr)   < 3) return 0;
   if(CopyBuffer(handleBB,       1, 0, 3, bbUpper)  < 3) return 0;
   if(CopyBuffer(handleBB,       0, 0, 3, bbMid)    < 3) return 0;
   if(CopyBuffer(handleBB,       2, 0, 3, bbLower)  < 3) return 0;
   if(CopyBuffer(handleHTF_EMA,  0, 0, 3, htfEma)   < 3) return 0;
   if(CopyBuffer(handleHTF_RSI,  0, 0, 3, htfRsi)   < 3) return 0;

   // FIX: Volume - use CopyTickVolume() with dynamic long[] array
   long volArr[];
   ArraySetAsSeries(volArr, true);
   bool volOk = (CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 10, volArr) >= 10);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int buyScore  = 0;
   int sellScore = 0;

   // === 1. SMC ANALYSIS ===
   if(InpUseSMC)
   {
      DetectOrderBlocks();
      DetectFairValueGaps();
      string phase = DetectMarketPhase();
      marketPhase  = phase;

      if(hasValidOB)
      {
         if(lastBullishOB.isBullish && bid >= lastBullishOB.lowPrice && bid <= lastBullishOB.highPrice)
            { buyScore += InpSMC_BonusScore; smcPattern = "Bullish OB"; }
         if(!lastBearishOB.isBullish && ask >= lastBearishOB.lowPrice && ask <= lastBearishOB.highPrice)
            { sellScore += InpSMC_BonusScore; smcPattern = "Bearish OB"; }
      }

      if(hasValidFVG)
      {
         if( lastFVG.isBullish && bid <= lastFVG.lowerPrice)
            { buyScore  += 1; smcPattern += "+FVG"; }
         if(!lastFVG.isBullish && ask >= lastFVG.upperPrice)
            { sellScore += 1; smcPattern += "+FVG"; }
      }

      if(phase == "ACCUMULATION"  && InpUseAccumulation)  buyScore  += 1;
      if(phase == "DISTRIBUTION"  && InpUseDistribution)  sellScore += 1;
      if(phase == "MANIPULATION"  && InpUseManipulation)
      {
         if(trendDirection == "DOWN") buyScore  += 1;
         if(trendDirection == "UP")   sellScore += 1;
      }
   }

   // === 2. EMA TREND ===
   if(fastEma[1] > medEma[1] && medEma[1] > slowEma[1])       buyScore  += 2;
   else if(fastEma[1] < medEma[1] && medEma[1] < slowEma[1])  sellScore += 2;

   if(fastEma[1] > medEma[1] && fastEma[2] <= medEma[2]) buyScore  += 1;
   if(fastEma[1] < medEma[1] && fastEma[2] >= medEma[2]) sellScore += 1;

   if(bid > trendEma[1]) buyScore  += 1;
   else                  sellScore += 1;

   // === 3. RSI ===
   if(rsiArr[1] > 40 && rsiArr[1] < InpRSI_Overbought) buyScore  += 1;
   if(rsiArr[1] < 60 && rsiArr[1] > InpRSI_Oversold)   sellScore += 1;

   if(rsiArr[2] < InpRSI_Oversold   && rsiArr[1] > InpRSI_Oversold)   buyScore  += 1;
   if(rsiArr[2] > InpRSI_Overbought && rsiArr[1] < InpRSI_Overbought) sellScore += 1;

   // === 4. MACD ===
   if(macdMain[1] > macdSig[1] && macdMain[1] > 0) buyScore  += 1;
   if(macdMain[1] < macdSig[1] && macdMain[1] < 0) sellScore += 1;

   if(macdMain[1] > macdSig[1] && macdMain[2] <= macdSig[2]) buyScore  += 1;
   if(macdMain[1] < macdSig[1] && macdMain[2] >= macdSig[2]) sellScore += 1;

   // === 5. BOLLINGER BANDS ===
   if(bid < bbLower[1]) buyScore  += 1;
   if(ask > bbUpper[1]) sellScore += 1;
   if(bid > bbMid[1])   buyScore  += 1;
   else                 sellScore += 1;

   // === 6. HTF CONFIRMATION ===
   if(ask > htfEma[1])     buyScore  += 1;
   else                    sellScore += 1;
   if(htfRsi[1] < 50)      buyScore  += 1;
   else if(htfRsi[1] > 50) sellScore += 1;

   confluenceScore = MathMax(buyScore, sellScore);
   int scoreDiff   = MathAbs(buyScore - sellScore);
   int reqScore    = isCoolDownActive ? InpOverrideScore : InpMinConfluence;

   if(buyScore >= reqScore && scoreDiff >= InpMinScoreDiff && buyScore > sellScore)
   {
      lastSignal = "BUY (" + IntegerToString(buyScore) + "/10)";
      return 1;
   }
   if(sellScore >= reqScore && scoreDiff >= InpMinScoreDiff && sellScore > buyScore)
   {
      lastSignal = "SELL (" + IntegerToString(sellScore) + "/10)";
      return -1;
   }

   lastSignal = "No Signal (B:" + IntegerToString(buyScore) + " S:" + IntegerToString(sellScore) + ")";
   return 0;
}

//============================================================
// DetectOrderBlocks - FIX: dynamic arrays
//============================================================
void DetectOrderBlocks()
{
   double highs[], lows[], opens[], closes[];
   ArraySetAsSeries(highs,  true);
   ArraySetAsSeries(lows,   true);
   ArraySetAsSeries(opens,  true);
   ArraySetAsSeries(closes, true);

   int bars = InpOrderBlockBars + 5;
   if(CopyHigh (_Symbol, PERIOD_CURRENT, 0, bars, highs)  < bars) return;
   if(CopyLow  (_Symbol, PERIOD_CURRENT, 0, bars, lows)   < bars) return;
   if(CopyOpen (_Symbol, PERIOD_CURRENT, 0, bars, opens)  < bars) return;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, bars, closes) < bars) return;

   for(int i = 2; i < InpOrderBlockBars; i++)
   {
      if(closes[i] < opens[i])
      {
         double upMove = 0;
         for(int j = i-1; j >= MathMax(0, i-3); j--)
            if(closes[j] > opens[j]) upMove += closes[j] - opens[j];

         double obSize = opens[i] - closes[i];
         if(obSize > 0 && upMove > obSize * 2)
         {
            lastBullishOB.time      = iTime(_Symbol, PERIOD_CURRENT, i);
            lastBullishOB.highPrice = highs[i];
            lastBullishOB.lowPrice  = lows[i];
            lastBullishOB.isBullish = true;
            lastBullishOB.strength  = (int)(upMove / obSize);
            hasValidOB = true;
            break;
         }
      }
   }

   for(int i = 2; i < InpOrderBlockBars; i++)
   {
      if(closes[i] > opens[i])
      {
         double downMove = 0;
         for(int j = i-1; j >= MathMax(0, i-3); j--)
            if(closes[j] < opens[j]) downMove += opens[j] - closes[j];

         double obSize = closes[i] - opens[i];
         if(obSize > 0 && downMove > obSize * 2)
         {
            lastBearishOB.time      = iTime(_Symbol, PERIOD_CURRENT, i);
            lastBearishOB.highPrice = highs[i];
            lastBearishOB.lowPrice  = lows[i];
            lastBearishOB.isBullish = false;
            lastBearishOB.strength  = (int)(downMove / obSize);
            hasValidOB = true;
            break;
         }
      }
   }
}

//============================================================
// DetectFairValueGaps - FIX: dynamic arrays
//============================================================
void DetectFairValueGaps()
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 5, highs) < 5) return;
   if(CopyLow (_Symbol, PERIOD_CURRENT, 0, 5, lows)  < 5) return;

   double pt = _Point;

   double bullGap = lows[0] - highs[2];
   if(bullGap > InpFVG_MinPoints * pt)
   {
      lastFVG.time       = iTime(_Symbol, PERIOD_CURRENT, 1);
      lastFVG.upperPrice = lows[0];
      lastFVG.lowerPrice = highs[2];
      lastFVG.isBullish  = true;
      hasValidFVG = true;
   }

   double bearGap = lows[2] - highs[0];
   if(bearGap > InpFVG_MinPoints * pt)
   {
      lastFVG.time       = iTime(_Symbol, PERIOD_CURRENT, 1);
      lastFVG.upperPrice = lows[2];
      lastFVG.lowerPrice = highs[0];
      lastFVG.isBullish  = false;
      hasValidFVG = true;
   }
}

//============================================================
// DetectMarketPhase (Wyckoff)
// FIX: No longer takes volume[] parameter - reads internally via CopyTickVolume()
//      FIX: static arrays -> dynamic arrays
//============================================================
string DetectMarketPhase()
{
   // Volume via CopyTickVolume
   long volArr[];
   ArraySetAsSeries(volArr, true);
   if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 10, volArr) < 10) return "UNKNOWN";

   double avgVol = 0;
   for(int i = 1; i < 10; i++) avgVol += (double)volArr[i];
   avgVol /= 9.0;

   double currentVol = (double)volArr[0];

   // Dynamic arrays for price data
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs,  true);
   ArraySetAsSeries(lows,   true);
   ArraySetAsSeries(closes, true);

   if(CopyHigh (_Symbol, PERIOD_CURRENT, 0, 20, highs)  < 20) return "UNKNOWN";
   if(CopyLow  (_Symbol, PERIOD_CURRENT, 0, 20, lows)   < 20) return "UNKNOWN";
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 20, closes) < 20) return "UNKNOWN";

   double volatility = 0;
   for(int i = 0; i < 10; i++) volatility += highs[i] - lows[i];
   volatility /= 10.0;

   double rangeHigh = highs[ArrayMaximum(highs, 0, 10)];
   double rangeLow  = lows [ArrayMinimum(lows,  0, 10)];
   double rangeWidth = rangeHigh - rangeLow;

   // ACCUMULATION: low volume + low volatility + ranging
   if(currentVol < avgVol * 0.8 && rangeWidth > 0 && volatility < rangeWidth * 0.3)
      return "ACCUMULATION";

   // MANIPULATION: volume spike + rejection candle
   bool volumeSpike = (avgVol > 0 && currentVol > avgVol * InpVolSpikeThreshold);
   bool priceRejection = false;

   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double bodySize  = MathAbs(closes[1] - o1);
   double upperWick = highs[1] - MathMax(closes[1], o1);
   double lowerWick = MathMin(closes[1], o1) - lows[1];

   if(bodySize > 0 && (upperWick > bodySize * 2 || lowerWick > bodySize * 2))
      priceRejection = true;

   if(volumeSpike && priceRejection) return "MANIPULATION";

   // DISTRIBUTION: high volume + high volatility + trending
   if(rangeWidth > 0 && currentVol > avgVol * 1.5 && volatility > rangeWidth * 0.5)
      return "DISTRIBUTION";

   return "NEUTRAL";
}

//============================================================
// ExecuteTrade
//============================================================
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pt     = _Point;
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double slPts, tpPts;

   if(InpUseATR_SLTP)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(handleATR, 0, 1, 1, atrBuf) < 1) return;
      slPts = atrBuf[0] * InpATR_SL_Multi;
      tpPts = atrBuf[0] * InpATR_TP_Multi;
   }
   else
   {
      slPts = InpSL_Points * pt;
      tpPts = InpTP_Points * pt;
   }

   double minStop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * pt;
   if(slPts < minStop * 2) slPts = minStop * 2;
   if(tpPts < minStop * 2) tpPts = minStop * 2;

   double entry, sl, tp;
   if(orderType == ORDER_TYPE_BUY)
   {
      entry = ask;
      sl    = NormalizeDouble(entry - slPts, digits);
      tp    = NormalizeDouble(entry + tpPts, digits);
   }
   else
   {
      entry = bid;
      sl    = NormalizeDouble(entry + slPts, digits);
      tp    = NormalizeDouble(entry - tpPts, digits);
   }

   double lots = CalculateLotSize(slPts);
   if(lots <= 0) return;

   if(InpAdjustTP_For_Cost)
   {
      double spread     = ask - bid;
      double commission = InpCommissionPerLot * lots;
      double totalCost  = spread + (commission / lots);
      if(orderType == ORDER_TYPE_BUY)  tp = NormalizeDouble(tp + totalCost, digits);
      else                             tp = NormalizeDouble(tp - totalCost, digits);
      totalSpreadCost += spread * lots;
      totalCommission += commission;
   }

   bool ok = (orderType == ORDER_TYPE_BUY)
             ? trade.Buy (lots, _Symbol, entry, sl, tp, InpTradeComment)
             : trade.Sell(lots, _Symbol, entry, sl, tp, InpTradeComment);

   if(ok)
   {
      string dir = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      Print("TRADE: ", dir, "  Lot=", lots,
            "  Entry=", entry, "  SL=", sl, "  TP=", tp,
            "  Score=", confluenceScore, "  SMC=", smcPattern);
      if(InpEnableAlerts)
         Alert("ProSmart v6.0 | ", dir, " | ", _Symbol, " | Score:", confluenceScore);
   }
   else
      Print("Trade failed! Error:", GetLastError());
}

//============================================================
// CalculateLotSize
//============================================================
double CalculateLotSize(double slPoints)
{
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickVal == 0 || tickSz == 0 || slPoints == 0) return minLot;
   if(balance <= InpMicroBalanceUSD) return minLot;

   double riskAmt  = balance * (InpRiskPercent / 100.0);
   double slTicks  = slPoints / tickSz;
   double lots     = riskAmt / (slTicks * tickVal);

   lots = MathMin(lots, InpMaxLotSize);
   lots = MathMin(lots, maxLot);
   lots = MathMax(lots, InpMinLotSize);
   lots = MathMax(lots, minLot);
   lots = MathFloor(lots / lotStep) * lotStep;

   return NormalizeDouble(lots, 2);
}

//============================================================
// ManageOpenPositions
//============================================================
void ManageOpenPositions()
{
   double pt     = _Point;
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i))         continue;
      if(posInfo.Magic()  != InpMagicNumber) continue;
      if(posInfo.Symbol() != _Symbol)        continue;

      double   openPrice = posInfo.PriceOpen();
      double   curSL     = posInfo.StopLoss();
      double   curTP     = posInfo.TakeProfit();
      double   ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double   bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      ulong    ticket    = posInfo.Ticket();
      datetime openTime  = posInfo.Time();

      if(InpMaxHoldHours > 0)
      {
         int hoursOpen = (int)((TimeCurrent() - openTime) / 3600);
         if(hoursOpen >= InpMaxHoldHours)
         {
            Print("Max hold time (", hoursOpen, "h). Closing #", ticket);
            trade.PositionClose(ticket);
            continue;
         }
      }

      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double pp = (bid - openPrice) / pt;

         if(InpUseBE && pp >= InpBE_Activate && curSL < openPrice)
         {
            double nSL = NormalizeDouble(openPrice + pt * 10, digits);
            trade.PositionModify(ticket, nSL, curTP);
            if(InpDebugMode) Print("BE activated BUY #", ticket);
         }
         if(InpUseTrailing && pp >= InpTrailStart)
         {
            double nSL = NormalizeDouble(bid - InpTrailStart * pt, digits);
            if(nSL > curSL + InpTrailStep * pt)
            {
               trade.PositionModify(ticket, nSL, curTP);
               if(InpDebugMode) Print("Trail updated BUY #", ticket);
            }
         }
      }
      else if(posInfo.PositionType() == POSITION_TYPE_SELL)
      {
         double pp = (openPrice - ask) / pt;

         if(InpUseBE && pp >= InpBE_Activate && (curSL > openPrice || curSL == 0))
         {
            double nSL = NormalizeDouble(openPrice - pt * 10, digits);
            trade.PositionModify(ticket, nSL, curTP);
            if(InpDebugMode) Print("BE activated SELL #", ticket);
         }
         if(InpUseTrailing && pp >= InpTrailStart)
         {
            double nSL = NormalizeDouble(ask + InpTrailStart * pt, digits);
            if(nSL < curSL - InpTrailStep * pt || curSL == 0)
            {
               trade.PositionModify(ticket, nSL, curTP);
               if(InpDebugMode) Print("Trail updated SELL #", ticket);
            }
         }
      }
   }
}

//============================================================
// CheckCoolDownStatus
//============================================================
void CheckCoolDownStatus()
{
   double balance        = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyLossLimit = dailyStartBalance * (InpMaxDailyLoss / 100.0);
   double dailyLoss      = dailyStartBalance - balance;

   if(dailyLoss >= dailyLossLimit && !isCoolDownActive)
   {
      isCoolDownActive = true;
      coolDownUntil    = TimeCurrent() + (InpCoolDownHours * 3600);
      Print("DAILY LOSS LIMIT! Cool-down for ", InpCoolDownHours, " hours.");
   }

   if(dailyProfit >= dailyStartBalance * (InpMaxDailyProfit / 100.0))
   {
      Print("Daily profit target reached! Locking profits.");
      isCoolDownActive = true;
      coolDownUntil    = GetEndOfDay();
   }

   if(isCoolDownActive && TimeCurrent() >= coolDownUntil)
   {
      isCoolDownActive = false;
      coolDownUntil    = 0;
      Print("Cool-down ended. Robot resumed.");
   }
}

//============================================================
// UpdateDailyStats
//============================================================
void UpdateDailyStats()
{
   MqlDateTime dt, ldt;
   TimeToStruct(TimeCurrent(), dt);
   TimeToStruct(lastDayReset,  ldt);

   if(dt.day != ldt.day)
   {
      dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      lastDayReset      = TimeCurrent();
      winTrades         = 0;
      lossTrades        = 0;
      totalPnL          = 0;
      totalCommission   = 0;
      totalSpreadCost   = 0;
      isCoolDownActive  = false;
      coolDownUntil     = 0;
      FetchNewsFromCalendar();
      Print("=== NEW TRADING DAY === Balance=$", dailyStartBalance);
   }

   dailyProfit = AccountInfoDouble(ACCOUNT_BALANCE) - dailyStartBalance;
}

//============================================================
// OnTradeTransaction
//============================================================
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest&     request,
                        const MqlTradeResult&      result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.deal_type != DEAL_TYPE_BUY && trans.deal_type != DEAL_TYPE_SELL) return;

   double profit     = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   if(profit == 0) return;

   totalPnL        += profit;
   totalCommission += MathAbs(commission);

   if(profit > 0) { winTrades++;  Print("WIN  $", profit, " Comm=$", MathAbs(commission)); }
   else           { lossTrades++; Print("LOSS $", profit, " Comm=$", MathAbs(commission)); }
}

//============================================================
// Helper Functions
//============================================================
int CountMyPositions()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == _Symbol) cnt++;
   }
   return cnt;
}

bool CheckSpreadFilter()
{
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > InpMaxSpreadPoints)
      { if(InpDebugMode) Print("Spread too wide:", spread); return false; }
   return true;
}

bool IsMarketSessionOpen()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dow = dt.day_of_week;

   if(InpNoWeekend && (dow == 0 || dow == 6))
      { sessionStatus = "WEEKEND CLOSED"; return false; }

   if(dow == 5)
   {
      int nowMin   = dt.hour * 60 + dt.min;
      int closeMin = InpFridayCloseHour * 60 + InpFridayCloseMin;
      if(nowMin >= closeMin)
         { sessionStatus = "FRIDAY CLOSING"; return false; }
   }

   sessionStatus = "MARKET OPEN";
   return true;
}

datetime GetEndOfDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 23; dt.min = 59; dt.sec = 59;
   return StructToTime(dt);
}

//============================================================
// News Filter - Calendar API
//============================================================
void FetchNewsFromCalendar()
{
   newsCacheCount = 0;
   ArrayResize(newsCache, 0);

   datetime now = TimeCurrent();
   MqlCalendarValue values[];

   int count = CalendarValueHistory(values, now - 3600, now + 172800);
   if(count <= 0)
      { newsStatus = "Calendar: No data"; lastNewsFetch = now; return; }

   string filterCurr[];
   int filterCount = StringSplit(InpNewsCurrencies, ',', filterCurr);

   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent   event;
      MqlCalendarCountry country;
      if(!CalendarEventById(values[i].event_id, event))       continue;
      if(!CalendarCountryById(event.country_id, country))     continue;

      int impact = 0;
      if(event.importance == CALENDAR_IMPORTANCE_HIGH)     impact = 3;
      if(event.importance == CALENDAR_IMPORTANCE_MODERATE) impact = 2;
      if(event.importance == CALENDAR_IMPORTANCE_LOW)      impact = 1;

      bool shouldFilter = false;
      if(InpFilterHighImpact && impact == 3) shouldFilter = true;
      if(InpFilterMedImpact  && impact == 2) shouldFilter = true;
      if(!shouldFilter) continue;

      bool currMatch = false;
      for(int c = 0; c < filterCount; c++)
      {
         string fc = filterCurr[c];
         StringTrimLeft(fc); StringTrimRight(fc);
         if(fc == country.currency || fc == "ALL") { currMatch = true; break; }
      }
      if(!currMatch) continue;

      int idx = newsCacheCount;
      ArrayResize(newsCache, idx + 1);
      newsCache[idx].eventTime = values[i].time;
      newsCache[idx].currency  = country.currency;
      newsCache[idx].title     = event.name;
      newsCache[idx].impact    = impact;
      newsCacheCount++;
   }

   lastNewsFetch = now;
   newsStatus    = "Calendar: " + IntegerToString(newsCacheCount) + " events";
}

bool IsNewsTime()
{
   if(newsCacheCount == 0) return false;
   datetime now = TimeCurrent();
   for(int i = 0; i < newsCacheCount; i++)
   {
      datetime t = newsCache[i].eventTime;
      if(now >= t - InpNewsMinsBefore * 60 && now <= t + InpNewsMinsAfter * 60)
         { newsStatus = "NEWS: " + newsCache[i].title; return true; }
   }
   newsStatus = "No news";
   return false;
}

//============================================================
// Dashboard
//============================================================
void DrawDashboard()
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   int    pos       = CountMyPositions();
   int    total     = winTrades + lossTrades;
   double wr        = (total > 0) ? (double)winTrades / (double)total * 100.0 : 0.0;
   double profitPct = (dailyStartBalance > 0) ? (dailyProfit / dailyStartBalance * 100.0) : 0;
   double netPnL    = totalPnL - totalCommission - totalSpreadCost;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string timeStr = StringFormat("%02d:%02d  %02d.%02d.%d", dt.hour, dt.min, dt.day, dt.mon, dt.year);

   string modeStr = "";
   if(isCoolDownActive)
   {
      int remainMin = (int)((coolDownUntil - TimeCurrent()) / 60);
      modeStr = "COOL-DOWN (" + IntegerToString(remainMin) + " min)";
   }
   else modeStr = (balance <= InpMicroBalanceUSD) ? "MICRO MODE" : "ACTIVE";

   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;

   string s = "";
   s += "=== ProSmartScalper AI v6.0 ULTIMATE ===\n";
   s += _Symbol + " " + EnumToString(Period()) + "  " + timeStr + "\n";
   s += "Status  : " + modeStr + "\n";
   s += "---\n";
   s += "Balance : $" + DoubleToString(balance, 2) + "\n";
   s += "Equity  : $" + DoubleToString(equity,  2) + "\n";
   s += "Day P&L : $" + DoubleToString(dailyProfit, 2) + " (" + DoubleToString(profitPct, 1) + "%)\n";
   s += "---\n";
   s += "Signal  : " + lastSignal + "\n";
   s += "SMC     : " + smcPattern + "\n";
   s += "Phase   : " + marketPhase + "\n";
   s += "Score   : " + IntegerToString(confluenceScore) + "/10\n";
   s += "---\n";
   s += newsStatus + "\n";
   s += sessionStatus + "\n";
   s += "Spread  : " + DoubleToString(spread, 1) + " pts\n";
   s += "---\n";
   s += "Pos     : " + IntegerToString(pos) + "/" + IntegerToString(InpMaxPositions) + "\n";
   s += "Trades  : " + IntegerToString(total) + " W:" + IntegerToString(winTrades) + " L:" + IntegerToString(lossTrades) + "\n";
   s += "WinRate : " + DoubleToString(wr, 1) + "%\n";
   s += "Gross PL: $" + DoubleToString(totalPnL, 2) + "\n";
   s += "Comm    : $" + DoubleToString(totalCommission, 2) + "\n";
   s += "Net PL  : $" + DoubleToString(netPnL, 2) + "\n";
   s += "---\n";
   s += "Risk    : " + DoubleToString(InpRiskPercent, 1) + "% | SMC:" + (string)(InpUseSMC ? "ON" : "OFF") + "\n";

   Comment(s);
}

//+------------------------------------------------------------------+
//| END OF EXPERT ADVISOR                                             |
//+------------------------------------------------------------------+
