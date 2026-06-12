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
input double      RiskPercent = 2.0;           // Risk per trade (%)
input double      MinLotSize = 0.01;           // Minimum lot size
input double      MaxLotSize = 0.5;            // Maximum lot size
input int         MaxSpread = 30;              // Maximum spread (points)
input int         MagicNumber = 123456;        // Magic number
input int         MaxOpenTrades = 1;           // Maximum open trades

input group "=== STRATEGY PARAMETERS ==="
input int         RSI_Period = 14;             // RSI Period
input int         RSI_Oversold = 30;           // RSI Oversold level
input int         RSI_Overbought = 70;         // RSI Overbought level
input int         MACD_Fast = 12;              // MACD Fast EMA
input int         MACD_Slow = 26;              // MACD Slow EMA
input int         MACD_Signal = 9;             // MACD Signal
input int         BB_Period = 20;              // Bollinger Bands Period
input double      BB_Deviation = 2.0;          // Bollinger Bands Deviation
input int         ATR_Period = 14;             // ATR Period
input double      ATR_Multiplier = 1.5;        // ATR SL Multiplier
input int         ADX_Period = 14;             // ADX Period
input double      ADX_MinLevel = 25.0;         // Minimum ADX for trend

input group "=== RISK MANAGEMENT ==="
input bool        UseTrailingStop = true;      // Use Trailing Stop
input int         TrailingStart = 200;         // Trailing Start (points)
input int         TrailingStep = 50;           // Trailing Step (points)
input bool        UseBreakeven = true;         // Move SL to Breakeven
input int         BreakevenStart = 150;        // Breakeven Start (points)
input int         BreakevenProfit = 10;        // Breakeven Profit (points)

input group "=== TIME FILTERS ==="
input bool        UseTimeFilter = true;        // Use Time Filter
input int         MinutesBeforeClose = 15;     // Stop before market close (min)
input int         TradingStartHour = 1;        // Trading start hour (server)
input int         TradingEndHour = 22;         // Trading end hour (server)

input group "=== NEWS FILTER ==="
input bool        UseNewsFilter = true;        // Use News Filter
input int         MinutesBeforeNews = 15;      // Stop before news (minutes)
input int         MinutesAfterNews = 15;       // Resume after news (minutes)

//--- Global Variables
int handleRSI, handleMACD, handleBB, handleATR, handleADX;
int handleRSI_H1, handleADX_H1, handleRSI_H4;
double rsiBuffer[], macdMainBuffer[], macdSignalBuffer[];
double bbUpperBuffer[], bbMiddleBuffer[], bbLowerBuffer[];
double atrBuffer[], adxBuffer[];
double rsiH1Buffer[], adxH1Buffer[], rsiH4Buffer[];
datetime lastBarTime;


//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("╔════════════════════════════════════════════════════════╗");
   Print("║   ProAdvancedTrader v1.0 - Professional Trading Robot  ║");
   Print("║   Multi-Strategy with Advanced Risk Management         ║");
   Print("╚════════════════════════════════════════════════════════╝");
   
   // Initialize indicators on current timeframe
   handleRSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   handleMACD = iMACD(_Symbol, PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   handleBB = iBands(_Symbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   handleATR = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   handleADX = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   
   // Initialize higher timeframe indicators
   handleRSI_H1 = iRSI(_Symbol, PERIOD_H1, RSI_Period, PRICE_CLOSE);
   handleADX_H1 = iADX(_Symbol, PERIOD_H1, ADX_Period);
   handleRSI_H4 = iRSI(_Symbol, PERIOD_H4, RSI_Period, PRICE_CLOSE);
   
   // Check if indicators are created successfully
   if(handleRSI == INVALID_HANDLE || handleMACD == INVALID_HANDLE || 
      handleBB == INVALID_HANDLE || handleATR == INVALID_HANDLE || 
      handleADX == INVALID_HANDLE || handleRSI_H1 == INVALID_HANDLE ||
      handleADX_H1 == INVALID_HANDLE || handleRSI_H4 == INVALID_HANDLE)
   {
      Print("❌ Error creating indicators!");
      return(INIT_FAILED);
   }
   
   // Set arrays as series
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(macdMainBuffer, true);
   ArraySetAsSeries(macdSignalBuffer, true);
   ArraySetAsSeries(bbUpperBuffer, true);
   ArraySetAsSeries(bbMiddleBuffer, true);
   ArraySetAsSeries(bbLowerBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(adxBuffer, true);
   ArraySetAsSeries(rsiH1Buffer, true);
   ArraySetAsSeries(adxH1Buffer, true);
   ArraySetAsSeries(rsiH4Buffer, true);
   
   lastBarTime = 0;
   
   Print("✅ Robot initialized successfully!");
   Print("📊 Symbol: ", _Symbol);
   Print("⏰ Timeframe: ", EnumToString(Period()));
   Print("💰 Risk per trade: ", RiskPercent, "%");
   Print("🎯 Magic Number: ", MagicNumber);
   
   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleMACD);
   IndicatorRelease(handleBB);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleADX);
   IndicatorRelease(handleRSI_H1);
   IndicatorRelease(handleADX_H1);
   IndicatorRelease(handleRSI_H4);
   
   Print("🛑 Robot stopped. Reason: ", getUninitReasonText(reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime)
      return;
   
   lastBarTime = currentBarTime;
   
   // Update indicator buffers
   if(!UpdateIndicators())
      return;
   
   // Apply filters
   if(!CheckTimeFilter())
   {
      Print("⏰ Time filter: Trading not allowed at this time");
      return;
   }
   
   if(!CheckMarketCloseFilter())
   {
      Print("🔔 Market close filter: Too close to market close");
      return;
   }
   
   if(!CheckNewsFilter())
   {
      Print("📰 News filter: High-impact news detected");
      return;
   }
   
   if(!CheckSpreadFilter())
   {
      Print("📊 Spread filter: Spread too wide");
      return;
   }
   
   // Manage existing positions
   ManagePositions();
   
   // Check if we can open new trades
   if(CountOpenPositions() >= MaxOpenTrades)
      return;
   
   // Analyze market and generate signals
   int signal = AnalyzeMarket();
   
   if(signal == 1) // BUY Signal
   {
      Print("🚀 BUY SIGNAL DETECTED!");
      OpenTrade(ORDER_TYPE_BUY);
   }
   else if(signal == -1) // SELL Signal
   {
      Print("🚀 SELL SIGNAL DETECTED!");
      OpenTrade(ORDER_TYPE_SELL);
   }
}


//+------------------------------------------------------------------+
//| Update Indicator Buffers                                         |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   // Copy RSI
   if(CopyBuffer(handleRSI, 0, 0, 3, rsiBuffer) < 0) return false;
   
   // Copy MACD
   if(CopyBuffer(handleMACD, 0, 0, 3, macdMainBuffer) < 0) return false;
   if(CopyBuffer(handleMACD, 1, 0, 3, macdSignalBuffer) < 0) return false;
   
   // Copy Bollinger Bands
   if(CopyBuffer(handleBB, 0, 0, 3, bbUpperBuffer) < 0) return false;
   if(CopyBuffer(handleBB, 1, 0, 3, bbMiddleBuffer) < 0) return false;
   if(CopyBuffer(handleBB, 2, 0, 3, bbLowerBuffer) < 0) return false;
   
   // Copy ATR
   if(CopyBuffer(handleATR, 0, 0, 3, atrBuffer) < 0) return false;
   
   // Copy ADX
   if(CopyBuffer(handleADX, 0, 0, 3, adxBuffer) < 0) return false;
   
   // Copy Higher Timeframe indicators
   if(CopyBuffer(handleRSI_H1, 0, 0, 2, rsiH1Buffer) < 0) return false;
   if(CopyBuffer(handleADX_H1, 0, 0, 2, adxH1Buffer) < 0) return false;
   if(CopyBuffer(handleRSI_H4, 0, 0, 2, rsiH4Buffer) < 0) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Analyze Market and Generate Signal                              |
//+------------------------------------------------------------------+
int AnalyzeMarket()
{
   // Get current price
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Current timeframe values
   double rsi = rsiBuffer[0];
   double macdMain = macdMainBuffer[0];
   double macdSignal = macdSignalBuffer[0];
   double macdPrev = macdMainBuffer[1];
   double macdSignalPrev = macdSignalBuffer[1];
   double bbUpper = bbUpperBuffer[0];
   double bbLower = bbLowerBuffer[0];
   double bbMiddle = bbMiddleBuffer[0];
   double adx = adxBuffer[0];
   
   // Higher timeframe values
   double rsiH1 = rsiH1Buffer[0];
   double adxH1 = adxH1Buffer[0];
   double rsiH4 = rsiH4Buffer[0];
   
   // Signal scores
   int buyScore = 0;
   int sellScore = 0;
   
   // === MULTI-TIMEFRAME RSI ANALYSIS ===
   // Current TF RSI
   if(rsi < RSI_Oversold) buyScore += 2;
   if(rsi > RSI_Overbought) sellScore += 2;
   
   // H1 RSI Confirmation
   if(rsiH1 < 40) buyScore++;
   if(rsiH1 > 60) sellScore++;
   
   // H4 RSI Trend
   if(rsiH4 < 50) buyScore++;
   if(rsiH4 > 50) sellScore++;

   
   // === MACD CROSSOVER ===
   bool macdBullishCross = (macdMain > macdSignal) && (macdPrev <= macdSignalPrev);
   bool macdBearishCross = (macdMain < macdSignal) && (macdPrev >= macdSignalPrev);
   
   if(macdBullishCross && macdMain < 0) buyScore += 2;
   if(macdBearishCross && macdMain > 0) sellScore += 2;
   
   // === BOLLINGER BANDS ===
   if(bid < bbLower) buyScore += 2; // Oversold
   if(ask > bbUpper) sellScore += 2; // Overbought
   
   // Price crossing middle band
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(prevClose < bbMiddle && bid > bbMiddle) buyScore++;
   if(prevClose > bbMiddle && ask < bbMiddle) sellScore++;
   
   // === ADX TREND STRENGTH ===
   // Require strong trend for both current and H1 timeframes
   bool strongTrend = (adx > ADX_MinLevel && adxH1 > ADX_MinLevel);
   
   if(!strongTrend)
   {
      Print("⚠️ Weak trend detected. ADX: ", adx, " ADX H1: ", adxH1);
      return 0; // No signal in weak trend
   }
   
   // === PRICE ACTION CONFIRMATION ===
   double range = iHigh(_Symbol, PERIOD_CURRENT, 1) - iLow(_Symbol, PERIOD_CURRENT, 1);
   double atr = atrBuffer[0];
   
   // Volatility check
   if(range < atr * 0.5)
   {
      Print("⚠️ Low volatility. Range: ", range, " ATR: ", atr);
      return 0;
   }
   
   // === FINAL DECISION ===
   Print("📊 Market Analysis: BUY=", buyScore, " SELL=", sellScore);
   Print("   RSI: ", rsi, " | MACD: ", macdMain, " | ADX: ", adx);
   Print("   H1 RSI: ", rsiH1, " | H4 RSI: ", rsiH4);
   
   // Require minimum score of 5 for signal confirmation
   if(buyScore >= 5 && buyScore > sellScore)
      return 1; // BUY
   
   if(sellScore >= 5 && sellScore > buyScore)
      return -1; // SELL
   
   return 0; // No signal
}


//+------------------------------------------------------------------+
//| Open Trade with Dynamic Risk Management                         |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = atrBuffer[0];
   
   // Calculate SL based on ATR
   double slDistance = atr * ATR_Multiplier;
   double sl = 0, tp = 0;
   double price = 0;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      price = ask;
      sl = NormalizeDouble(bid - slDistance, _Digits);
      tp = NormalizeDouble(ask + slDistance * 2.0, _Digits); // 1:2 RR
   }
   else
   {
      price = bid;
      sl = NormalizeDouble(ask + slDistance, _Digits);
      tp = NormalizeDouble(bid - slDistance * 2.0, _Digits); // 1:2 RR
   }
   
   // Calculate lot size
   double lotSize = CalculateLotSize(sl, price);
   
   if(lotSize < MinLotSize)
   {
      Print("❌ Lot size too small: ", lotSize);
      return;
   }
   
   // Prepare request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "ProAdvanced v1.0";
   request.type_filling = ORDER_FILLING_FOK;
   
   // Send order
   if(!OrderSend(request, result))
   {
      Print("❌ OrderSend failed! Error: ", GetLastError());
      Print("   RetCode: ", result.retcode);
      return;
   }
   
   if(result.retcode == TRADE_RETCODE_DONE)
   {
      Print("✅ Trade opened successfully!");
      Print("   Type: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
      Print("   Lot: ", lotSize);
      Print("   Price: ", price);
      Print("   SL: ", sl, " | TP: ", tp);
      Print("   ATR: ", atr);
   }
   else
   {
      Print("⚠️ Trade failed. RetCode: ", result.retcode);
   }
}


//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk                                |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl, double entryPrice)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   double slPoints = MathAbs(entryPrice - sl);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Calculate lot size
   double lotSize = (riskAmount / slPoints) * (tickSize / tickValue);
   
   // Round to lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Apply limits
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;
   if(lotSize > MaxLotSize) lotSize = MaxLotSize;
   if(lotSize < MinLotSize) lotSize = 0;
   
   Print("💰 Lot Calculation:");
   Print("   Balance: $", accountBalance);
   Print("   Risk: $", riskAmount, " (", RiskPercent, "%)");
   Print("   SL Points: ", slPoints);
   Print("   Lot Size: ", lotSize);
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Manage Open Positions (Trailing Stop & Breakeven)               |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posTP = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
      
      double profit = (posType == POSITION_TYPE_BUY) ? 
                      (bid - posOpenPrice) : (posOpenPrice - ask);
      double profitPoints = profit / _Point;
      
      // === BREAKEVEN ===
      if(UseBreakeven && profitPoints >= BreakevenStart)
      {
         double newSL = posOpenPrice + (BreakevenProfit * _Point * ((posType == POSITION_TYPE_BUY) ? 1 : -1));
         
         if((posType == POSITION_TYPE_BUY && (posSL < posOpenPrice || posSL == 0)) ||
            (posType == POSITION_TYPE_SELL && (posSL > posOpenPrice || posSL == 0)))
         {
            ModifyPosition(ticket, newSL, posTP);
            Print("🎯 Breakeven set for position #", ticket);
         }
      }
      
      // === TRAILING STOP ===
      if(UseTrailingStop && profitPoints >= TrailingStart)
      {
         double newSL = 0;
         
         if(posType == POSITION_TYPE_BUY)
         {
            newSL = bid - (TrailingStep * _Point);
            if(newSL > posSL + (TrailingStep * _Point) || posSL == 0)
            {
               ModifyPosition(ticket, newSL, posTP);
               Print("📈 Trailing stop updated for BUY #", ticket);
            }
         }
         else
         {
            newSL = ask + (TrailingStep * _Point);
            if(newSL < posSL - (TrailingStep * _Point) || posSL == 0)
            {
               ModifyPosition(ticket, newSL, posTP);
               Print("📉 Trailing stop updated for SELL #", ticket);
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//| Modify Position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   
   if(!OrderSend(request, result))
   {
      Print("❌ Modify failed! Error: ", GetLastError());
      return false;
   }
   
   return (result.retcode == TRADE_RETCODE_DONE);
}

//+------------------------------------------------------------------+
//| Count Open Positions                                            |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check Time Filter                                               |
//+------------------------------------------------------------------+
bool CheckTimeFilter()
{
   if(!UseTimeFilter) return true;
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   if(time.hour < TradingStartHour || time.hour >= TradingEndHour)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Market Close Filter                                       |
//+------------------------------------------------------------------+
bool CheckMarketCloseFilter()
{
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   // Friday close check (usually 22:00-23:00 server time)
   if(time.day_of_week == 5) // Friday
   {
      if(time.hour >= 22 || (time.hour == 21 && time.min >= (60 - MinutesBeforeClose)))
         return false;
   }
   
   return true;
}


//+------------------------------------------------------------------+
//| Check News Filter (Simplified)                                  |
//+------------------------------------------------------------------+
bool CheckNewsFilter()
{
   if(!UseNewsFilter) return true;
   
   // Simplified news filter based on time
   // High-impact news usually at: 8:30, 10:00, 12:30, 14:00, 15:30 GMT
   MqlDateTime time;
   TimeToStruct(TimeGMT(), time);
   
   int currentMinute = time.hour * 60 + time.min;
   
   // News times in minutes from midnight GMT
   int newsTimes[] = {
      510,  // 08:30
      600,  // 10:00
      750,  // 12:30
      840,  // 14:00
      930   // 15:30
   };
   
   for(int i = 0; i < ArraySize(newsTimes); i++)
   {
      int newsTime = newsTimes[i];
      int timeDiff = MathAbs(currentMinute - newsTime);
      
      if(timeDiff <= MinutesBeforeNews || timeDiff <= MinutesAfterNews)
      {
         Print("📰 News filter active. Minutes to/from news: ", timeDiff);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Spread Filter                                             |
//+------------------------------------------------------------------+
bool CheckSpreadFilter()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   if(spread > MaxSpread)
   {
      Print("📊 Spread too wide: ", spread, " points (Max: ", MaxSpread, ")");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Uninit Reason Text                                          |
//+------------------------------------------------------------------+
string getUninitReasonText(int reasonCode)
{
   string text = "";
   switch(reasonCode)
   {
      case REASON_PROGRAM:     text = "Program stopped by user"; break;
      case REASON_REMOVE:      text = "Program removed from chart"; break;
      case REASON_RECOMPILE:   text = "Program recompiled"; break;
      case REASON_CHARTCHANGE: text = "Chart symbol or timeframe changed"; break;
      case REASON_CHARTCLOSE:  text = "Chart closed"; break;
      case REASON_PARAMETERS:  text = "Input parameters changed"; break;
      case REASON_ACCOUNT:     text = "Account changed"; break;
      default:                 text = "Unknown reason";
   }
   return text;
}

//+------------------------------------------------------------------+
