# Trade AI Pro 3.0 — Architecture

## Halol cheklov

**100% aniq / xatosiz savdo boti mavjud emas.** Professional daraja: 55–70% win rate + yaxshi risk/reward + uzoq muddat foyda.

## Pipeline

```
Data Layer → Quant Engine → Decision Engine → Rule Engine → (ixtiyoriy LLM tushuntirish)
```

| Qatlam | Vazifa |
|--------|--------|
| **data_layer** | MT5, Twelve Data, OHLC M15/H1/H4, jonli narx |
| **quant_engine** | RSI, MACD, EMA, ADX, regime, confluence |
| **decision_engine** | LONG % / SHORT %, SL/TP, ishonch |
| **rule_engine** | Risk %, demo data, grafik ziddiyat, range filter |
| **llm_analyst** | O'zbek tushuntirish (OpenAI ixtiyoriy) |

## Ishga tushirish

1. `npm install` → `npm run dev`
2. Haqiqiy narx: MT5 terminal + `MT5_ENABLED=true` yoki `TWELVE_DATA_API_KEY`
3. `http://localhost:5173` — LONG/SHORT % ko'rinadi
4. **KIRMANG** — signal zaif yoki risk o'tmaganda (aldov emas)

## Keyingi qadamlar (ixtiyoriy)

- ccxt (Binance/Bybit)
- Orderflow, funding rate
- Auto execution bot
- VPS deployment (Docker)
