//+------------------------------------------------------------------+
//|                          ProAdvancedTrader_v2_ULTIMATE.mq5        |
//|                    PROFESSIONAL AUTO TRADING SYSTEM               |
//|   Multi-Strategy: SMC + ICT + Volume + Price Action + Indicators  |
//+------------------------------------------------------------------+
#property copyright   "ProAdvancedTrader Ultimate"
#property version     "2.00"
#property description "Professional Multi-Strategy Auto Trading Robot"
#property description "SMC + ICT + Volume Profile + Price Action"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//============================================================
// INPUT PARAMETERS
//============================================================
input group "=== RISK MANAGEMENT ==="
input double   InpRiskPercent          = 1.0;
input double   InpMaxDailyLoss         = 5.0;
input double   InpMaxDailyProfit       = 15.0;
input int      InpMaxPositions         = 2;
input double   InpMaxLotSize           = 5.0;
input double   InpMinLotSize           = 0.01;
input bool     InpUseMartingale        = false;
input double   InpMartingaleMulti      = 1.5;

input group "=== SL/TP ADVANCED ==="
input int      InpSL_Points            = 150;
input int      InpTP1_Points           = 200;
input int      InpTP2_Points           = 400;
input bool     InpUseATR_SLTP          = true;
input double   InpATR_SL_Multi         = 1.5;
input double   InpATR_TP1_Multi        = 2.0;
input double   InpATR_TP2_Multi        = 4.0;
input bool     InpUseTrailing          = true;
input int      InpTrailStart           = 200;
input int      InpTrailStep            = 50;
input bool     InpUseBreakeven         = true;
input int      InpBE_ActivatePoints    = 150;
input int      InpBE_ProfitPoints      = 20;

input group "=== SMART MONEY CONCEPTS (SMC) ==="
input bool     InpUseSMC               = true;
input int      InpOB_LookbackBars      = 30;
input double   InpOB_MinStrength       = 2.0;
input int      InpFVG_MinPoints        = 40;
input bool     InpUseBOS               = true;
input int      InpBOS_ConfirmBars      = 3;
input bool     InpUseLiquiditySweep    = true;
input int      InpLiqSweep_Lookback    = 20;

input group "=== ICT CONCEPTS ==="
input bool     InpUseICT               = true;
input bool     InpUseKillZones         = true;
input int      InpLondonOpenHour       = 8;
input int      InpNYOpenHour           = 13;
input bool     InpUseMitigationBlock   = true;
input bool     InpUseOptimalTradeEntry = true;

input group "=== VOLUME ANALYSIS ==="
input bool     InpUseVolumeProfile     = true;
input double   InpVolSpikeMulti        = 2.0;
input int      InpVolProfilePeriod     = 50;
input bool     InpHighVolNodeFilter    = true;

input group "=== PRICE ACTION PATTERNS ==="
input bool     InpUsePriceAction       = true;
input bool     InpDetectPinBar         = true;
input bool     InpDetectEngulfing      = true;
input bool     InpDetectInsideBar      = true;
input bool     InpDetectRejection      = true;
input double   InpWickRatio            = 2.5;

input group "=== MULTI-TIMEFRAME ANALYSIS ==="
input bool          InpUseMTF          = true;
input ENUM_TIMEFRAMES InpHTF1          = PERIOD_H4;
input ENUM_TIMEFRAMES InpHTF2          = PERIOD_H1;
input bool          InpMTF_AllMustAlign = false;

input group "=== TECHNICAL INDICATORS ==="
input int      InpEMA_Fast             = 8;
input int      InpEMA_Medium           = 21;
input int      InpEMA_Slow             = 50;
input int      InpEMA_Trend            = 200;
input int      InpRSI_Period           = 14;
input double   InpRSI_Oversold         = 30.0;
input double   InpRSI_Overbought       = 70.0;
input int      InpMACD_Fast            = 12;
input int      InpMACD_Slow            = 26;
input int      InpMACD_Signal          = 9;
input int      InpATR_Period           = 14;
input int      InpADX_Period           = 14;
input double   InpADX_MinTrend         = 25.0;
input int      InpStoch_K              = 5;
input int      InpStoch_D              = 3;
input int      InpStoch_Slowing        = 3;
input int      InpBB_Period            = 20;
input double   InpBB_Deviation         = 2.0;

input group "=== FIBONACCI ==="
input bool     InpUseFibonacci         = true;
input int      InpFib_SwingBars        = 50;
input bool     InpFib_TradeRetracements = true;

input group "=== FILTERS & CONDITIONS ==="
input double   InpMaxSpreadPoints      = 5.0;
input bool     InpNewsFilter           = false;
input bool     InpNoWeekendTrading     = true;
input int      InpFridayCloseHour      = 22;
input double   InpMinAccountBalance    = 50.0;

input group "=== SIGNAL QUALITY ==="
input int      InpMinConfluence        = 8;
input int      InpPerfectSignalScore   = 12;
input bool     InpWaitPerfectOnly      = false;

input group "=== GENERAL ==="
input long     InpMagicNumber          = 999888;
input string   InpTradeComment         = "ProUltimate_v2";
input bool     InpShowDashboard        = true;
input bool     InpEnableAlerts         = true;
input bool     InpDebugMode            = false;

//============================================================
// GLOBAL VARIABLES
//============================================================
CTrade        trade;
CPositionInfo posInfo;
COrderInfo    orderInfo;

// Indicator handles
int handleEMA_Fast, handleEMA_Med, handleEMA_Slow, handleEMA_Trend;
int handleRSI, handleMACD, handleATR, handleADX, handleStoch, handleBB;
int handleHTF1_EMA, handleHTF2_EMA;
// NOTE: No handleVolume needed – we use CopyTickVolume() directly

// Statistics
double   dailyStartBalance = 0;
double   dailyProfit       = 0;
double   totalPnL          = 0;
int      totalTrades       = 0;
int      winTrades         = 0;
int      lossTrades        = 0;
datetime lastBarTime       = 0;
datetime lastDayReset      = 0;

// Signal tracking
string lastSignal          = "Initializing...";
string marketPhase         = "Analyzing...";
string smcPattern          = "None";
string ictPattern          = "None";
string priceActionPattern  = "None";

int  confluenceScore = 0;
bool perfectSignal   = false;

// SMC structures
struct OrderBlock
{
   datetime time;
   double   highPrice;
   double   lowPrice;
   bool     isBullish;
   double   strength;
   bool     isValid;
};
OrderBlock activeBullOB, activeBearOB;

struct FairValueGap
{
   datetime time;
   double   upperPrice;
   double   lowerPrice;
   bool     isBullish;
   bool     isFilled;
};
FairValueGap activeFVG;

// Market structure
double lastSwingHigh   = 0;
double lastSwingLow    = 0;
string trendDirection  = "NEUTRAL";
bool   bosDetected     = false;

// Position management
double lastLotSize        = 0;
int    consecutiveLosses  = 0;

//============================================================
// FORWARD DECLARATIONS
//============================================================
int    AnalyzeMarketUltimate();
void   DetectOrderBlocks();
void   DetectFairValueGaps();
void   DetectBreakOfStructure();
bool   IsKillZoneTime();
bool   DetectLiquiditySweep();
string DetectPriceActionPatterns();
void   ExecuteTrade(ENUM_ORDER_TYPE orderType);
double CalculateLotSize(double slDistance);
void   ManagePositions();
void   UpdateDailyStats();
bool   PassFilters();
int    CountMyPositions();
void   DrawDashboard();

//============================================================
// OnInit
//============================================================
int OnInit()
{
   Print("=== ProAdvancedTrader v2.0 ULTIMATE ===");

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.LogLevel(LOG_LEVEL_ERRORS);

   handleEMA_Fast  = iMA(_Symbol, PERIOD_CURRENT, InpEMA_Fast,   0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Med   = iMA(_Symbol, PERIOD_CURRENT, InpEMA_Medium, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Slow  = iMA(_Symbol, PERIOD_CURRENT, InpEMA_Slow,   0, MODE_EMA, PRICE_CLOSE);
   handleEMA_Trend = iMA(_Symbol, PERIOD_CURRENT, InpEMA_Trend,  0, MODE_EMA, PRICE_CLOSE);
   handleRSI       = iRSI(_Symbol, PERIOD_CURRENT, InpRSI_Period, PRICE_CLOSE);
   handleMACD      = iMACD(_Symbol, PERIOD_CURRENT, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, PRICE_CLOSE);
   handleATR       = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
   handleADX       = iADX(_Symbol, PERIOD_CURRENT, InpADX_Period);
   handleStoch     = iStochastic(_Symbol, PERIOD_CURRENT, InpStoch_K, InpStoch_D, InpStoch_Slowing, MODE_SMA, STO_LOWHIGH);
   handleBB        = iBands(_Symbol, PERIOD_CURRENT, InpBB_Period, 0, InpBB_Deviation, PRICE_CLOSE);

   if(InpUseMTF)
   {
      handleHTF1_EMA = iMA(_Symbol, InpHTF1, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      handleHTF2_EMA = iMA(_Symbol, InpHTF2, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   }

   if(handleEMA_Fast == INVALID_HANDLE || handleRSI == INVALID_HANDLE ||
      handleATR      == INVALID_HANDLE || handleMACD == INVALID_HANDLE)
   {
      Print("ERROR: Failed to initialize indicators!");
      return INIT_FAILED;
   }

   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   lastDayReset      = TimeCurrent();

   Print("Robot initialized. Balance=$", dailyStartBalance,
         "  Risk=", InpRiskPercent, "%",
         "  MinScore=", InpMinConfluence);
   return INIT_SUCCEEDED;
}

//============================================================
// OnDeinit
//============================================================
void OnDeinit(const int reason)
{
   IndicatorRelease(handleEMA_Fast);
   IndicatorRelease(handleEMA_Med);
   IndicatorRelease(handleEMA_Slow);
   IndicatorRelease(handleEMA_Trend);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleMACD);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleADX);
   IndicatorRelease(handleStoch);
   IndicatorRelease(handleBB);
   if(InpUseMTF)
   {
      IndicatorRelease(handleHTF1_EMA);
      IndicatorRelease(handleHTF2_EMA);
   }
   Comment("");
   Print("Robot stopped. Trades=", totalTrades,
         " Wins=", winTrades, " Losses=", lossTrades,
         " PnL=$", totalPnL);
}

//============================================================
// OnTick
//============================================================
void OnTick()
{
   UpdateDailyStats();
   ManagePositions();

   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBar == lastBarTime) return;
   lastBarTime = currentBar;

   if(InpShowDashboard) DrawDashboard();
   if(!PassFilters())   return;
   if(CountMyPositions() >= InpMaxPositions) return;

   int signal = AnalyzeMarketUltimate();

   bool canTrade = InpWaitPerfectOnly
                   ? (confluenceScore >= InpPerfectSignalScore)
                   : (confluenceScore >= InpMinConfluence);

   if(canTrade)
   {
      if(signal ==  1) ExecuteTrade(ORDER_TYPE_BUY);
      if(signal == -1) ExecuteTrade(ORDER_TYPE_SELL);
   }
}

//============================================================
// AnalyzeMarketUltimate
// FIX: volume uses CopyTickVolume() with dynamic long[] array
//      All CopyBuffer arrays are dynamic (no fixed size)
//============================================================
int AnalyzeMarketUltimate()
{
   // --- dynamic arrays for CopyBuffer (MQL5 requires dynamic for indicator buffers) ---
   double emaFast[], emaMed[], emaSlow[], emaTrend[];
   double rsiArr[], macdMain[], macdSig[], atrArr[], adxArr[];
   double stochMain[], stochSig[];
   double bbUp[], bbMid[], bbLow[];

   ArraySetAsSeries(emaFast,   true); ArraySetAsSeries(emaMed,   true);
   ArraySetAsSeries(emaSlow,   true); ArraySetAsSeries(emaTrend, true);
   ArraySetAsSeries(rsiArr,    true); ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSig,   true); ArraySetAsSeries(atrArr,   true);
   ArraySetAsSeries(adxArr,    true); ArraySetAsSeries(stochMain,true);
   ArraySetAsSeries(stochSig,  true); ArraySetAsSeries(bbUp,     true);
   ArraySetAsSeries(bbMid,     true); ArraySetAsSeries(bbLow,    true);

   if(CopyBuffer(handleEMA_Fast,  0, 0, 3, emaFast)   < 3) return 0;
   if(CopyBuffer(handleEMA_Med,   0, 0, 3, emaMed)    < 3) return 0;
   if(CopyBuffer(handleEMA_Slow,  0, 0, 3, emaSlow)   < 3) return 0;
   if(CopyBuffer(handleEMA_Trend, 0, 0, 3, emaTrend)  < 3) return 0;
   if(CopyBuffer(handleRSI,       0, 0, 3, rsiArr)    < 3) return 0;
   if(CopyBuffer(handleMACD,      0, 0, 3, macdMain)  < 3) return 0;
   if(CopyBuffer(handleMACD,      1, 0, 3, macdSig)   < 3) return 0;
   if(CopyBuffer(handleATR,       0, 0, 3, atrArr)    < 3) return 0;
   if(CopyBuffer(handleADX,       0, 0, 3, adxArr)    < 3) return 0;
   if(CopyBuffer(handleStoch,     0, 0, 3, stochMain) < 3) return 0;
   if(CopyBuffer(handleStoch,     1, 0, 3, stochSig)  < 3) return 0;
   if(CopyBuffer(handleBB,        1, 0, 3, bbUp)      < 3) return 0;
   if(CopyBuffer(handleBB,        0, 0, 3, bbMid)     < 3) return 0;
   if(CopyBuffer(handleBB,        2, 0, 3, bbLow)     < 3) return 0;

   // --- FIX: Volume – use CopyTickVolume() with dynamic long[] array ---
   long volArr[];
   ArraySetAsSeries(volArr, true);
   bool volOk = (CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 10, volArr) >= 10);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int buyScore  = 0;
   int sellScore = 0;
   smcPattern         = "";
   ictPattern         = "";
   priceActionPattern = "";

   // === 1. SMC ===
   if(InpUseSMC)
   {
      DetectOrderBlocks();
      if(activeBullOB.isValid && bid >= activeBullOB.lowPrice && bid <= activeBullOB.highPrice)
         { buyScore += 3; smcPattern += "BullOB "; }
      if(activeBearOB.isValid && ask >= activeBearOB.lowPrice && ask <= activeBearOB.highPrice)
         { sellScore += 3; smcPattern += "BearOB "; }

      DetectFairValueGaps();
      if( activeFVG.isBullish  && !activeFVG.isFilled && bid <= activeFVG.upperPrice)
         { buyScore += 2; smcPattern += "FVG "; }
      if(!activeFVG.isBullish  && !activeFVG.isFilled && ask >= activeFVG.lowerPrice)
         { sellScore += 2; smcPattern += "FVG "; }

      if(InpUseBOS)
      {
         DetectBreakOfStructure();
         if(bosDetected && trendDirection == "BULLISH") { buyScore  += 2; smcPattern += "BOS "; }
         if(bosDetected && trendDirection == "BEARISH") { sellScore += 2; smcPattern += "BOS "; }
      }
   }

   // === 2. ICT ===
   if(InpUseICT)
   {
      if(InpUseKillZones && IsKillZoneTime())
         { buyScore += 1; sellScore += 1; ictPattern += "KillZone "; }

      if(InpUseLiquiditySweep && DetectLiquiditySweep())
      {
         if(trendDirection == "BULLISH") buyScore  += 2;
         else                            sellScore += 2;
         ictPattern += "LiqSweep ";
      }
   }

   // === 3. VOLUME ===
   if(InpUseVolumeProfile && volOk)
   {
      double avgVol = 0;
      for(int k = 1; k < 10; k++) avgVol += (double)volArr[k];
      avgVol /= 9.0;
      if(avgVol > 0 && (double)volArr[0] > avgVol * InpVolSpikeMulti)
         { buyScore += 1; sellScore += 1; }
   }

   // === 4. PRICE ACTION ===
   if(InpUsePriceAction)
   {
      string pa = DetectPriceActionPatterns();
      if(pa == "BULLISH_PIN"   || pa == "BULLISH_ENGULF")
         { buyScore  += 3; priceActionPattern = pa; }
      if(pa == "BEARISH_PIN"   || pa == "BEARISH_ENGULF")
         { sellScore += 3; priceActionPattern = pa; }
   }

   // === 5. EMA ===
   if(emaFast[1] > emaMed[1] && emaMed[1] > emaSlow[1])        buyScore  += 2;
   else if(emaFast[1] < emaMed[1] && emaMed[1] < emaSlow[1])   sellScore += 2;

   if(emaFast[1] > emaMed[1] && emaFast[2] <= emaMed[2])       buyScore  += 2;
   if(emaFast[1] < emaMed[1] && emaFast[2] >= emaMed[2])       sellScore += 2;

   if(bid > emaTrend[1]) buyScore  += 1;
   else                  sellScore += 1;

   // === 6. RSI ===
   if(rsiArr[1] < InpRSI_Oversold)                              buyScore  += 2;
   if(rsiArr[1] > InpRSI_Overbought)                            sellScore += 2;
   if(rsiArr[2] < InpRSI_Oversold   && rsiArr[1] > InpRSI_Oversold)   buyScore  += 1;
   if(rsiArr[2] > InpRSI_Overbought && rsiArr[1] < InpRSI_Overbought) sellScore += 1;

   // === 7. MACD ===
   if(macdMain[1] > macdSig[1] && macdMain[1] > 0)             buyScore  += 1;
   if(macdMain[1] < macdSig[1] && macdMain[1] < 0)             sellScore += 1;
   if(macdMain[1] > macdSig[1] && macdMain[2] <= macdSig[2])   buyScore  += 1;
   if(macdMain[1] < macdSig[1] && macdMain[2] >= macdSig[2])   sellScore += 1;

   // === 8. ADX ===
   if(adxArr[1] >= InpADX_MinTrend)
   {
      if(buyScore  > sellScore) buyScore  += 1;
      if(sellScore > buyScore)  sellScore += 1;
   }

   // === 9. STOCHASTIC ===
   if(stochMain[1] < 20 && stochMain[1] > stochSig[1]) buyScore  += 1;
   if(stochMain[1] > 80 && stochMain[1] < stochSig[1]) sellScore += 1;

   // === 10. BOLLINGER BANDS ===
   if(bid <= bbLow[1]) buyScore  += 1;
   if(ask >= bbUp[1])  sellScore += 1;

   // === 11. MULTI-TIMEFRAME ===
   if(InpUseMTF)
   {
      double htf1[], htf2[];
      ArraySetAsSeries(htf1, true);
      ArraySetAsSeries(htf2, true);
      if(CopyBuffer(handleHTF1_EMA, 0, 0, 2, htf1) >= 2 &&
         CopyBuffer(handleHTF2_EMA, 0, 0, 2, htf2) >= 2)
      {
         if(ask > htf1[1] && ask > htf2[1])      buyScore  += 2;
         else if(bid < htf1[1] && bid < htf2[1]) sellScore += 2;
      }
   }

   // === FINAL ===
   confluenceScore = MathMax(buyScore, sellScore);
   perfectSignal   = (confluenceScore >= InpPerfectSignalScore);
   int diff        = MathAbs(buyScore - sellScore);

   if(buyScore >= InpMinConfluence && diff >= 3 && buyScore > sellScore)
   {
      lastSignal = "BUY  Score:" + IntegerToString(buyScore) + "/20";
      if(InpDebugMode)
         Print("BUY | Score:", buyScore, " SMC:", smcPattern, " ICT:", ictPattern, " PA:", priceActionPattern);
      return 1;
   }
   if(sellScore >= InpMinConfluence && diff >= 3 && sellScore > buyScore)
   {
      lastSignal = "SELL Score:" + IntegerToString(sellScore) + "/20";
      if(InpDebugMode)
         Print("SELL | Score:", sellScore, " SMC:", smcPattern, " ICT:", ictPattern, " PA:", priceActionPattern);
      return -1;
   }

   lastSignal = "No Signal (B:" + IntegerToString(buyScore) + " S:" + IntegerToString(sellScore) + ")";
   return 0;
}

//============================================================
// DetectOrderBlocks
// FIX: all price arrays are dynamic
//============================================================
void DetectOrderBlocks()
{
   double highs[], lows[], opens[], closes[];
   ArraySetAsSeries(highs,  true);
   ArraySetAsSeries(lows,   true);
   ArraySetAsSeries(opens,  true);
   ArraySetAsSeries(closes, true);

   int bars = InpOB_LookbackBars + 5;
   if(CopyHigh (_Symbol, PERIOD_CURRENT, 0, bars, highs)  < bars) return;
   if(CopyLow  (_Symbol, PERIOD_CURRENT, 0, bars, lows)   < bars) return;
   if(CopyOpen (_Symbol, PERIOD_CURRENT, 0, bars, opens)  < bars) return;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, bars, closes) < bars) return;

   // Bullish OB: last bearish candle before strong bullish move
   for(int i = 2; i < InpOB_LookbackBars; i++)
   {
      if(closes[i] < opens[i])
      {
         double upMove = 0;
         for(int j = i-1; j >= MathMax(0, i-3); j--)
            if(closes[j] > opens[j]) upMove += closes[j] - opens[j];

         double obSize = opens[i] - closes[i];
         if(obSize > 0 && upMove > obSize * InpOB_MinStrength)
         {
            activeBullOB.time      = iTime(_Symbol, PERIOD_CURRENT, i);
            activeBullOB.highPrice = highs[i];
            activeBullOB.lowPrice  = lows[i];
            activeBullOB.isBullish = true;
            activeBullOB.strength  = upMove / obSize;
            activeBullOB.isValid   = true;
            break;
         }
      }
   }

   // Bearish OB: last bullish candle before strong bearish move
   for(int i = 2; i < InpOB_LookbackBars; i++)
   {
      if(closes[i] > opens[i])
      {
         double downMove = 0;
         for(int j = i-1; j >= MathMax(0, i-3); j--)
            if(closes[j] < opens[j]) downMove += opens[j] - closes[j];

         double obSize = closes[i] - opens[i];
         if(obSize > 0 && downMove > obSize * InpOB_MinStrength)
         {
            activeBearOB.time      = iTime(_Symbol, PERIOD_CURRENT, i);
            activeBearOB.highPrice = highs[i];
            activeBearOB.lowPrice  = lows[i];
            activeBearOB.isBullish = false;
            activeBearOB.strength  = downMove / obSize;
            activeBearOB.isValid   = true;
            break;
         }
      }
   }
}

//============================================================
// DetectFairValueGaps
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
      activeFVG.time       = iTime(_Symbol, PERIOD_CURRENT, 1);
      activeFVG.upperPrice = lows[0];
      activeFVG.lowerPrice = highs[2];
      activeFVG.isBullish  = true;
      activeFVG.isFilled   = false;
   }

   double bearGap = lows[2] - highs[0];
   if(bearGap > InpFVG_MinPoints * pt)
   {
      activeFVG.time       = iTime(_Symbol, PERIOD_CURRENT, 1);
      activeFVG.upperPrice = lows[2];
      activeFVG.lowerPrice = highs[0];
      activeFVG.isBullish  = false;
      activeFVG.isFilled   = false;
   }
}

//============================================================
// DetectBreakOfStructure
//============================================================
void DetectBreakOfStructure()
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 50, highs) < 50) return;
   if(CopyLow (_Symbol, PERIOD_CURRENT, 0, 50, lows)  < 50) return;

   double swingHigh    = highs[ArrayMaximum(highs, 0, 30)];
   double swingLow     = lows [ArrayMinimum(lows,  0, 30)];
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);

   bosDetected = false;

   if(lastSwingHigh > 0 && currentPrice > lastSwingHigh)
      { bosDetected = true; trendDirection = "BULLISH"; }
   if(lastSwingLow  > 0 && currentPrice < lastSwingLow)
      { bosDetected = true; trendDirection = "BEARISH"; }

   lastSwingHigh = swingHigh;
   lastSwingLow  = swingLow;
}

//============================================================
// IsKillZoneTime
//============================================================
bool IsKillZoneTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if(h >= InpLondonOpenHour && h < InpLondonOpenHour + 2) return true;
   if(h >= InpNYOpenHour     && h < InpNYOpenHour     + 2) return true;
   return false;
}

//============================================================
// DetectLiquiditySweep
//============================================================
bool DetectLiquiditySweep()
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows,  true);

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 30, highs) < 30) return false;
   if(CopyLow (_Symbol, PERIOD_CURRENT, 0, 30, lows)  < 30) return false;

   double recentHigh = highs[ArrayMaximum(highs, 1, InpLiqSweep_Lookback)];
   double recentLow  = lows [ArrayMinimum(lows,  1, InpLiqSweep_Lookback)];

   if(highs[1] > recentHigh && iClose(_Symbol, PERIOD_CURRENT, 0) < recentHigh) return true;
   if(lows [1] < recentLow  && iClose(_Symbol, PERIOD_CURRENT, 0) > recentLow)  return true;
   return false;
}

//============================================================
// DetectPriceActionPatterns
//============================================================
string DetectPriceActionPatterns()
{
   double o1 = iOpen (_Symbol, PERIOD_CURRENT, 1);
   double h1 = iHigh (_Symbol, PERIOD_CURRENT, 1);
   double l1 = iLow  (_Symbol, PERIOD_CURRENT, 1);
   double c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double o2 = iOpen (_Symbol, PERIOD_CURRENT, 2);
   double c2 = iClose(_Symbol, PERIOD_CURRENT, 2);

   double body       = MathAbs(c1 - o1);
   double upperWick  = h1 - MathMax(o1, c1);
   double lowerWick  = MathMin(o1, c1) - l1;

   if(InpDetectPinBar && body > 0)
   {
      if(lowerWick > body * InpWickRatio && c1 > o1) return "BULLISH_PIN";
      if(upperWick > body * InpWickRatio && c1 < o1) return "BEARISH_PIN";
   }
   if(InpDetectEngulfing)
   {
      if(c1 > o1 && c2 < o2 && o1 < c2 && c1 > o2) return "BULLISH_ENGULF";
      if(c1 < o1 && c2 > o2 && o1 > c2 && c1 < o2) return "BEARISH_ENGULF";
   }
   return "NONE";
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

   double slDist, tp1Dist, tp2Dist;

   if(InpUseATR_SLTP)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(handleATR, 0, 1, 1, atrBuf) < 1) return;
      slDist  = atrBuf[0] * InpATR_SL_Multi;
      tp1Dist = atrBuf[0] * InpATR_TP1_Multi;
      tp2Dist = atrBuf[0] * InpATR_TP2_Multi;
   }
   else
   {
      slDist  = InpSL_Points  * pt;
      tp1Dist = InpTP1_Points * pt;
      tp2Dist = InpTP2_Points * pt;
   }

   double entry, sl, tp;
   if(orderType == ORDER_TYPE_BUY)
   {
      entry = ask;
      sl    = NormalizeDouble(entry - slDist,  digits);
      tp    = NormalizeDouble(entry + tp2Dist, digits);
   }
   else
   {
      entry = bid;
      sl    = NormalizeDouble(entry + slDist,  digits);
      tp    = NormalizeDouble(entry - tp2Dist, digits);
   }

   double lots = CalculateLotSize(slDist);
   if(lots <= 0) return;

   bool ok = (orderType == ORDER_TYPE_BUY)
             ? trade.Buy (lots, _Symbol, entry, sl, tp, InpTradeComment)
             : trade.Sell(lots, _Symbol, entry, sl, tp, InpTradeComment);

   if(ok)
   {
      string dir = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      Print("TRADE: ", dir, "  Lot=", lots,
            "  Entry=", entry, "  SL=", sl, "  TP=", tp,
            "  Score=", confluenceScore);
      lastLotSize       = lots;
      consecutiveLosses = 0;
      if(InpEnableAlerts)
         Alert("ProUltimate v2.0 | ", dir, " | ", _Symbol, " | Score:", confluenceScore);
   }
}

//============================================================
// CalculateLotSize
//============================================================
double CalculateLotSize(double slDistance)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickVal == 0 || tickSz == 0 || slDistance == 0) return minLot;

   double riskAmt = balance * (InpRiskPercent / 100.0);
   if(InpUseMartingale && consecutiveLosses > 0)
      riskAmt *= MathPow(InpMartingaleMulti, consecutiveLosses);

   double slTicks = slDistance / tickSz;
   double lots    = riskAmt / (slTicks * tickVal);

   lots = MathMin(lots, InpMaxLotSize);
   lots = MathMin(lots, maxLot);
   lots = MathMax(lots, InpMinLotSize);
   lots = MathMax(lots, minLot);
   lots = MathFloor(lots / lotStep) * lotStep;

   return NormalizeDouble(lots, 2);
}

//============================================================
// ManagePositions
//============================================================
void ManagePositions()
{
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i))         continue;
      if(posInfo.Magic()  != InpMagicNumber) continue;
      if(posInfo.Symbol() != _Symbol)        continue;

      double openPx   = posInfo.PriceOpen();
      double curSL    = posInfo.StopLoss();
      double curTP    = posInfo.TakeProfit();
      double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      ulong  ticket   = posInfo.Ticket();
      int    digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double pt       = _Point;
      double vol      = posInfo.Volume();

      if(posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double pp = (bid - openPx) / pt;

         if(InpUseBreakeven && pp >= InpBE_ActivatePoints && curSL < openPx)
         {
            double nSL = NormalizeDouble(openPx + InpBE_ProfitPoints * pt, digits);
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
         if(pp >= InpTP1_Points && vol > minVol)
         {
            double cv = NormalizeDouble(vol * 0.5, 2);
            if(cv >= minVol) { trade.PositionClosePartial(ticket, cv); Print("Partial close BUY #", ticket); }
         }
      }
      else // SELL
      {
         double pp = (openPx - ask) / pt;

         if(InpUseBreakeven && pp >= InpBE_ActivatePoints && (curSL > openPx || curSL == 0))
         {
            double nSL = NormalizeDouble(openPx - InpBE_ProfitPoints * pt, digits);
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
         if(pp >= InpTP1_Points && vol > minVol)
         {
            double cv = NormalizeDouble(vol * 0.5, 2);
            if(cv >= minVol) { trade.PositionClosePartial(ticket, cv); Print("Partial close SELL #", ticket); }
         }
      }
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
      Print("=== NEW DAY === Balance=$", dailyStartBalance);
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

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   if(profit == 0) return;

   totalPnL += profit;
   totalTrades++;

   if(profit > 0)
   {
      winTrades++;
      consecutiveLosses = 0;
      Print("WIN  $", profit, "  Total=$", totalPnL);
   }
   else
   {
      lossTrades++;
      consecutiveLosses++;
      Print("LOSS $", profit, "  Consec=", consecutiveLosses);
   }
}

//============================================================
// PassFilters
//============================================================
bool PassFilters()
{
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                    SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > InpMaxSpreadPoints)
      { if(InpDebugMode) Print("Spread too wide:", spread); return false; }

   if(InpNoWeekendTrading)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
      if(dt.day_of_week == 5 && dt.hour >= InpFridayCloseHour) return false;
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(dailyStartBalance - balance >= dailyStartBalance * (InpMaxDailyLoss / 100.0))
      { Print("Daily loss limit!"); return false; }

   if(dailyProfit >= dailyStartBalance * (InpMaxDailyProfit / 100.0))
      { if(InpDebugMode) Print("Daily profit target reached."); return false; }

   if(balance < InpMinAccountBalance)
      { Print("Balance too low: $", balance); return false; }

   return true;
}

//============================================================
// CountMyPositions
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

//============================================================
// DrawDashboard
//============================================================
void DrawDashboard()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   int    pos     = CountMyPositions();
   double wr      = (totalTrades > 0) ? (double)winTrades / (double)totalTrades * 100.0 : 0.0;

   string s = "";
   s += "=== ProAdvancedTrader v2.0 ULTIMATE ===\n";
   s += "Symbol  : " + _Symbol + "  " + EnumToString(Period()) + "\n";
   s += "Balance : $" + DoubleToString(balance, 2) + "\n";
   s += "Equity  : $" + DoubleToString(equity,  2) + "\n";
   s += "Day P&L : $" + DoubleToString(dailyProfit, 2) + "\n";
   s += "---\n";
   s += "Signal  : " + lastSignal + "\n";
   s += "Score   : " + IntegerToString(confluenceScore) + "/20";
   if(perfectSignal) s += " [PERFECT]";
   s += "\n";
   s += "SMC     : " + smcPattern + "\n";
   s += "ICT     : " + ictPattern + "\n";
   s += "PA      : " + priceActionPattern + "\n";
   s += "Trend   : " + trendDirection + "\n";
   s += "---\n";
   s += "Pos     : " + IntegerToString(pos) + "/" + IntegerToString(InpMaxPositions) + "\n";
   s += "Trades  : " + IntegerToString(totalTrades)
        + " W:" + IntegerToString(winTrades)
        + " L:" + IntegerToString(lossTrades) + "\n";
   s += "WinRate : " + DoubleToString(wr, 1) + "%\n";
   s += "Total PL: $" + DoubleToString(totalPnL, 2) + "\n";
   if(consecutiveLosses > 0)
      s += "ConsecL : " + IntegerToString(consecutiveLosses) + "\n";
   s += "---\n";
   s += "SMC:" + (string)(InpUseSMC          ? "ON" : "OFF");
   s += " ICT:" + (string)(InpUseICT         ? "ON" : "OFF");
   s += " PA:"  + (string)(InpUsePriceAction ? "ON" : "OFF");
   s += " MTF:" + (string)(InpUseMTF         ? "ON" : "OFF") + "\n";

   Comment(s);
}

//+------------------------------------------------------------------+
//| END OF EXPERT ADVISOR                                             |
//+------------------------------------------------------------------+
