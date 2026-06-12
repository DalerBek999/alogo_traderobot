# 🤖 Forex AlgoTrader v2.0 - Complete Setup Guide

**Aziz Xalikov Strategy** - Parallel Channel Breakout with RSI Divergence  
Optimized for micro accounts ($10-$15) with advanced risk management

---

## ✨ Features

### 🎯 **Trading Strategy**
- **Parallel Channel Detection** - Automated pivot high/low analysis
- **RSI Divergence** - Bullish/bearish divergence confirmation  
- **Smart Breakout Entry** - Immediate execution on channel break
- **Dynamic SL/TP** - 1:1 (TP1) and 1:2 (TP2) risk-reward ratios
- **Multiple SL Methods** - Channel-based, Lookback, or ATR

### 🛡️ **Risk Management**
- **Micro Account Support** - Works with $10-$15 accounts
- **Dynamic Position Sizing** - Risk-based lot calculation (0.01-0.1 lots)
- **Daily Loss Limit** - Stops trading at 10% loss
- **Consecutive Loss Protection** - Stops after 3 consecutive losses
- **Demo-Only Mode** - Safety feature prevents real account trading

### 🔌 **MT5 Integration**
- **Real-time Data** - Live OHLCV, RSI, ATR calculations
- **Auto-reconnection** - Exponential backoff on connection loss
- **Position Monitoring** - Automatic TP1/TP2/SL management
- **Multiple Symbols** - EURUSD, GBPUSD, XAUUSD support

### 📊 **Performance Tracking**
- **Trade Journal** - Complete trade history with P&L
- **Win Rate Statistics** - Real-time performance metrics
- **Risk-Reward Tracking** - R-multiple calculations
- **Daily/Total P&L** - Comprehensive profit tracking

---

## 🚀 Quick Start Guide

### **Step 1: Install MetaTrader 5**

1. Download MT5 from your broker's website
2. Install and create a **DEMO account** (never use real money for testing!)
3. Note your:
   - Account number (login)
   - Password
   - Server name (e.g., "YourBroker-Demo")

### **Step 2: Install Python Dependencies**

Open terminal/command prompt:

```bash
cd alogo_traderobot/backend
pip install -r requirements.txt
```

### **Step 3: Configure Your Settings**

Edit `backend/.env` file:

```env
# === Your MT5 Demo Account ===
MT5_LOGIN=12345678               # Replace with your demo account number
MT5_PASSWORD=your_password       # Replace with your demo password
MT5_SERVER=YourBroker-Demo       # Replace with your server name
MT5_PATH=                        # Leave empty (auto-detect)

# === Account Settings ===
ACCOUNT_SIZE=15.0                # Your demo account balance
RISK_PER_TRADE=2.0               # Risk 2% per trade
MAX_OPEN_TRADES=1                # One trade at a time

# === Trading Symbols ===
TRADING_SYMBOLS=EURUSD,GBPUSD,XAUUSD

# === SAFETY - ALWAYS KEEP THIS TRUE FOR TESTING! ===
DEMO_ONLY=True                   # Prevents real account trading
MAX_DAILY_LOSS=10.0              # Stop at 10% daily loss
MAX_CONSECUTIVE_LOSSES=3         # Stop after 3 losses
```

### **Step 4: Start the Robot**

**Windows:**
```bash
START_ROBOT.bat
```

**Or manually:**
```bash
cd backend
python trading_bot.py
```

**Linux/Mac:**
```bash
cd backend
python trading_bot.py
```

---

## 📊 Strategy Explanation

### **How the Aziz Xalikov Strategy Works**

#### **1. Channel Detection Phase**

The robot looks for **parallel channels** formed by pivot highs and lows:

```
Bullish Channel (Falling):
     High 1 ●─────────● High 2
            │         │
            │ Channel │
            │         │
     Low 1  ●─────────● Low 2
            ↑ 
         Breakout = BUY Signal


Bearish Channel (Rising):
     High 1 ●─────────● High 2
            │         │
            │ Channel │
            │         │
     Low 1  ●─────────● Low 2
                      ↓
                   Breakout = SELL Signal
```

#### **2. Confirmation Requirements**

For a **BUY signal**, the robot checks:
- ✅ Bullish channel detected (falling or flat)
- ✅ RSI at channel low is oversold (≤ 35) OR
- ✅ Bullish divergence (price lower low, RSI higher low)
- ✅ Price closes **above** channel top line

For a **SELL signal**, the robot checks:
- ✅ Bearish channel detected (rising or flat)
- ✅ RSI at channel high is overbought (≥ 65) OR
- ✅ Bearish divergence (price higher high, RSI lower high)
- ✅ Price closes **below** channel bottom line

#### **3. Entry & Risk Management**

**Entry:** Next bar open (immediate execution)

**Stop Loss (SL):** Based on your configured method:
- `Kanal`: Channel extreme (lowest low for BUY, highest high for SELL)
- `Lookback`: Min/max of last 20 bars
- `ATR`: Entry ± 1.5× ATR

**Take Profit:**
- **TP1**: Entry + 1R (Risk amount)
- **TP2**: Entry + 2R (Double risk amount)

**Position Management:**
1. When TP1 is hit → Move SL to breakeven (entry price)
2. When TP2 is hit → Close entire position
3. If SL is hit → Close position (loss)

#### **4. Position Sizing (Micro Accounts)**

For a $15 account with 2% risk:
```
Risk Amount = $15 × 2% = $0.30
SL Distance = 20 pips
Lot Size = $0.30 / (20 pips × $1 per 0.01 lot) = 0.015 lots
→ Rounded to 0.01 lots (minimum)
```

---

## ⚙️ Advanced Configuration

### **Strategy Parameters**

Edit these in `backend/.env`:

```env
# Pivot Detection
FRACTAL_PERIOD=5              # Left/right bars for pivot (3-7)
MAX_BARS_BETWEEN=30           # Max bars between pivots (20-50)

# Channel Filtering
MAX_CHANNEL_RANGE=20.0        # Max channel height in pips (0=unlimited)
                              # For XAUUSD: 20.0, for EURUSD: 0.005

# RSI Settings
RSI_LENGTH=14                 # RSI period (14-21)
RSI_OVERBOUGHT=70             # Overbought level (65-75)
RSI_OVERSOLD=30               # Oversold level (25-35)

# Stop Loss Method
SL_METHOD=Lookback            # Options: Kanal, Lookback, ATR
SL_LOOKBACK=20                # Bars to look back for SL
SL_ATR_MULT=1.5               # ATR multiplier for SL

# Timeframe Filter
MIN_TIMEFRAME_MINUTES=15      # Minimum TF (5, 15, 30, 60)
```

### **Risk Management Tuning**

```env
# For $10 account:
ACCOUNT_SIZE=10.0
RISK_PER_TRADE=1.5            # Lower risk for smaller accounts

# For $15-20 account:
ACCOUNT_SIZE=15.0
RISK_PER_TRADE=2.0            # Standard risk

# Position Limits
MAX_OPEN_TRADES=1             # Conservative (1-2)
MAX_DAILY_LOSS=10.0           # Stop at 10% loss
MAX_CONSECUTIVE_LOSSES=3      # Stop after 3 losses
```

---

## 🔍 Monitoring Your Robot

### **Log Files**

All activity is logged to:
```
backend/logs/traderobot.log
```

Watch for:
- ✅ `Connected to MT5 account` - Connection successful
- 🎯 `Signal detected: BUY/SELL` - Trade signal found
- 🚀 `Executing trade` - Trade being placed
- ✅ `Position opened successfully` - Trade executed
- 📊 `TP1/TP2 reached` - Take profit hit
- ❌ `SL hit` - Stop loss hit

### **Real-time Console Output**

```
🔄 Trading Cycle - 2024-01-15 14:30:00
================================================
Analyzing EURUSD...
📊 Bullish Channel Detected: Slope=-0.000012, RSI@Low=28.45, Divergence=True
🎯 Signal detected: BUY EURUSD
   Entry: 1.09450
   SL: 1.09250
   TP1: 1.09650
   TP2: 1.09850
   Reason: Bullish channel breakout - RSI@Low: 28.45 + Bullish Divergence
🚀 Executing BUY trade for EURUSD
📊 Position Size Calculation:
   Symbol: EURUSD
   Entry: 1.09450, SL: 1.09250
   SL Distance: 0.00200 (20.0 pips)
   Lot Size: 0.01
   Expected Risk: $0.20 (1.33%)
✅ Trade executed successfully!
📊 Statistics: Trades: 1, Win Rate: 0.0%, P&L: $0.00
```

---

## 🛡️ Safety Features

### **1. Demo-Only Mode**
```env
DEMO_ONLY=True  # Robot REFUSES to trade on real accounts
```

### **2. Daily Loss Limit**
- Stops trading if daily loss ≥ 10% of account
- Resets at midnight

### **3. Consecutive Loss Protection**
- Stops trading after 3 consecutive losses
- Prevents emotional trading spiral
- Requires manual restart

### **4. Position Limits**
- Maximum 1 open trade at a time
- Prevents over-exposure

### **5. Lot Size Limits**
```env
MIN_LOT_SIZE=0.01    # Minimum (micro lot)
MAX_LOT_SIZE=0.1     # Maximum (safety cap)
```

---

## ❓ Troubleshooting

### **Problem: "MT5 initialize failed"**

**Solution:**
1. Make sure MT5 terminal is running
2. Check MT5 → Tools → Options → "Allow automated trading"
3. Verify server name in `.env` matches MT5

### **Problem: "Symbol EURUSD not found"**

**Solution:**
1. Open MT5 MarketWatch (Ctrl+M)
2. Right-click → Symbols → Find your symbol
3. Make sure it's visible in MarketWatch

### **Problem: "Trading is not allowed"**

**Solution:**
1. Check MT5 terminal connection (bottom right should be green)
2. Verify "AutoTrading" button is enabled in MT5 (should be green)
3. Check account has sufficient margin

### **Problem: "Insufficient funds" / "No money"**

**Solution:**
1. Check demo account balance in MT5
2. Reduce `RISK_PER_TRADE` in `.env`
3. Top up demo account (MT5 → Tools → Demo Account → Deposit)

### **Problem: Robot not finding signals**

**Solution:**
1. Markets might be ranging (no clear channels)
2. Try M5 or M30 timeframe: Edit `MIN_TIMEFRAME_MINUTES`
3. Increase `MAX_CHANNEL_RANGE` for wider channels
4. Wait for market movement (signals are rare, that's normal!)

---

## 📈 Expected Performance

### **Signal Frequency**
- **M15 Timeframe**: 2-5 signals per week per symbol
- **M5 Timeframe**: 5-10 signals per week per symbol

### **Win Rate**
- **Expected**: 50-65% (depends on market conditions)
- **Target**: >55% for profitability with 1:2 RR

### **Risk-Reward**
- **TP1 (1:1)**: Breakeven management
- **TP2 (1:2)**: Main profit target
- **Combined**: 1:1.5 average RR

---

## 📞 Support

### **Telegram Channel**
Join [@takrorlanmas_robotlar](https://t.me/takrorlanmas_robotlar) for:
- Strategy updates
- Trading signals
- Community support

### **Issues & Questions**
Open an issue on GitHub repository

---

## ⚠️ Disclaimer

**IMPORTANT:**
1. **Always test on DEMO account first** - Never risk real money until fully tested
2. **Past performance ≠ future results** - No strategy is guaranteed profitable
3. **Forex trading is risky** - Only trade with money you can afford to lose
4. **This is educational software** - Use at your own risk
5. **Monitor your trades** - Don't leave the robot unattended for long periods

---

## 🎓 Learning Resources

### **Strategy Concepts**
- **Parallel Channels**: Price ranges between two parallel trendlines
- **Breakout**: Price closes outside channel = trend change
- **RSI Divergence**: Price and RSI move in opposite directions
- **Risk-Reward**: Ratio of potential profit to potential loss

### **Recommended Timeframes**
- **M15 (15 minutes)**: Best balance of signals and reliability
- **M30 (30 minutes)**: Fewer but higher quality signals
- **H1 (1 hour)**: Very reliable but rare signals

### **Best Trading Sessions**
- **London**: 08:00-17:00 GMT (highest volatility)
- **New York**: 13:00-22:00 GMT (good volume)
- **Overlap**: 13:00-17:00 GMT (best time for EURUSD/GBPUSD)

---

## 🚀 Next Steps

1. ✅ Install MT5 and create demo account
2. ✅ Configure `backend/.env` with your credentials
3. ✅ Run `pip install -r requirements.txt`
4. ✅ Start robot: `START_ROBOT.bat`
5. ✅ Monitor logs and console output
6. ✅ Let it run for 1-2 weeks to collect data
7. ✅ Review performance in logs
8. ✅ Adjust parameters if needed
9. ✅ **Only after success on demo**: Consider small real account

---

**Good luck with your trading! 🚀📈**
