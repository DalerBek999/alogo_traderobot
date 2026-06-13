//+------------------------------------------------------------------+
//|                                       ProAdvancedTrader_v1.mq5   |
//|                                  Professional Trading Robot       |
//|                                  Multi-Strategy with News Filter  |
//+------------------------------------------------------------------+
#property copyright "Takrorlanmas Robotlar"
#property link      "https://t.me/takrorlanmas_robotlar"
#property version   "1.00"
#property strict

//--- Input Parameters
input group "=== TRADING SETTINGS ==="
input double   RiskPercent        = 2.0;    // Risk per trade (%)
input double   MinLotSize         = 0.01;   // Minimum lot size
input double   MaxLotSize         = 0.5;    // Maximum lot size
input int      MaxSpread          = 30;     // Maximum spread (points)
input long     MagicNumber        = 123456; // Magic number  // FIX: long (not int) for magic
input int      MaxOpenTrades      = 1;      // Maximum open trades

input group "=== STRATEGY PARAMETERS ==="
input int      RSI_Period         = 14;
input int      RSI_Oversold       = 30;
input int      RSI_Overbought     = 70;
input int      MACD_Fast          = 12;
input int      MACD_Slow          = 26;
input int      MACD_Signal        = 9;
input int      BB_Period          = 20;
input double   BB_Deviation       = 2.0;
input int      ATR_Period         = 14;
input double   ATR_Multiplier     = 1.5;
input int      ADX_Period         = 14;
input double   ADX_MinLevel       = 25.0;

input group "=== RISK MANAGEMENT ==="
input bool     UseTrailingStop    = true;
input int      TrailingStart      = 200;
input int      TrailingStep       = 50;
input bool     UseBreakeven       = true;
input int      BreakevenStart     = 150;
input int      BreakevenProfit    = 10;

input group "=== TIME FILTERS ==="
input bool     UseTimeFilter      = true;
input int      MinutesBeforeClose = 15;
input int      TradingStartHour   = 1;
input int      TradingEndHour     = 22;

input group "=== NEWS FILTER ==="
input bool     UseNewsFilter      = true;
input int      MinutesBeforeNews  = 15;
input int      MinutesAfterNews   = 15;

//--- Indicator handles
int handleRSI, handleMACD, handleBB, handleATR, handleADX;
int handleRSI_H1, handleADX_H1, handleRSI_H4;

//--- Global variables
// FIX: all indicator buffers declared as global dynamic arrays
//      and marked AsSeries in OnInit (correct MQL5 pattern)
double rsiBuffer[];
double macdMainBuffer[], macdSignalBuffer[];
double bbUpperBuffer[], bbMiddleBuffer[], bbLowerBuffer[];
double atrBuffer[], adxBuffer[];
double rsiH1Buffer[], adxH1Buffer[], rsiH4Buffer[];

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== ProAdvancedTrader v1.0 ===");

   handleRSI    = iRSI  (_Symbol, PERIOD_CURRENT, RSI_Period,  PRICE_CLOSE);
   handleMACD   = iMACD (_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   handleBB     = iBands(_Symbol, PERIOD_CURRENT, BB_Period,  0, BB_Deviation, PRICE_CLOSE);
   handleATR    = iATR  (_Symbol, PERIOD_CURRENT, ATR_Period);
   handleADX    = iADX  (_Symbol, PERIOD_CURRENT, ADX_Period);
   handleRSI_H1 = iRSI  (_Symbol, PERIOD_H1, RSI_Period, PRICE_CLOSE);
   handleADX_H1 = iADX  (_Symbol, PERIOD_H1, ADX_Period);
   handleRSI_H4 = iRSI  (_Symbol, PERIOD_H4, RSI_Period, PRICE_CLOSE);

   if(handleRSI    == INVALID_HANDLE || handleMACD   == INVALID_HANDLE ||
      handleBB     == INVALID_HANDLE || handleATR    == INVALID_HANDLE ||
      handleADX    == INVALID_HANDLE || handleRSI_H1 == INVALID_HANDLE ||
      handleADX_H1 == INVALID_HANDLE || handleRSI_H4 == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicators!");
      return INIT_FAILED;
   }

   // Mark all global buffers as series
   ArraySetAsSeries(rsiBuffer,       true);
   ArraySetAsSeries(macdMainBuffer,  true);
   ArraySetAsSeries(macdSignalBuffer,true);
   ArraySetAsSeries(bbUpperBuffer,   true);
   ArraySetAsSeries(bbMiddleBuffer,  true);
   ArraySetAsSeries(bbLowerBuffer,   true);
   ArraySetAsSeries(atrBuffer,       true);
   ArraySetAsSeries(adxBuffer,       true);
   ArraySetAsSeries(rsiH1Buffer,     true);
   ArraySetAsSeries(adxH1Buffer,     true);
   ArraySetAsSeries(rsiH4Buffer,     true);

   lastBarTime = 0;

   Print("Robot initialized. Symbol=", _Symbol,
         "  TF=", EnumToString(Period()),
         "  Risk=", RiskPercent, "%",
         "  Magic=", MagicNumber);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleMACD);
   IndicatorRelease(handleBB);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleADX);
   IndicatorRelease(handleRSI_H1);
   IndicatorRelease(handleADX_H1);
   IndicatorRelease(handleRSI_H4);
   Print("Robot stopped. Reason:", getUninitReasonText(reason));
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   if(!UpdateIndicators())   return;
   if(!CheckTimeFilter())    return;
   if(!CheckMarketCloseFilter()) return;
   if(!CheckNewsFilter())    return;
   if(!CheckSpreadFilter())  return;

   ManagePositions();

   if(CountOpenPositions() >= MaxOpenTrades) return;

   int signal = AnalyzeMarket();
   if(signal ==  1) OpenTrade(ORDER_TYPE_BUY);
   if(signal == -1) OpenTrade(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
//| UpdateIndicators
//| FIX: check return value >= required count (not < 0)
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   // FIX: require at least 3 values, return false if fewer
   if(CopyBuffer(handleRSI,    0, 0, 3, rsiBuffer)        < 3) return false;
   if(CopyBuffer(handleMACD,   0, 0, 3, macdMainBuffer)   < 3) return false;
   if(CopyBuffer(handleMACD,   1, 0, 3, macdSignalBuffer) < 3) return false;

   // FIX: iBands buffer indices: 0=Base/Middle, 1=Upper, 2=Lower
   if(CopyBuffer(handleBB, 1, 0, 3, bbUpperBuffer)  < 3) return false;
   if(CopyBuffer(handleBB, 0, 0, 3, bbMiddleBuffer) < 3) return false;
   if(CopyBuffer(handleBB, 2, 0, 3, bbLowerBuffer)  < 3) return false;

   if(CopyBuffer(handleATR,    0, 0, 3, atrBuffer)    < 3) return false;
   if(CopyBuffer(handleADX,    0, 0, 3, adxBuffer)    < 3) return false;
   if(CopyBuffer(handleRSI_H1, 0, 0, 3, rsiH1Buffer)  < 3) return false;
   if(CopyBuffer(handleADX_H1, 0, 0, 3, adxH1Buffer)  < 3) return false;
   if(CopyBuffer(handleRSI_H4, 0, 0, 3, rsiH4Buffer)  < 3) return false;

   return true;
}

//+------------------------------------------------------------------+
//| AnalyzeMarket                                                    |
//+------------------------------------------------------------------+
int AnalyzeMarket()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double rsi           = rsiBuffer[1];
   double macdMain      = macdMainBuffer[1];
   double macdSig       = macdSignalBuffer[1];
   double macdPrev      = macdMainBuffer[2];
   double macdSigPrev   = macdSignalBuffer[2];
   double bbUpper       = bbUpperBuffer[1];
   double bbLower       = bbLowerBuffer[1];
   double bbMiddle      = bbMiddleBuffer[1];
   double adx           = adxBuffer[1];
   double rsiH1         = rsiH1Buffer[1];
   double adxH1         = adxH1Buffer[1];
   double rsiH4         = rsiH4Buffer[1];

   int buyScore  = 0;
   int sellScore = 0;

   // RSI
   if(rsi < RSI_Oversold)  buyScore  += 2;
   if(rsi > RSI_Overbought) sellScore += 2;
   if(rsiH1 < 40)  buyScore++;
   if(rsiH1 > 60)  sellScore++;
   if(rsiH4 < 50)  buyScore++;
   if(rsiH4 > 50)  sellScore++;

   // MACD crossover
   if(macdMain > macdSig && macdPrev <= macdSigPrev && macdMain < 0) buyScore  += 2;
   if(macdMain < macdSig && macdPrev >= macdSigPrev && macdMain > 0) sellScore += 2;

   // Bollinger Bands
   if(bid < bbLower)  buyScore  += 2;
   if(ask > bbUpper)  sellScore += 2;

   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 2);
   if(prevClose < bbMiddle && bid > bbMiddle) buyScore++;
   if(prevClose > bbMiddle && ask < bbMiddle) sellScore++;

   // ADX trend strength filter
   if(adx < ADX_MinLevel || adxH1 < ADX_MinLevel)
   {
      if(InpDebugPrint()) Print("Weak trend. ADX=", adx, " ADX_H1=", adxH1);
      return 0;
   }

   // Volatility check
   double range = iHigh(_Symbol, PERIOD_CURRENT, 1) - iLow(_Symbol, PERIOD_CURRENT, 1);
   double atr   = atrBuffer[1];
   if(range < atr * 0.5)
   {
      if(InpDebugPrint()) Print("Low volatility. Range=", range, " ATR=", atr);
      return 0;
   }

   if(buyScore  >= 5 && buyScore  > sellScore) return  1;
   if(sellScore >= 5 && sellScore > buyScore)  return -1;
   return 0;
}

// Helper: avoid unused input warning – no debug input in v1, just always false
bool InpDebugPrint() { return false; }

//+------------------------------------------------------------------+
//| OpenTrade                                                        |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   double ask  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr  = atrBuffer[1];

   double slDist = atr * ATR_Multiplier;
   double entry, sl, tp;

   if(orderType == ORDER_TYPE_BUY)
   {
      entry = ask;
      sl    = NormalizeDouble(bid - slDist,        _Digits);
      tp    = NormalizeDouble(ask + slDist * 2.0,  _Digits);
   }
   else
   {
      entry = bid;
      sl    = NormalizeDouble(ask + slDist,         _Digits);
      tp    = NormalizeDouble(bid - slDist * 2.0,   _Digits);
   }

   double lotSize = CalculateLotSize(sl, entry);
   if(lotSize < MinLotSize)
      { Print("Lot size too small: ", lotSize); return; }

   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};

   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = _Symbol;
   request.volume       = lotSize;
   request.type         = orderType;
   request.price        = entry;
   request.sl           = sl;
   request.tp           = tp;
   request.deviation    = 10;
   request.magic        = MagicNumber;
   request.comment      = "ProAdvanced v1.0";
   request.type_filling = ORDER_FILLING_FOK;

   if(!OrderSend(request, result))
      { Print("OrderSend failed! Error:", GetLastError(), " RetCode:", result.retcode); return; }

   if(result.retcode == TRADE_RETCODE_DONE)
   {
      string dir = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      Print("TRADE: ", dir, "  Lot=", lotSize,
            "  Entry=", entry, "  SL=", sl, "  TP=", tp, "  ATR=", atr);
   }
   else
      Print("Trade failed. RetCode:", result.retcode);
}

//+------------------------------------------------------------------+
//| CalculateLotSize                                                 |
//| FIX: formula corrected: risk / (slPoints / tickSize * tickValue) |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl, double entryPrice)
{
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt  = balance * (RiskPercent / 100.0);
   double slPoints = MathAbs(entryPrice - sl);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickVal == 0 || tickSz == 0 || slPoints == 0) return minLot;

   // Correct formula
   double slTicks = slPoints / tickSz;
   double lotSize = riskAmt  / (slTicks * tickVal);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   if(lotSize < minLot)   lotSize = minLot;
   if(lotSize > maxLot)   lotSize = maxLot;
   if(lotSize > MaxLotSize) lotSize = MaxLotSize;
   if(lotSize < MinLotSize) lotSize = 0;

   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| ManagePositions                                                  |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)           continue;
      // FIX: cast MagicNumber to long for comparison
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      double             posOpen  = PositionGetDouble(POSITION_PRICE_OPEN);
      double             posSL    = PositionGetDouble(POSITION_SL);
      double             posTP    = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType  = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double             ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double             bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double profit       = (posType == POSITION_TYPE_BUY) ? (bid - posOpen) : (posOpen - ask);
      double profitPoints = profit / _Point;

      // Breakeven
      if(UseBreakeven && profitPoints >= BreakevenStart)
      {
         double newSL = posOpen + BreakevenProfit * _Point * ((posType == POSITION_TYPE_BUY) ? 1 : -1);
         if((posType == POSITION_TYPE_BUY  && (posSL < posOpen || posSL == 0)) ||
            (posType == POSITION_TYPE_SELL && (posSL > posOpen || posSL == 0)))
         {
            ModifyPosition(ticket, newSL, posTP);
            Print("Breakeven set for #", ticket);
         }
      }

      // Trailing stop
      if(UseTrailingStop && profitPoints >= TrailingStart)
      {
         double newSL = 0;
         if(posType == POSITION_TYPE_BUY)
         {
            newSL = bid - TrailingStep * _Point;
            if(newSL > posSL + TrailingStep * _Point || posSL == 0)
               ModifyPosition(ticket, newSL, posTP);
         }
         else
         {
            newSL = ask + TrailingStep * _Point;
            if(newSL < posSL - TrailingStep * _Point || posSL == 0)
               ModifyPosition(ticket, newSL, posTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ModifyPosition                                                   |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};

   request.action   = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl       = NormalizeDouble(sl, _Digits);
   request.tp       = NormalizeDouble(tp, _Digits);

   if(!OrderSend(request, result))
      { Print("Modify failed! Error:", GetLastError()); return false; }

   return (result.retcode == TRADE_RETCODE_DONE);
}

//+------------------------------------------------------------------+
//| CountOpenPositions                                               |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| CheckTimeFilter                                                  |
//+------------------------------------------------------------------+
bool CheckTimeFilter()
{
   if(!UseTimeFilter) return true;
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   return (t.hour >= TradingStartHour && t.hour < TradingEndHour);
}

//+------------------------------------------------------------------+
//| CheckMarketCloseFilter                                           |
//+------------------------------------------------------------------+
bool CheckMarketCloseFilter()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   if(t.day_of_week == 5) // Friday
   {
      if(t.hour >= 22 || (t.hour == 21 && t.min >= 60 - MinutesBeforeClose))
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| CheckNewsFilter                                                  |
//+------------------------------------------------------------------+
bool CheckNewsFilter()
{
   if(!UseNewsFilter) return true;

   MqlDateTime t;
   TimeToStruct(TimeGMT(), t);
   int currentMinute = t.hour * 60 + t.min;

   // FIX: declare as const to avoid "static array" warning
   const int newsTimes[5] = { 510, 600, 750, 840, 930 };

   for(int i = 0; i < 5; i++)
   {
      int timeDiff = MathAbs(currentMinute - newsTimes[i]);
      if(timeDiff <= MinutesBeforeNews || timeDiff <= MinutesAfterNews)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| CheckSpreadFilter                                                |
//+------------------------------------------------------------------+
bool CheckSpreadFilter()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread <= MaxSpread);
}

//+------------------------------------------------------------------+
//| getUninitReasonText                                              |
//+------------------------------------------------------------------+
string getUninitReasonText(int reasonCode)
{
   switch(reasonCode)
   {
      case REASON_PROGRAM:     return "Program stopped by user";
      case REASON_REMOVE:      return "Program removed from chart";
      case REASON_RECOMPILE:   return "Program recompiled";
      case REASON_CHARTCHANGE: return "Chart symbol or timeframe changed";
      case REASON_CHARTCLOSE:  return "Chart closed";
      case REASON_PARAMETERS:  return "Input parameters changed";
      case REASON_ACCOUNT:     return "Account changed";
      default:                 return "Unknown reason";
   }
}

//+------------------------------------------------------------------+
//| END OF EXPERT ADVISOR                                            |
//+------------------------------------------------------------------+
