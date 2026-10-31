# ============================================================
# Gold & Currency Prediction System - Technical Documentation
# Version 5.0
# ============================================================

doc = """
# سامانه پیش‌بینی قیمت طلا و ارز
## مستند فنی و معماری سیستم - نسخه 5.0

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
┌─────────────────────────────────────────────────────────┐
│                    DATA LAYER                           │
│  TGJU API → انس، دلار، طلا18                           │
│  FRED API → DXY، US10Y، VIX                            │
│  Frankfurter API → 12 ارز جهانی                       │
│  RSS Feeds → FXStreet، Investing، MarketWatch          │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────┐
│                 ANALYSIS LAYER                          │
│  MathEngine: همبستگی، گرنجر، هم‌انباشتگی             │
│  MacroData: DXY، US10Y، VIX تاریخچه                   │
│  NewsSentiment: NLP اخبار                             │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────┐
│                PREDICTION LAYER                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │  ARIMA   │ │  Holt-   │ │  Ridge   │ │   MC+    │  │
│  │ (5,1,0)  │ │ Winters  │ │   Reg    │ │  GARCH   │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
│  ┌──────────┐ ┌──────────┐                             │
│  │Technical │ │Currency  │                             │
│  │ Analysis │ │  Impact  │                             │
│  └──────────┘ └──────────┘                             │
│                                                         │
│  Regime Detection → Macro Adjustment → Direction Model │
│  Sentiment Adjustment → Z-Score → Agreement Boost      │
│  Auto-Weight Tuning → Ensemble → Final Prediction      │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────┐
│               VALIDATION LAYER                          │
│  BacktestEngine: Walk-Forward، 1-step ahead            │
│  Storage (SQLite): ثبت پیش‌بینی روزانه                │
│  Multi-Horizon: دقت 1/3/7 روزه                        │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────┐
│                  API + UI LAYER                         │
│  HTTP.jl Server → REST API → HTML/JS Dashboard         │
│  Chart.js → تاریخ شمسی → Trail/Backtest/Forecast      │
└─────────────────────────────────────────────────────────┘
```

---

## 3. منابع داده

| منبع | داده | نوع | بازه |
|------|------|-----|------|
| TGJU API | انس جهانی (ons) | واقعی | ~3 سال |
| TGJU API | دلار آزاد (price_dollar_rl) | واقعی | ~3 سال |
| TGJU API | طلای 18 عیار (geram18) | واقعی | ~3 سال |
| FRED | DXY (DTWEXBGS) | واقعی | 180 روز |
| FRED | US10Y (DGS10) | واقعی | 180 روز |
| FRED | VIX (VIXCLS) | واقعی | 180 روز |
| Frankfurter | 12 ارز جهانی | واقعی | ~3 سال |
| open.er-api | نرخ لحظه‌ای | واقعی | لحظه‌ای |
| FXStreet RSS | اخبار فارکس | زنده | 24 ساعت |
| Investing.com RSS | اخبار اقتصادی | زنده | 24 ساعت |
| MarketWatch RSS | اخبار بازار | زنده | 24 ساعت |

---

## 4. مدل‌های پیش‌بینی

### 4.1 ARIMA(5,1,0)

**توضیح:** مدل خودبازگشتی مرتبه 5 با یک‌بار تفاضل‌گیری

**فرمول:**
```
Δyₜ = c + φ₁·Δyₜ₋₁ + φ₂·Δyₜ₋₂ + φ₃·Δyₜ₋₃ + φ₄·Δyₜ₋₄ + φ₅·Δyₜ₋₅ + εₜ
```
جایی که:
- Δyₜ = yₜ - yₜ₋₁ (تفاضل اول)
- φᵢ = ضرایب خودبازگشتی (برآورد با Ridge Regression)
- λ = 0.01 (پارامتر تنظیم Ridge)

**برآورد پارامترها:**
```
β̂ = (X'X + λI)⁻¹ X'Y
```

**محاسبه R²:**
```
R² = 1 - SSR/SST = 1 - Σ(yᵢ - ŷᵢ)²/Σ(yᵢ - ȳ)²
```

---

### 4.2 Holt-Winters Double Exponential Smoothing

**توضیح:** هموارسازی نمایی مضاعف با بهینه‌سازی خودکار پارامترها

**فرمول‌ها:**
```
Level:  lₜ = α·yₜ + (1-α)·(lₜ₋₁ + bₜ₋₁)
Trend:  bₜ = β·(lₜ - lₜ₋₁) + (1-β)·bₜ₋₁
```

**پیش‌بینی h گام جلوتر:**
```
ŷₜ₊ₕ = lₜ + h·bₜ
```

**بهینه‌سازی پارامترها:**
```
(α*, β*) = argmin MAPE(validation set)
α ∈ {0.1, 0.2, ..., 0.6}
β ∈ {0.01, 0.06, ..., 0.31}
```

---

### 4.3 Ridge Regression (Currency Impact)

**توضیح:** رگرسیون خطی با تنظیم L2 بر اساس 12 ارز جهانی

**فرمول:**
```
ŷ = X·β̂ridge
β̂ridge = (X'X + λI)⁻¹ X'y
```
جایی که:
- X = ماتریس قیمت‌های ارزها (normalize شده)
- λ = 1.0 (پارامتر Ridge)

**نرمال‌سازی:**
```
X_norm = (X - μ) / σ
```

**پیش‌بینی آینده:** رشد خطی هر ارز بر اساس میانگین 7 روز اخیر

---

### 4.4 Monte Carlo + GARCH(1,1)

**توضیح:** شبیه‌سازی 3000-5000 مسیر قیمتی با نوسان متغیر زمانی

**GARCH(1,1) - پیش‌بینی نوسان:**
```
σ²ₜ = ω + α·r²ₜ₋₁ + β·σ²ₜ₋₁
```
پارامترها:
- ω = 0.00001 (پایه نوسان)
- α = 0.1 (واکنش به شوک)
- β = 0.85 (ماندگاری نوسان)
- α + β = 0.95 < 1 (پایداری مدل)

**پیش‌بینی نوسان h گام جلوتر:**
```
σ²ₜ₊ₕ = ω/(1-α-β) + (α+β)ʰ·(σ²ₜ - ω/(1-α-β))
```

**Monte Carlo GBM:**
```
Sₜ₊₁ = Sₜ · exp((μ_adj - σ²ₜ/2) + σₜ·Zₜ)
```
جایی که:
- μ_adj = 0.6·μ_long + 0.4·μ_recent (میانگین تعدیل‌شده)
- Z ~ N(0,1) (اعداد تصادفی نرمال)

**خروجی:**
```
point = mean(S_T across all simulations)
low   = quantile(S_T, 0.10)
high  = quantile(S_T, 0.90)
```

---

### 4.5 Technical Analysis

**شاخص‌های محاسبه‌شده:**

**RSI (14 روزه):**
```
RS = Average Gain / Average Loss
RSI = 100 - 100/(1 + RS)
```
تفسیر: RSI > 70 → اشباع خرید، RSI < 30 → اشباع فروش

**MACD:**
```
MACD = EMA(12) - EMA(26)
Signal = EMA(MACD, 9)
Histogram = MACD - Signal
```

**Bollinger Bands (20 روزه):**
```
Middle = SMA(20)
Upper  = SMA(20) + 2·σ(20)
Lower  = SMA(20) - 2·σ(20)
%BB    = (Price - Lower) / (Upper - Lower)
```

**Stochastic Oscillator (14 روزه):**
```
%K = (Close - Low₁₄) / (High₁₄ - Low₁₄) × 100
```

**ATR (14 روزه):**
```
ATR = mean(|Priceᵢ - Priceᵢ₋₁|) for i in last 14 days
```

**Rate of Change (10 روزه):**
```
ROC₁₀ = (Price_today - Price_10days_ago) / Price_10days_ago × 100
```

**امتیاز تکنیکال:**
```
Score = Σ(weighted signals from RSI, MACD, MA, BB, Stoch, Momentum)
trend_factor = clamp(Score/120, -0.07, 0.07)
prediction[d] = current_price × (1 + trend_factor × d/days)
```

---

### 4.6 Currency Impact

**توضیح:** تأثیر حرکت ارزها بر طلا از طریق بتا

**فرمول:**
```
impact = Σ(βᵢ × rᵢ_recent) / n_currencies
```
جایی که:
- βᵢ = Cov(rᵢ, r_gold) / Var(rᵢ)
- rᵢ_recent = میانگین بازده 7 روز اخیر ارز i

**پیش‌بینی:**
```
S_d = S_0 × exp(impact × exp(-0.1×d))
```

---

## 5. منطق ترکیب مدل‌ها (Ensemble)

### 5.1 Auto-Tuning وزن‌ها

**روش:** Walk-Forward با پنجره 60 روزه، 20 روز validation

**فرمول وزن‌دهی:**
```
MAPE_m = mean(|pred_m - actual| / actual) over validation set
w_m = (1/MAPE_m) / Σ(1/MAPE_j)
```

### 5.2 Regime Boost

| Regime | ARIMA | Holt | Ridge | MC | TA | Currency |
|--------|-------|------|-------|-----|-----|----------|
| TRENDING_UP | 1.1 | 1.0 | 1.2 | 0.9 | 1.3 | 1.0 |
| TRENDING_DOWN | 1.1 | 0.9 | 1.0 | 1.0 | 1.3 | 0.9 |
| MILD_UP | 1.0 | 1.0 | 1.1 | 1.0 | 1.1 | 1.0 |
| RANGING | 1.0 | 1.3 | 1.0 | 1.2 | 1.0 | 1.0 |
| VOLATILE | 0.7 | 0.7 | 0.8 | 1.8 | 0.9 | 0.8 |

### 5.3 Direction Agreement Boost

```
boost_m = 1.18  if model_m direction == expected direction
boost_m = 0.96  if model_m direction == neutral
boost_m = 0.72  if model_m direction != expected direction
```

### 5.4 پیش‌بینی نهایی طلا

```
base_d = Σ(w_m × pred_m_d)
gold_d = base_d × (1 + macro_adj × d/7)
                × (1 + z_reversion × exp(-0.2×d))
                × (1 + dir_bias × d/7)
                × (1 + sent_factor × exp(-0.3×d))
```

---

## 6. تشخیص رژیم بازار

### 6.1 پارامترهای محاسبه

**نوسان سالانه (20 روزه):**
```
Vol_ann = std(log_returns_20d) × sqrt(252) × 100
```

**مومنتوم‌های مختلف:**
```
mom5  = (P_t - P_{t-5}) / P_{t-5} × 100
mom10 = (P_t - P_{t-10}) / P_{t-10} × 100
mom20 = (P_t - P_{t-20}) / P_{t-20} × 100
```

**ADX تخمینی:**
```
ADX = |avg_up - avg_dn| / (avg_up + avg_dn) × 100
```

**امتیاز رژیم:**
```
score = mom20×0.35 + mom10×0.25 + mom5×0.15
      + (ma10>ma50 ? 1 : -1)×15×0.15
      + DXY_factor×0.05 + VIX_factor×0.05
```

### 6.2 قوانین تشخیص

```
if Vol_ann > 30% or VIX > 35:
    regime = VOLATILE
elif ADX > 35 and score > 8:
    regime = TRENDING_UP
elif ADX > 35 and score < -8:
    regime = TRENDING_DOWN
elif ADX > 20 and score > 4:
    regime = MILD_UP
elif ADX > 20 and score < -4:
    regime = MILD_DOWN
else:
    regime = RANGING
```

---

## 7. مدل جهت‌یابی (Direction Probability)

### 7.1 طلا

**امتیازدهی سیگنال‌ها:**
```
score += momentum(3d) × 1.0   → [-5, +5]
score += momentum(5d) × 1.2   → [-6, +6]
score += momentum(10d) × 1.4  → [-8, +8]
score += momentum(20d) × 1.1  → [-10, +10]
score += (ma10>ma20 ? +5 : -5)
score += (ma20>ma50 ? +7 : -7)
score += RSI_signal           → [-20, +20]
score += MACD_signal          → [-6, +6]
score += Z_score_signal       → [-8, +8]
score += breakout_signal      → [-7, +7]
score += DXY_signal           → [-5, +4]
score += US10Y_signal         → [-4, +3]
score += VIX_signal           → [-1, +4]
score += sentiment × 1.5      → [-6, +6]
```

**تبدیل به احتمال (Logistic):**
```
P(up) = 1 / (1 + exp(-score/9))
```

**تفسیر:**
```
P(up) > 0.56 → UP (تمایل صعودی)
P(up) < 0.44 → DOWN (تمایل نزولی)
otherwise    → NEUTRAL (خنثی)
```

**تأثیر بر پیش‌بینی:**
```
dir_bias = (P(up) - 0.5) × 0.008
gold_d  *= (1 + dir_bias × d/7)
```

---

## 8. تعدیل کلان اقتصادی

### 8.1 DXY

**همبستگی تاریخی:**
```
c_DXY = Corr(Δlog(Gold), Δlog(DXY))
```

**تعدیل ترند:**
```
dxy_trend = mean(Δlog(DXY), last 7 days)
dxy_adj   = -c_DXY × dxy_trend × 0.7
```

**تعدیل سطح:**
```
DXY > 105 → adj -= 0.005  (فشار نزولی)
DXY < 100 → adj += 0.004  (حمایت صعودی)
```

### 8.2 US10Y (نرخ بهره واقعی)

```
US10Y > 5.0% → adj -= 0.008  (فشار نزولی شدید)
US10Y > 4.5% → adj -= 0.004  (فشار نزولی متوسط)
US10Y < 3.5% → adj += 0.006  (حمایت صعودی)
US10Y < 3.0% → adj += 0.003  (حمایت ملایم)
```

### 8.3 VIX (ترس بازار)

```
VIX > 35 → adj += 0.015  (پناهگاه امن قوی)
VIX > 25 → adj += 0.007  (تقاضای safe haven)
VIX < 12 → adj -= 0.003  (ریسک‌پذیری بالا)
```

**مجموع تعدیل:**
```
macro_adj = clamp(Σ(adj), -0.03, +0.03)
```

---

## 9. Z-Score Mean Reversion

**محاسبه Z-Score:**
```
Z = (P_current - μ₂₀) / σ₂₀
```
جایی که μ₂₀ و σ₂₀ میانگین و انحراف معیار 20 روز اخیر

**تعدیل:**
```
Z > 2.0  → z_adj = -0.04 (فشار نزولی قوی)
Z < -2.0 → z_adj = +0.04 (فشار صعودی قوی)
otherwise → z_adj = clamp(-Z × 0.015, -0.04, +0.04)
```

**کاهش اثر در زمان:**
```
gold_d *= (1 + z_adj × exp(-0.2×d))
```

---

## 10. تحلیل احساسات اخبار

### 10.1 منابع

- FXStreet RSS
- Investing.com RSS
- MarketWatch RSS

### 10.2 الگوریتم امتیازدهی

**کلمات کلیدی صعودی طلا:**
```
gold rises, gold gains, gold surges, gold rally,
safe haven, inflation hedge, dollar weakens,
geopolitical, uncertainty, recession fears, ...
```

**کلمات کلیدی نزولی طلا:**
```
gold falls, gold drops, gold slides, risk on,
dollar strength, rate hike, bond yields rise, ...
```

**فرمول امتیاز:**
```
score_item = Σ(keyword_weight × occurrence)
overall_score = mean(score_item for all news)
```

**تأثیر بر مدل:**
```
sent_adj = clamp(score/5000, -0.02, +0.02) × multiplier
multiplier = HIGH:1.5 | MEDIUM:1.2 | LOW:1.0
```

---

## 11. فرمول طلای ایران

### 11.1 فرمول پایه

```
Gold18_t = (Gold_oz_t / 31.1035) × 0.75 × USD_IRR_t × MF_t
```
جایی که:
- 31.1035 = تبدیل اونس به گرم (troy ounce)
- 0.75 = نسبت طلای 18 عیار (18/24)
- MF_t = ضریب بازار ایران (Market Factor)

### 11.2 محاسبه Market Factor

```
MF_t = Gold18_real_t / (Gold_oz_t/31.1035 × 0.75 × USD_IRR_t)
```

**میانگین وزنی نمایی (30 روزه):**
```
MF_avg = Σ(MF_i × w_i) / Σ(w_i)
w_i = exp(-0.08 × (n-i))
```

**محدوده:**
```
MF ∈ [0.87, 1.13]
```

### 11.3 فرمول سکه بهار آزادی

```
Coin = Gold18 × 8.133 × (21.6/18) × premium
```
جایی که:
- 8.133 = وزن خالص طلای سکه (گرم)
- 21.6/18 = نسبت عیار سکه به طلا 18
- premium ∈ [1.02, 1.08]

---

## 12. پیش‌بینی دلار (USD/IRR)

### 12.1 ساختار ترکیبی

```
USD_pred = 0.35×VAR + 0.25×ARIMA + 0.20×Holt + 0.20×MC
```

### 12.2 VAR(3) - مدل برداری خودبازگشتی

**سیستم معادلات:**
```
ΔUSDₜ = c₁ + Σᵢ(φ₁ᵢ·ΔUSDₜ₋ᵢ + φ₂ᵢ·ΔGoldₜ₋ᵢ) + ε₁ₜ
ΔGoldₜ = c₂ + Σᵢ(ψ₁ᵢ·ΔUSDₜ₋ᵢ + ψ₂ᵢ·ΔGoldₜ₋ᵢ) + ε₂ₜ
```
برآورد با Ridge Regression: λ = 0.1

### 12.3 تعدیل Z-Score و Direction

```
USD_d *= (1 + z_reversion_usd × exp(-0.15×d))
USD_d *= (1 + usd_dir_bias × d/7)
```

---

## 13. بک‌تست و اعتبارسنجی

### 13.1 Walk-Forward Validation

**الگوریتم:**
```
for i in start:step:end:
    train = prices[max(1, i-window):i]
    actual = prices[i + horizon]
    pred = ensemble(train)
    error = |pred - actual| / actual
```
پارامترها:
- window = 60 روز
- step = 5 روز
- horizon ∈ {1, 3, 7}

### 13.2 معیارهای عملکرد

**MAPE:**
```
MAPE = mean(|pred_i - actual_i| / actual_i × 100)
```

**Direction Accuracy:**
```
DA = Σ(pred_dir_i == actual_dir_i) / n × 100
```
جایی که pred_dir و actual_dir ∈ {UP, DOWN}

---

## 14. تحلیل همبستگی ارزها

### 14.1 ضریب همبستگی پیرسون

```
ρ = Cov(X,Y) / (σ_X × σ_Y)
```

### 14.2 همبستگی اسپیرمن

```
ρ_s = 1 - 6Σdᵢ² / (n(n²-1))
```
جایی که dᵢ = رتبه X_i - رتبه Y_i

### 14.3 بتا

```
β = Cov(r_currency, r_gold) / Var(r_currency)
```

### 14.4 آزمون گرنجر

**H₀: ارز علیت گرنجری طلا را ندارد**
```
F = ((RSS_restricted - RSS_unrestricted) / lags) /
    (RSS_unrestricted / (T - 2×lags - 1))
```
اگر F > 3 → رابطه علی احتمالی

### 14.5 هم‌انباشتگی انگل-گرنجر

```
Step 1: y = α + β·x + ε
Step 2: ADF test on ε
τ = (ρ-1) / SE(ρ)
```

### 14.6 امتیاز تأثیر ترکیبی

```
impact = |ρ_pearson|×0.25 + |ρ_spearman|×0.15
       + min(|β|,5)/5×0.20 + R²×0.20
       + min(F,10)/10×0.10 + min(|τ|,5)/5×0.10
```

---

## 15. اطمینان پیش‌بینی (Confidence)

### 15.1 محاسبه چندعاملی

```
Conf = 0.40×base_conf + 0.25×agreement + 0.20×dir_conf + 0.15×regime_conf
     - event_penalty

base_conf    = weighted avg of model confidences
agreement    = 1 - clamp(std(predictions)/mean, 0, 0.60)
dir_conf     = |P(up) - 0.5| × 2
regime_conf  = f(ADX, score)
event_penalty = min(event_risk × 4, 0.08)
```

**محدوده:**
```
Conf ∈ [0.35, 0.82]
```

---

## 16. Breakout Detection

**تعریف شکست:**
```
pad = max(current × 0.0015, ATR × 0.35)

if current > max(last_20d) + pad:
    breakout = +0.020  (شکست صعودی)
elif current < min(last_20d) - pad:
    breakout = -0.020  (شکست نزولی)
else:
    breakout = 0
```

---

## 17. ساختار SQLite

### جدول actual_snapshots

```sql
CREATE TABLE actual_snapshots (
    trade_date   TEXT PRIMARY KEY,
    captured_at  TEXT,
    gold_oz      REAL,
    usd_irr      REAL,
    iran_gold    REAL,
    dxy          REAL,
    vix          REAL,
    us10y        REAL
)
```

### جدول forecast_runs

```sql
CREATE TABLE forecast_runs (
    run_id       TEXT,
    run_time     TEXT,
    target_date  TEXT,
    horizon_day  INTEGER,
    gold_point   REAL, gold_low REAL, gold_high REAL,
    usd_point    REAL, usd_low  REAL, usd_high  REAL,
    iran_point   REAL, iran_low REAL, iran_high REAL,
    confidence   REAL,
    trend        TEXT,
    PRIMARY KEY (run_id, target_date)
)
```

---

## 18. API Endpoints

| Endpoint | توضیح |
|----------|-------|
| GET / | داشبورد HTML |
| GET /api/data | داده کامل JSON |
| GET /api/refresh | به‌روزرسانی دستی |
| GET /api/backtest?days=N | بک‌تست N روزه |

---

## 19. پارامترهای کلیدی

| پارامتر | مقدار | توضیح |
|---------|-------|-------|
| GARCH ω | 0.00001 | پایه نوسان |
| GARCH α | 0.10 | واکنش به شوک |
| GARCH β | 0.85 | ماندگاری |
| MC simulations | 3000-5000 | تعداد مسیر |
| CI lower | 10th percentile | حد پایین |
| CI upper | 90th percentile | حد بالا |
| Ridge λ | 0.01-1.0 | تنظیم |
| ARIMA p | 5 | مرتبه AR |
| ARIMA d | 1 | تفاضل |
| Market Factor bounds | [0.87, 1.13] | ضریب بازار |
| Direction threshold | 0.56/0.44 | آستانه جهت |
| Z-score cap | [-2, +2] | محدوده |
| Macro adj cap | [-3%, +3%] | تعدیل کلان |
| Walk-forward window | 60 روز | پنجره |
| Walk-forward step | 5 روز | گام |

---

## 20. محدودیت‌ها و هشدارها

1. **روزهای پرنوسان سیاسی:** خطا تا 5-15% ممکن است
2. **ضریب بازار ایران:** ناپایدار است (حباب/هیجان)
3. **تعطیلات بازار ایران:** پنجشنبه/جمعه gap ایجاد می‌کند
4. **FRED downtime:** fallback به مقادیر پیش‌فرض
5. **داده TGJU:** حداکثر ~3 سال تاریخچه
6. **Direction 58%:** بهتر از تصادف اما کامل نیست
7. **Walk-Forward 0.86%:** در شرایط عادی، نه رویدادهای خبری

---

## 21. نسخه و فناوری

| مورد | مقدار |
|------|-------|
| نسخه | 5.0 |
| زبان | Julia 1.12.x |
| سرور | HTTP.jl |
| پایگاه داده | SQLite |
| UI | HTML/CSS/JavaScript |
| چارت | Chart.js 4.4.0 |
| فونت | Vazirmatn |

---

*این مستند توسط سازنده سیستم نوشته شده است.*
*آخرین به‌روزرسانی: $(Dates.format(now(), "yyyy-mm-dd"))*
"""

fname = "TECHNICAL_DOCUMENTATION.md"
open(fname, "w") do f
    write(f, doc)
end

println("═══════════════════════════════════════")
println("  مستند فنی ساخته شد: $(fname)")
println("═══════════════════════════════════════")
