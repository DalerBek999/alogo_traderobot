# Trade AI v2 — To'liq platforma

XAUUSD va Forex uchun: **grafik tahlil**, **MT5 order**, **backtest**, **savdo jurnali**, **ICT/SMC/FVG o'qitish**, **Telegram bot**.

## Modullar

| Modul | Tavsif |
|-------|--------|
| **Tahlil** | Rasm → AI Buy/Sell, ICT/SMC/FVG, risk, o'qitish rejimi |
| **MT5** | Jonli bid/ask, avtomatik BUY/SELL order |
| **Backtest** | MA Cross / RSI — tarixiy win rate, profit factor |
| **Jurnal** | Barcha tahlil va savdolar SQLite da, statistika |
| **O'qitish** | SMC, FVG, ICT, risk darslari |
| **Telegram** | Rasmdan tahlil, /price, avto-jurnal |

## Brauzerda ishga tushirish (iBank kabi — 2 buyruq)

Loyiha **ildiz** papkasida (`Trade AI`), **bitta terminal**:

```powershell
cd "c:\Users\user\Desktop\Trade AI"
npm install
npm run dev
```

| Buyruq | Nima qiladi |
|--------|-------------|
| `npm install` | Python backend + React frontend avtomatik o‘rnatiladi |
| `npm run dev` | API `:8000` + sayt `:5173` birga ishga tushadi, brauzer ochiladi |

To‘xtatish: `Ctrl+C`

> `backend` yoki `frontend` ichiga kirib alohida buyruq yozish **shart emas**.

### OPENAI kaliti (grafik tahlil uchun)

`backend\.env` faylida (birinchi `npm install` da avtomatik yaratiladi):

```
OPENAI_API_KEY=sk-...
```

Ixtiyoriy: `TELEGRAM_BOT_TOKEN`, `TWELVE_DATA_API_KEY`, `MT5_LOGIN` va hokazo — `backend\.env.example` da.

---

### Alohida terminal (ixtiyoriy, eski usul)

Backend: `cd backend` → `.\venv\Scripts\Activate.ps1` → `python main.py`  
Frontend: `cd frontend` → `npm run dev`

## MT5

1. MetaTrader 5 o'rnating va broker hisobiga kiring  
2. Terminal **ochiq** qoldiring  
3. Ilovada **MT5** tab → ulanishni tekshiring → order  

`MetaTrader5` faqat **Windows** da ishlaydi.

## Telegram

1. [@BotFather](https://t.me/BotFather) → `/newbot` → token  
2. `.env` → `TELEGRAM_BOT_TOKEN`  
3. Backend qayta ishga tushiring  
4. Botga grafik yuboring (caption: `XAUUSD`)

## Ogohlantirish

Bu tizim **ta'lim va yordam** uchun. Bozor bashorati 100% emas. Real pul bilan ehtiyotkor savdo qiling.
