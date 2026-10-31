# سامانه پیش‌بینی قیمت طلا و ارز
## مستند فنی و معماری سیستم - نسخه 5.0
**آخرین به‌روزرسانی:** 2026-08-17

---

## 1. معرفی سیستم

سامانه پیش‌بینی قیمت طلا و ارز یک سیستم تحلیلی چندمدله است که با ترکیب
6 الگوریتم پیش‌بینی، تحلیل کلان اقتصادی، تحلیل تکنیکال پیشرفته، تشخیص
رژیم بازار، و تحلیل احساسات اخبار، پیش‌بینی 7 روزه برای:

- انس جهانی طلا (USD/oz)
- دلار آزاد (تومان)
- طلای 18 عیار (تومان/گرم)
- سکه بهار آزادی (تومان)

ارائه می‌دهد.

---

## 2. معماری کلی سیستم

```
DATA LAYER
  TGJU API      → انس، دلار، طلا18 (~3 سال)
  FRED API      → DXY، US10Y، VIX (180 روز)
  Frankfurter   → 12 ارز جهانی
  RSS Feeds     → FXStreet، Investing، MarketWatch
       ↓
ANALYSIS LAYER
  MathEngine    → همبستگی، گرنجر، هم‌انباشتگی
  MacroData     → DXY، US10Y، VIX تاریخچه
  NewsSentiment → NLP اخبار
       ↓
PREDICTION LAYER
  ARIMA(5,1,0) + Holt-Winters + Ridge + MC+GARCH + TA + Currency
  Regime Detection → Macro Adj → Direction Model → Ensemble
       ↓
VALIDATION LAYER
  BacktestEngine → Walk-Forward → Multi-Horizon
  SQLite → ثبت پیش‌بینی روزانه
       ↓
API + UI LAYER
  HTTP.jl → REST API → Dashboard (HTML/JS/Chart.js)
```

---

## 3. منابع داده

| منبع | داده | نوع | بازه |
|------|------|-----|------|
| TGJU | انس (ons) | واقعی | ~3 سال |
| TGJU | دلار (price_dollar_rl) | واقعی | ~3 سال |
| TGJU | طلا18 (geram18) | واقعی | ~3 سال |
| FRED | DXY (DTWEXBGS) | واقعی | 180 روز |
| FRED | US10Y (DGS10) | واقعی | 180 روز |
| FRED | VIX (VIXCLS) | واقعی | 180 روز |
| Frankfurter | 12 ارز | واقعی | ~3 سال |
| open.er-api | نرخ لحظه‌ای | واقعی | لحظه‌ای |
| FXStreet RSS | اخبار | زنده | 24h |
| Investing.com | اخبار | زنده | 24h |
| MarketWatch | اخبار | زنده | 24h |

---

## 4. مدل‌های پیش‌بینی

### 4.1 ARIMA(5,1,0)

**فرمول:**
```
Δyₜ = c + φ₁Δyₜ₋₁ + φ₂Δyₜ₋₂ + φ₃Δyₜ₋₃ + φ₄Δyₜ₋₄ + φ₅Δyₜ₋₅ + εₜ
```
- Δyₜ = yₜ - yₜ₋₁ (تفاضل اول)
- برآورد با Ridge: β = (X'X + λI)⁻¹ X'Y , λ=0.01

### 4.2 Holt-Winters Double Exponential

```
Level:   lₜ = α·yₜ + (1-α)·(lₜ₋₁ + bₜ₋₁)
Trend:   bₜ = β·(lₜ - lₜ₋₁) + (1-β)·bₜ₋₁
Forecast: ŷₜ₊ₕ = lₜ + h·bₜ
```
- α ∈ [0.1, 0.6] , β ∈ [0.01, 0.31] (بهینه‌سازی خودکار)

### 4.3 Ridge Regression (Currency Impact)

```
β_ridge = (X'X + λI)⁻¹ X'y    λ=1.0
X = ماتریس قیمت‌های 12 ارز (normalize شده)
```

### 4.4 Monte Carlo + GARCH(1,1)

**GARCH نوسان:**
```
σ²ₜ = ω + α·r²ₜ₋₁ + β·σ²ₜ₋₁
ω=0.00001, α=0.10, β=0.85
```

**Monte Carlo GBM (3000-5000 مسیر):**
```
Sₜ₊₁ = Sₜ · exp((μ_adj - σ²/2) + σ·Z)  Z~N(0,1)
μ_adj = 0.6·μ_long + 0.4·μ_recent
point = mean(S_T)
low   = quantile(S_T, 0.10)
high  = quantile(S_T, 0.90)
```

### 4.5 Technical Analysis

| شاخص | فرمول | آستانه |
|------|-------|--------|
| RSI(14) | 100 - 100/(1+RS) | >70 اشباع خرید, <30 اشباع فروش |
| MACD | EMA(12)-EMA(26) | histogram > 0 صعودی |
| BB(20) | SMA±2σ | خارج از باند سیگنال |
| Stoch(14) | (C-L14)/(H14-L14)×100 | >80 اشباع, <20 اشباع |
| ATR(14) | mean(|Pᵢ-Pᵢ₋₁|) | نوسان |
| ROC(10) | (P-P₁₀)/P₁₀×100 | مومنتوم |

```
score = Σ(weighted signals)
trend_factor = clamp(score/120, -0.07, +0.07)
pred[d] = P₀ × (1 + trend_factor × d/7)
```

### 4.6 Currency Impact

```
impact = Σ(βᵢ × r_recent_i) / n
S_d = S₀ × exp(impact × exp(-0.1×d))
βᵢ = Cov(r_currency, r_gold) / Var(r_currency)
```

---

## 5. ترکیب مدل‌ها (Ensemble)

### 5.1 Auto-Tuning وزن‌ها

```
Walk-Forward: window=60, step=5, validation=20 days
MAPE_m = mean(|pred - actual| / actual)
w_m = (1/MAPE_m) / Σ(1/MAPE_j)
```

### 5.2 Regime Boost

| Regime | ARIMA | Holt | Ridge | MC | TA | Currency |
|--------|-------|------|-------|-----|-----|----------|
| TRENDING_UP | 1.1 | 1.0 | 1.2 | 0.9 | 1.3 | 1.0 |
| TRENDING_DOWN | 1.1 | 0.9 | 1.0 | 1.0 | 1.3 | 0.9 |
| RANGING | 1.0 | 1.3 | 1.0 | 1.2 | 1.0 | 1.0 |
| VOLATILE | 0.7 | 0.7 | 0.8 | 1.8 | 0.9 | 0.8 |

### 5.3 Direction Agreement Boost

```
boost = 1.18  (هم‌جهت با مدل direction)
boost = 0.96  (خنثی)
boost = 0.72  (خلاف جهت)
```

### 5.4 پیش‌بینی نهایی

```
gold[d] = base[d]
        × (1 + macro_adj × d/7)
        × (1 + z_reversion × exp(-0.2d))
        × (1 + dir_bias × d/7)
        × (1 + sent_factor × exp(-0.3d))
```

---

## 6. تشخیص رژیم بازار

```
Vol_ann = std(log_returns_20d) × sqrt(252) × 100
ADX ≈ |avg_up - avg_dn| / (avg_up + avg_dn) × 100
score = mom20×0.35 + mom10×0.25 + mom5×0.15 + MA×0.15 + macro×0.10

VOLATILE      → Vol_ann > 30% یا VIX > 35
TRENDING_UP   → ADX > 35 و score > 8
TRENDING_DOWN → ADX > 35 و score < -8
MILD_UP       → ADX > 20 و score > 4
MILD_DOWN     → ADX > 20 و score < -4
RANGING       → غیر از موارد بالا
```

---

## 7. مدل جهت‌یابی

```
score = mom(3d)×1.0 + mom(5d)×1.2 + mom(10d)×1.4 + mom(20d)×1.1
      + MA_signal + RSI_signal + MACD_signal
      + Z_signal + Breakout + DXY + US10Y + VIX + Sentiment

P(up) = 1 / (1 + exp(-score/9))    [Logistic]

P>0.56 → UP | P<0.44 → DOWN | else → NEUTRAL
dir_bias = (P(up) - 0.5) × 0.008
```

---

## 8. تعدیل کلان اقتصادی

```
DXY:   adj = -corr × trend × 0.7  ±  level_bias
US10Y: adj = rate_signal (-0.008 to +0.006)
VIX:   adj = vix_signal  (-0.003 to +0.015)
total: macro_adj = clamp(Σadj, -0.03, +0.03)
```

---

## 9. Z-Score Mean Reversion

```
Z = (P - μ₂₀) / σ₂₀
z_adj = clamp(-Z × 0.015, -0.04, +0.04)
effect[d] = z_adj × exp(-0.2d)
```

---

## 10. فرمول طلای ایران

```
Gold18 = (Gold_oz / 31.1035) × 0.75 × USD_IRR × MF
MF = Gold18_real / (Gold_oz/31.1035 × 0.75 × USD_IRR)
MF_avg = Σ(MF_i × exp(-0.08(n-i))) / Σ(exp(-0.08(n-i)))
MF ∈ [0.87, 1.13]

Coin = Gold18 × 8.133 × (21.6/18) × premium
premium ∈ [1.02, 1.08]
```

---

## 11. پیش‌بینی دلار

```
USD = 0.35×VAR(3) + 0.25×ARIMA + 0.20×Holt + 0.20×MC

VAR(3):
  ΔUSDₜ = c₁ + Σᵢ(φ₁ᵢΔUSDₜ₋ᵢ + φ₂ᵢΔGoldₜ₋ᵢ)  i=1..3
```

---

## 12. تحلیل همبستگی

```
Pearson:       ρ = Cov(X,Y) / (σ_X × σ_Y)
Spearman:      ρ_s رتبه‌بندی
Beta:          β = Cov(r_curr, r_gold) / Var(r_curr)
Granger F:     F = ((RSS_R - RSS_U)/lags) / (RSS_U/(T-2k-1))
Cointegration: ADF test on regression residuals

impact = |ρ|×0.25 + |ρ_s|×0.15 + |β|×0.20 + R²×0.20
       + F×0.10 + |τ|×0.10
```

---

## 13. اطمینان (Confidence)

```
Conf = 0.40×base + 0.25×agreement + 0.20×dir_conf + 0.15×regime_conf
     - event_penalty
Conf ∈ [0.35, 0.82]
```

---

## 14. Walk-Forward Validation

```
for i in (min_train+1) : step : (n-horizon):
    train  = prices[i-window : i]
    actual = prices[i + horizon]
    pred   = ensemble(train)
    error  = |pred - actual| / actual

window=60, step=5, horizon∈[1,3,7]
```

---

## 15. پارامترهای کلیدی

| پارامتر | مقدار |
|---------|-------|
| GARCH ω/α/β | 0.00001 / 0.10 / 0.85 |
| MC simulations | 3000-5000 |
| CI bounds | 10th - 90th percentile |
| ARIMA order | (5,1,0) |
| Ridge λ | 0.01 - 1.0 |
| Market Factor | [0.87, 1.13] |
| Direction threshold | 0.56 / 0.44 |
| Macro adj cap | [-3%, +3%] |
| Walk-forward window | 60 روز |
| Walk-forward step | 5 روز |

---

## 16. ساختار دیتابیس

```sql
actual_snapshots: trade_date, gold_oz, usd_irr, iran_gold, dxy, vix, us10y
forecast_runs:    run_id, target_date, horizon_day,
                  gold_point/low/high, usd_point/low/high,
                  iran_point/low/high, confidence, trend
```

---

## 17. API Endpoints

| Endpoint | توضیح |
|----------|-------|
| GET / | داشبورد |
| GET /api/data | داده کامل JSON |
| GET /api/refresh | به‌روزرسانی |
| GET /api/backtest?days=N | بک‌تست N روزه |

---

## 18. محدودیت‌ها

1. رویدادهای سیاسی غیرقابل پیش‌بینی → خطا تا 15%
2. ضریب بازار ایران ناپایدار است
3. تعطیلات پنجشنبه/جمعه → gap در داده
4. FRED downtime → fallback پیش‌فرض
5. داده TGJU حداکثر ~3 سال
6. Direction accuracy ~58% (نه 100%)

---

## 19. فناوری

| مورد | مقدار |
|------|-------|
| نسخه | 5.0 |
| زبان | Julia 1.12.x |
| سرور | HTTP.jl |
| دیتابیس | SQLite |
| UI | HTML/CSS/JS |
| چارت | Chart.js 4.4 |
| فونت | Vazirmatn |

---
*آخرین به‌روزرسانی: 2026-08-17*
