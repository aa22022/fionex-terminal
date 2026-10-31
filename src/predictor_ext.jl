module PredictorExt

using Statistics, Dates

export predict_short_term, ShortTermPrediction

struct ShortTermPrediction
    current::Float64
    h1::Float64
    h4::Float64
    h24::Float64
    h1_pct::Float64
    h4_pct::Float64
    h24_pct::Float64
    confidence::Float64
    strength::String
    direction::String
end

# پیش‌بینی کوتاه‌مدت بر اساس مومنتوم اخیر
function predict_short_term(prices::Vector{Float64}; base_price::Float64=0.0)::ShortTermPrediction
    n = length(prices)

    # اگر base_price داده شد، از آن استفاده کن؛ در غیر این صورت از آخرین قیمت
    current = base_price > 0.0 ? base_price : (n > 0 ? prices[end] : 0.0)

    if n < 5 || current <= 0.0
        return ShortTermPrediction(current, current, current, current, 0.0, 0.0, 0.0, 30.0, "WEAK", "FLAT")
    end

    # مومنتوم روزانه اخیر (سه روز با وزن‌دهی)
    m1 = n >= 2 ? (prices[end] - prices[end-1]) / max(prices[end-1], 1e-9) : 0.0
    m2 = n >= 3 ? (prices[end-1] - prices[end-2]) / max(prices[end-2], 1e-9) : 0.0
    m3 = n >= 4 ? (prices[end-2] - prices[end-3]) / max(prices[end-3], 1e-9) : 0.0

    # میانگین موزون (روز اخیر وزن بالاتر)
    weighted_mom = 0.5 * m1 + 0.3 * m2 + 0.2 * m3

    # نوسانات اخیر برای confidence
    recent = prices[max(1, n-20):end]
    volatility = length(recent) >= 5 ? std(recent) / mean(recent) : 0.01

    # فاکتور تضعیف (mean reversion) — در افق کوتاه، احتمال بازگشت زیاد است
    h1_pct = weighted_mom * 0.15
    h4_pct = weighted_mom * 0.45
    h24_pct = weighted_mom * 1.00

    # محدودسازی نوسان غیرمنطقی به ±2%
    h1_pct = clamp(h1_pct, -0.02, 0.02)
    h4_pct = clamp(h4_pct, -0.03, 0.03)
    h24_pct = clamp(h24_pct, -0.05, 0.05)

    h1 = current * (1.0 + h1_pct)
    h4 = current * (1.0 + h4_pct)
    h24 = current * (1.0 + h24_pct)

    # قدرت سیگنال
    abs_mom = abs(weighted_mom)
    strength = abs_mom > 0.02 ? "STRONG" : (abs_mom > 0.005 ? "MODERATE" : "WEAK")

    # جهت
    direction = weighted_mom > 0.002 ? "UP" : (weighted_mom < -0.002 ? "DOWN" : "FLAT")

    # اطمینان پویا: هرچه نوسان کمتر و مومنتوم بیشتر، اطمینان بالاتر
    conf_base = 50.0 + abs_mom * 500.0  # حداکثر 50% اضافه
    conf_vol_penalty = min(volatility * 200.0, 25.0)  # کاهش به خاطر نوسان
    confidence = clamp(conf_base - conf_vol_penalty, 30.0, 95.0)

    return ShortTermPrediction(
        current,
        h1, h4, h24,
        h1_pct * 100.0,
        h4_pct * 100.0,
        h24_pct * 100.0,
        round(confidence, digits=1),
        strength,
        direction
    )
end

# محاسبه اطمینان پویا برای پیش‌بینی ۷ روزه
function compute_weekly_confidence(prices::Vector{Float64})::Float64
    n = length(prices)
    n < 20 && return 50.0

    recent = prices[max(1, n-30):end]
    volatility = std(recent) / mean(recent)

    # هرچه نوسان کمتر، اطمینان بالاتر (حداکثر ۹۰٪)
    conf = 90.0 - (volatility * 400.0)
    return clamp(round(conf, digits=1), 45.0, 90.0)
end


# ═══════════════════════════════════════════════════════
# Walk-Forward Backtest - بک‌تست واقعی با موتور اصلی
# برای هر روز از گذشته، فقط از داده‌های قبلی استفاده می‌کند
# ═══════════════════════════════════════════════════════
function walk_forward_backtest(prices::Vector{Float64}; min_history::Int=30)::Vector{Dict{String, Any}}
    results = Dict{String, Any}[]
    n = length(prices)
    n < min_history + 5 && return results

    for i in (min_history + 1):n
        # فقط داده تا قبل از روز i
        past = prices[1:i-1]
        actual = prices[i]

        # استفاده از همان فرمول predict_short_term
        pred = predict_short_term(past; base_price=past[end])

        push!(results, Dict(
            "predicted" => pred.h24,
            "actual" => actual,
            "error_pct" => actual > 0 ? abs((pred.h24 - actual) / actual) * 100.0 : 0.0
        ))
    end

    return results
end

# بک‌تست سبک‌تر (برای سرعت بالاتر - هر 3 روز یک پیش‌بینی)
function walk_forward_backtest_sampled(prices::Vector{Float64}; min_history::Int=30, step::Int=3)::Vector{Dict{String, Any}}
    results = Dict{String, Any}[]
    n = length(prices)
    n < min_history + 5 && return results

    for i in (min_history + 1):step:n
        past = prices[1:i-1]
        actual = prices[i]
        pred = predict_short_term(past; base_price=past[end])

        push!(results, Dict(
            "predicted" => pred.h24,
            "actual" => actual,
            "error_pct" => actual > 0 ? abs((pred.h24 - actual) / actual) * 100.0 : 0.0
        ))
    end

    return results
end

end