# 🤖 ProAdvancedTrader v1.0 - MQL5 Robot Setup Guide

## 📋 **Robot Xususiyatlari**

### ✨ **Asosiy Imkoniyatlar**

#### **1. Multi-Indikator Strategiya**
- ✅ **RSI (Relative Strength Index)** - Oversold/Overbought aniqlash
- ✅ **MACD (Moving Average Convergence Divergence)** - Trend o'zgarishini aniqlash
- ✅ **Bollinger Bands** - Volatillik va price action
- ✅ **ATR (Average True Range)** - Dinamik SL/TP
- ✅ **ADX (Average Directional Index)** - Trend kuchi

#### **2. Multi-Timeframe Analysis**
- ✅ Joriy timeframe (M15/M30/H1)
- ✅ H1 timeframe - Trend tasdiq
- ✅ H4 timeframe - Asosiy yo'nalish

#### **3. Advanced Risk Management**
- ✅ **Dynamic Lot Sizing** - Balansingizga qarab avtomatik hisob
- ✅ **Trailing Stop** - Foyda himoyasi
- ✅ **Breakeven** - SL ni kirish narxiga ko'chirish
- ✅ **ATR-based SL/TP** - Market volatilitiga moslashadi
- ✅ **1:2 Risk-Reward Ratio** - Har bir riskka 2x foyda

#### **4. Smart Filters**
- ✅ **Time Filter** - Soat bo'yicha trade vaqtini cheklash
- ✅ **Market Close Filter** - Bozor yopilishidan 15-20 daqiqa oldin to'xtaydi
- ✅ **News Filter** - Yangiliklar vaqtida va atrofida to'xtaydi
- ✅ **Spread Filter** - Keng spread paytida trade qilmaydi
- ✅ **Trend Filter** - Faqat kuchli trendda ishlaydi (ADX)

---

## 🚀 **O'rnatish (Installation)**

### **1. Faylni MetaEditor ga yuklash**

1. **MetaTrader 5** ni oching
2. **F4** tugmasini bosing (yoki Tools → MetaQuotes Language Editor)
3. **File → Open** → `ProAdvancedTrader_v1.mq5` ni tanlang
4. **F7** tugmasini bosing (Compile)
5. Agar xatolik bo'lmasa, "0 errors, 0 warnings" ko'rinadi ✅

### **2. Chartga qo'shish**

1. MT5 da chart oching (masalan EURUSD, M15)
2. **Navigator** oynasida **Expert Advisors** ni toping
3. `ProAdvancedTrader_v1` ni chartga sudrab tashlang
4. Sozlamalar oynasi ochiladi

---

## ⚙️ **Sozlamalar (Settings)**

### **📊 Trading Settings**

```
RiskPercent = 2.0         // Har bir tradeda 2% risk (1-5% tavsiya)
MinLotSize = 0.01         // Minimum lot (micro account uchun)
MaxLotSize = 0.5          // Maksimum lot (safety cap)
MaxSpread = 30            // Maksimal spread (points)
MagicNumber = 123456      // Robot ID raqami
MaxOpenTrades = 1         // Bir vaqtda 1 ta trade
```

**Tavsiya:**
- $10-20 balans: `RiskPercent = 1.5`, `MaxLotSize = 0.1`
- $50-100 balans: `RiskPercent = 2.0`, `MaxLotSize = 0.3`
- $200+ balans: `RiskPercent = 2.5`, `MaxLotSize = 0.5`

---

### **🎯 Strategy Parameters**

```
RSI_Period = 14
RSI_Oversold = 30         // Pastroq = ko'proq signal
RSI_Overbought = 70       // Yuqoriroq = ko'proq signal
MACD_Fast = 12
MACD_Slow = 26
MACD_Signal = 9
BB_Period = 20
BB_Deviation = 2.0
ATR_Period = 14
ATR_Multiplier = 1.5      // SL masofasi (1.5 = 150%)
ADX_Period = 14
ADX_MinLevel = 25.0       // Trend kuchini talab qiladi
```

**Optimizatsiya:**
- Kam signal kerak: `ADX_MinLevel = 30`, `RSI_Oversold = 25`
- Ko'proq signal kerak: `ADX_MinLevel = 20`, `RSI_Oversold = 35`

---

### **🛡️ Risk Management**

```
UseTrailingStop = true
TrailingStart = 200       // 20 pips profit dan keyin boshlaydi
TrailingStep = 50         // 5 pips step bilan
UseBreakeven = true
BreakevenStart = 150      // 15 pips profit da
BreakevenProfit = 10      // Breakeven + 1 pip
```

**Volatillik asosida:**
- EURUSD: `TrailingStart = 150`, `TrailingStep = 30`
- GBPUSD: `TrailingStart = 200`, `TrailingStep = 50`
- XAUUSD: `TrailingStart = 300`, `TrailingStep = 100`

---

### **⏰ Time Filters**

```
UseTimeFilter = true
MinutesBeforeClose = 15   // Bozor yopilishidan 15 daqiqa oldin
TradingStartHour = 1      // Server vaqti: 01:00
TradingEndHour = 22       // Server vaqti: 22:00
```

**London Session uchun:**
- `TradingStartHour = 8`
- `TradingEndHour = 17`

---

### **📰 News Filter**

```
UseNewsFilter = true
MinutesBeforeNews = 15
MinutesAfterNews = 15
```

**News vaqtlari (GMT):**
- 08:30 - USD Employment, CPI
- 10:00 - EUR Economic Data
- 12:30 - CAD Employment
- 14:00 - USD FOMC Minutes
- 15:30 - USD Oil Inventory

---

## 📈 **Qaysi Symbolda Ishlaydi?**

### **Tavsiya etilgan juftliklar:**

| Symbol | Timeframe | Sozlamalar |
|--------|-----------|------------|
| **EURUSD** | M15, M30, H1 | Default settings OK |
| **GBPUSD** | M15, M30 | `ATR_Multiplier = 2.0` |
| **XAUUSD** | M30, H1 | `ATR_Multiplier = 2.5`, `TrailingStart = 300` |
| **AUDUSD** | M30, H1 | Default settings OK |
| **USDJPY** | M15, M30 | Default settings OK |

---

## 🧪 **Testlash (Backtesting)**

### **Strategy Tester da test qilish:**

1. MT5 da **Ctrl+R** (Strategy Tester)
2. **Expert**: `ProAdvancedTrader_v1`
3. **Symbol**: `EURUSD`
4. **Period**: `M15`
5. **Date**: Oxirgi 3 oy
6. **Mode**: `Every tick`
7. **Optimization**: `Disabled`
8. **Start** tugmasini bosing

### **Kutilgan natijalar:**

- **Win Rate**: 50-65%
- **Profit Factor**: >1.5
- **Max Drawdown**: <20%
- **Total Trades**: 50-100 (3 oyda)

---

## 🔍 **Monitoring & Logs**

### **Konsolda ko'rinadigan loglar:**

```
✅ Robot initialized successfully!
📊 Symbol: EURUSD
⏰ Timeframe: M15
💰 Risk per trade: 2.0%

📊 Market Analysis: BUY=6 SELL=2
   RSI: 28.5 | MACD: -0.0015 | ADX: 32.1
   H1 RSI: 35.2 | H4 RSI: 42.1

🚀 BUY SIGNAL DETECTED!

💰 Lot Calculation:
   Balance: $50.00
   Risk: $1.00 (2.0%)
   SL Points: 150
   Lot Size: 0.01

✅ Trade opened successfully!
   Type: BUY
   Lot: 0.01
   Price: 1.08450
   SL: 1.08300 | TP: 1.08750
```

---

## ⚠️ **Xatoliklarni Tuzatish**

### **❌ "Indicator create error"**
**Sabab**: Indikator yuklanmadi
**Yechim**: 
- MT5 ni qayta ishga tushiring
- Expert ni qayta compile qiling

### **❌ "Trade not allowed"**
**Sabab**: AutoTrading o'chirilgan
**Yechim**: 
- MT5 toolbar da "AutoTrading" tugmasini bosing (yashil bo'lishi kerak)
- Tools → Options → Expert Advisors → "Allow automated trading" ✓

### **❌ "Not enough money"**
**Sabab**: Balance yetarli emas
**Yechim**: 
- `RiskPercent` ni kamaytiring (1.0%)
- `MaxLotSize` ni kamaytiring (0.05)

### **❌ "Spread too wide"**
**Sabab**: Spread `MaxSpread` dan katta
**Yechim**: 
- `MaxSpread` ni oshiring (50-100)
- Yoki past spread vaqtida trade qiling

---

## 📊 **Real Balansda Ishlatish**

### **⚠️ MUHIM! Demo da test qiling:**

1. **Kamida 2 hafta** demo accountda ishlating
2. **Kamida 20 ta trade** natijasini kuzating
3. **Profit Factor > 1.5** bo'lishi kerak
4. **Max Drawdown < 15%** bo'lishi kerak

### **Real accountga o'tish:**

1. **Kichik balans** bilan boshlang ($50-$100)
2. `RiskPercent = 1.0` dan boshlang
3. `MaxLotSize = 0.1` qo'ying
4. Birinchi oyda natijalarni kuzating

---

## 🎯 **Optimizatsiya Maslahatlari**

### **Ko'proq signal olish uchun:**
```
ADX_MinLevel = 20
RSI_Oversold = 35
RSI_Overbought = 65
```

### **Sifatli signallar uchun:**
```
ADX_MinLevel = 30
RSI_Oversold = 25
RSI_Overbought = 75
```

### **Conservative (xavfsiz):**
```
RiskPercent = 1.0
MaxLotSize = 0.05
TrailingStart = 300
```

### **Aggressive (tajribali treyderlar):**
```
RiskPercent = 3.0
MaxLotSize = 1.0
TrailingStart = 150
```

---

## 📞 **Yordam & Support**

- **Telegram**: @takrorlanmas_robotlar
- **GitHub**: https://github.com/DalerBek999/alogo_traderobot

---

## ⚠️ **Disclaimer**

1. **Demo da test qiling** - Hech qachon darhol real accountda ishlatmang
2. **Forex trading xavfli** - Faqat yo'qotishga qodir pulni sarflang
3. **Past performance ≠ future results** - O'tmishdagi natija kelajakni kafolatlamaydi
4. **Risk managementni hurmat qiling** - `RiskPercent` ni 5% dan oshirmang
5. **Monitoring muhim** - Loglarni har kuni tekshiring

---

**Omad va foyda! 🚀📈**
