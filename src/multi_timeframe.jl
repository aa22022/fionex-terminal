module MultiTimeframe

using Statistics, LinearAlgebra

export TimeframeAnalysis, MTFResult, analyze_multi_timeframe, compute_mtf_confluence

# ============================================================
# Data Types
# ============================================================

struct TimeframeAnalysis
    tf_name::String           # "LTF" / "MTF" / "HTF" / "XLTF"
    window::Int               # روزهای شبیه‌سازی شده
    tf_label::String          # "H4-like", "D1-like", ...

    # Price info
    ma_short::Float64         # میانگین کوتاه (نصف window)
    ma_long::Float64          # میانگین کامل window
    trend_direction::String   # up/down/sideways
    trend_strength::Float64   # 0-1

    # Momentum
    momentum::Float64         # % change over window
    rsi::Float64              # RSI برای این TF
    velocity::Float64         # نرخ تغییر مومنتوم

    # Volatility
    volatility::Float64       # نوسان در این TF
    atr::Float64              # ATR شبیه‌سازی شده

    # Structure
    higher_highs::Bool
    higher_lows::Bool
    lower_highs::Bool
    lower_lows::Bool

    # Signal
    signal::String            # strong_buy/buy/neutral/sell/strong_sell
    confidence::Float64
end

struct MTFResult
    symbol::String
    timeframes::Vector{TimeframeAnalysis}

    # Confluence
    all_bullish::Bool
    all_bearish::Bool
    aligned_count::Int
    total_count::Int
    confluence_score::Float64   # 0-1
    dominant_bias::String       # bullish/bearish/mixed

    # Best entry TF
    best_tf::String
    best_tf_reason::String
end

# ============================================================
# Helpers
# ============================================================

function safe_ret(prices::Vector{Float64}, lag::Int)
    n = length(prices)
    n <= lag && return 0.0
    p0 = prices[end-lag]
    p0 <= 0 && return 0.0
    r = (prices[end] - p0) / p0 * 100
    isfinite(r) ? clamp(r, -30.0, 30.0) : 0.0
end

function calc_rsi_window(prices::Vector{Float64}, window::Int)
    n = length(prices)
    w = min(window, n-1)
    w < 3 && return 50.0
    sl = prices[end-w:end]
    ch = diff(sl)
    ag = mean(max.(ch, 0.0))
    al = mean(max.(-ch, 0.0))
    al < 1e-15 && return 100.0
    return 100.0 - 100.0 / (1.0 + ag/al)
end

function calc_atr_window(prices::Vector{Float64}, window::Int)
    n = length(prices)
    w = min(window, n-1)
    w < 2 && return 0.001
    sl = prices[end-w:end]
    ranges = [abs(sl[i] - sl[i-1]) for i in 2:length(sl)]
    isempty(ranges) ? 0.001 : mean(ranges)
end

# ============================================================
# Single TF Analysis
# ============================================================

function analyze_single_tf(prices::Vector{Float64}, window::Int, tf_name::String, tf_label::String)
    n = length(prices)
    n < window+5 && return nothing

    sl = prices[end-window+1:end]
    cur = last(prices)

    # MA
    ma_short = mean(prices[end-div(window,2)+1:end])
    ma_long = mean(sl)

    # Trend
    trend_dir = if cur > ma_short > ma_long
        "up"
    elseif cur < ma_short < ma_long
        "down"
    else
        "sideways"
    end

    # Trend strength = normalized slope
    xs = collect(1.0:Float64(length(sl)))
    ys = sl
    x_mean = mean(xs); y_mean = mean(ys)
    ss_xy = sum((xs .- x_mean) .* (ys .- y_mean))
    ss_xx = sum((xs .- x_mean).^2)
    slope = ss_xx > 1e-15 ? ss_xy / ss_xx : 0.0
    trend_strength = min(1.0, abs(slope) / max(y_mean * 0.005, 1e-10))

    # Momentum
    mom = safe_ret(prices, window)

    # RSI
    rsi = calc_rsi_window(prices, window)

    # Velocity (شتاب مومنتوم)
    mom_half = safe_ret(prices, div(window,2))
    velocity = mom_half - (mom - mom_half)

    # Volatility
    vol = std(diff(log.(max.(sl, 1e-10)))) * sqrt(252) * 100

    # ATR
    atr = calc_atr_window(prices, window)

    # Structure (higher highs/lows)
    mid_idx = div(length(sl), 2)
    first_half = sl[1:mid_idx]
    second_half = sl[mid_idx+1:end]

    hh = maximum(second_half) > maximum(first_half)
    hl = minimum(second_half) > minimum(first_half)
    lh = maximum(second_half) < maximum(first_half)
    ll = minimum(second_half) < minimum(first_half)

    # Signal
    signal = if trend_dir == "up" && rsi > 55 && mom > 0.3 && hh && hl
        "strong_buy"
    elseif trend_dir == "up" && (rsi > 50 || mom > 0)
        "buy"
    elseif trend_dir == "down" && rsi < 45 && mom < -0.3 && lh && ll
        "strong_sell"
    elseif trend_dir == "down" && (rsi < 50 || mom < 0)
        "sell"
    else
        "neutral"
    end

    # Confidence
    conf = if signal in ["strong_buy", "strong_sell"]
        clamp(0.7 + trend_strength * 0.2, 0.5, 0.95)
    elseif signal in ["buy", "sell"]
        clamp(0.45 + trend_strength * 0.25, 0.35, 0.75)
    else
        0.3
    end

    return TimeframeAnalysis(
        tf_name, window, tf_label,
        round(ma_short, digits=5), round(ma_long, digits=5),
        trend_dir, round(trend_strength, digits=3),
        round(mom, digits=3), round(rsi, digits=1),
        round(velocity, digits=3), round(vol, digits=2),
        round(atr, digits=5),
        hh, hl, lh, ll,
        signal, round(conf, digits=3)
    )
end

# ============================================================
# Multi-TF Analysis
# ============================================================

function analyze_multi_timeframe(symbol::String, prices::Vector{Float64})
    tfs = TimeframeAnalysis[]

    # Define TFs with real-world equivalents
    tf_configs = [
        ("LTF",  5,  "H4-like"),
        ("MTF",  15, "D1-like"),
        ("HTF",  40, "W1-like"),
        ("XLTF", 100, "MN-like")
    ]

    for (name, window, label) in tf_configs
        result = analyze_single_tf(prices, window, name, label)
        result !== nothing && push!(tfs, result)
    end

    return tfs
end

# ============================================================
# Confluence Scoring
# ============================================================

function compute_mtf_confluence(symbol::String, tfs::Vector{TimeframeAnalysis})
    isempty(tfs) && return nothing

    bull_count = count(tf -> tf.signal in ["strong_buy", "buy"], tfs)
    bear_count = count(tf -> tf.signal in ["strong_sell", "sell"], tfs)
    total = length(tfs)

    all_bullish = bull_count == total
    all_bearish = bear_count == total

    aligned = max(bull_count, bear_count)

    # Weighted confluence: TFهای بزرگتر مهم‌تر
    weights = [1.0, 1.3, 1.8, 2.2]  # LTF, MTF, HTF, XLTF
    total_weight = 0.0
    bull_weight = 0.0
    bear_weight = 0.0

    for (i, tf) in enumerate(tfs)
        w = i <= length(weights) ? weights[i] : 1.0
        total_weight += w
        if tf.signal in ["strong_buy", "buy"]
            bull_weight += w * tf.confidence
        elseif tf.signal in ["strong_sell", "sell"]
            bear_weight += w * tf.confidence
        end
    end

    max_conf_weight = max(bull_weight, bear_weight)
    confluence_score = total_weight > 0 ? max_conf_weight / total_weight : 0.0

    dominant_bias = if bull_weight > bear_weight * 1.3
        "bullish"
    elseif bear_weight > bull_weight * 1.3
        "bearish"
    else
        "mixed"
    end

    # Best TF for entry (بالاترین confidence با اجماع)
    best_tf_name = "none"
    best_reason = "بدون اجماع"

    if all_bullish || all_bearish
        # اگر همه موافق‌اند، LTF بهترین برای ورود
        best_tf_name = tfs[1].tf_name
        best_reason = "همه تایم‌فریم‌ها هم‌جهت - ورود از $(tfs[1].tf_label)"
    elseif dominant_bias != "mixed"
        # پیدا کردن بهترین TF با اجماع
        matching_tfs = filter(tf ->
            (dominant_bias == "bullish" && tf.signal in ["strong_buy", "buy"]) ||
            (dominant_bias == "bearish" && tf.signal in ["strong_sell", "sell"]),
            tfs
        )
        if !isempty(matching_tfs)
            best = matching_tfs[argmax([t.confidence for t in matching_tfs])]
            best_tf_name = best.tf_name
            best_reason = "$(best.tf_label) با اجماع $(round(Int, confluence_score*100))%"
        end
    end

    return MTFResult(
        symbol, tfs,
        all_bullish, all_bearish,
        aligned, total,
        round(confluence_score, digits=3),
        dominant_bias,
        best_tf_name, best_reason
    )
end

end
