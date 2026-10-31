module CandlePatterns

using Statistics

export CandleSignal, TimingAnalysis, detect_candle_patterns, evaluate_entry_timing

struct CandleSignal
    pattern_name::String     # "Bullish Pin Bar", "Bearish Engulfing", "Inside Bar", "None"
    pattern_fa::String       # نام فارسی الگو
    is_bullish::Bool
    is_bearish::Bool
    rejection_ratio::Float64 # درصد شدوی پس‌زده شده (Wick Ratio)
    pattern_quality::Float64 # 0.0 to 1.0
    pattern_desc::String
end

struct TimingAnalysis
    timing_score::Float64    # 0.0 to 10.0
    trigger_status::String   # "READY_TO_ENTER", "WAITING_FOR_TRIGGER", "PULLBACK_REQUIRED", "OVEREXTENDED"
    trigger_status_fa::String
    candle_signal::CandleSignal
    is_at_support_res::Bool
    reasons::Vector{String}
end

# محاسبه و تقریب OHLC از سری قیمت روزانه
function approximate_ohlc(prices::Vector{Float64})
    n = length(prices)
    n < 3 && return Tuple{Float64,Float64,Float64,Float64}[]

    ohlc = Tuple{Float64,Float64,Float64,Float64}[]
    for i in 2:n
        c = prices[i]
        o = prices[i-1]
        rng = abs(c - o) * 0.4 + c * 0.0015
        h = max(o, c) + rng * 0.6
        l = min(o, c) - rng * 0.6
        push!(ohlc, (o, h, l, c))
    end
    return ohlc
end

# 1. تشخیص الگوهای کندل استیک برگشتی و ادامه‌دهنده
function detect_candle_patterns(prices::Vector{Float64})
    n = length(prices)
    if n < 4
        return CandleSignal("None", "بدون الگوی کندلی", false, false, 0.0, 0.0, "داده ناکافی")
    end

    ohlc = approximate_ohlc(prices)
    length(ohlc) < 2 && return CandleSignal("None", "بدون الگوی کندلی", false, false, 0.0, 0.0, "داده ناکافی")

    o_prev, h_prev, l_prev, c_prev = ohlc[end-1]
    o_cur, h_cur, l_cur, c_cur = ohlc[end]

    total_range = h_cur - l_cur
    body = abs(c_cur - o_cur)
    upper_wick = h_cur - max(o_cur, c_cur)
    lower_wick = min(o_cur, c_cur) - l_cur

    total_range < 1e-10 && return CandleSignal("None", "بدون الگو", false, false, 0.0, 0.0, "رنج صفر")

    # پین‌بار صعودی (شدو پایینی بلند + بدنه کوچک در بالا)
    if lower_wick / total_range >= 0.55 && body / total_range <= 0.35
        ratio = lower_wick / total_range
        return CandleSignal("Bullish Pin Bar", "پین‌بار صعودی (پس‌زدگی کف با شدو بلند)", true, false, round(ratio, digits=2), 0.85, "ریجکشن قدرتمند قیمت از سطوح پایینی")
    end

    # پین‌بار نزولی (شدو بالایی بلند + بدنه کوچک در پایین)
    if upper_wick / total_range >= 0.55 && body / total_range <= 0.35
        ratio = upper_wick / total_range
        return CandleSignal("Bearish Pin Bar", "پین‌بار نزولی (پس‌زدگی سقف با شدو بلند)", false, true, round(ratio, digits=2), 0.85, "ریجکشن قدرتمند قیمت از سطوح بالایی")
    end

    # کندل پوشای صعودی (Bullish Engulfing)
    if c_cur > o_cur && c_prev < o_prev && c_cur >= o_prev && o_cur <= c_prev
        return CandleSignal("Bullish Engulfing", "کندل پوشای صعودی (Engulfing)", true, false, 0.0, 0.80, "غلبه کامل خریداران بر کندل نزولی قبلی")
    end

    # کندل پوشای نزولی (Bearish Engulfing)
    if c_cur < o_cur && c_prev > o_prev && c_cur <= o_prev && o_cur >= c_prev
        return CandleSignal("Bearish Engulfing", "کندل پوشای نزولی (Engulfing)", false, true, 0.0, 0.80, "غلبه کامل فروشندگان بر کندل صعودی قبلی")
    end

    # کندل داخلی (Inside Bar)
    if h_cur <= h_prev && l_cur >= l_prev
        return CandleSignal("Inside Bar", "کندل داخلی (تراکم انرژی Inside Bar)", false, false, 0.0, 0.65, "فشردگی قیمت درون رنج کندل قبل آماده شکست")
    end

    return CandleSignal("None", "الگوی استاندارد نرمال", false, false, 0.0, 0.3, "حرکت کندلی نرمال بدون الگوی ویژه")
end

# 2. ارزیابی امتیاز و تریگر تایمینگ ورود
function evaluate_entry_timing(
    prices::Vector{Float64},
    bias::String,
    entry_low::Float64,
    entry_high::Float64,
    dist_to_s::Float64,
    dist_to_r::Float64
)
    cur = last(prices)
    candle_sig = detect_candle_patterns(prices)
    reasons = String[]
    score = 5.0 # پایه ۵ از ۱۰

    # بررسی موقعیت مکانی نسبت به محدوده ورود
    in_entry_zone = (cur >= entry_low * 0.9995 && cur <= entry_high * 1.0005)
    
    if in_entry_zone
        score += 2.5
        push!(reasons, "قیمت دقیقاً درون باکس ورود بهینه قرار دارد")
    elseif bias == "long" && cur > entry_high
        score -= 2.0
        push!(reasons, "قیمت بالاتر از زون خرید است؛ منتظر پولبک باشید")
    elseif bias == "short" && cur < entry_low
        score -= 2.0
        push!(reasons, "قیمت پایین‌تر از زون فروش است؛ منتظر پولبک باشید")
    end

    # تاییدیه الگوهای کندلی
    if bias == "long"
        if candle_sig.is_bullish
            score += 2.5
            push!(reasons, "تاییدیه کندلی: " * candle_sig.pattern_fa)
        elseif candle_sig.is_bearish
            score -= 3.0
            push!(reasons, "هشدار کندلی خلاف جهت: " * candle_sig.pattern_fa)
        end
    elseif bias == "short"
        if candle_sig.is_bearish
            score += 2.5
            push!(reasons, "تاییدیه کندلی: " * candle_sig.pattern_fa)
        elseif candle_sig.is_bullish
            score -= 3.0
            push!(reasons, "هشدار کندلی خلاف جهت: " * candle_sig.pattern_fa)
        end
    end

    # نزدیکی به سطوح کلیدی
    is_at_sr = (bias == "long" && dist_to_s < 0.4) || (bias == "short" && dist_to_r < 0.4)
    if is_at_sr
        score += 1.5
        push!(reasons, "واکنش پرایس‌اکشنی سریع به سطح کلیدی")
    end

    final_score = clamp(round(score, digits=1), 1.0, 10.0)

    # وضعیت تریگر
    trigger_status = "WAITING_FOR_TRIGGER"
    status_fa = "در انتظار تاییدیه نهایی"

    if final_score >= 7.5 && in_entry_zone
        trigger_status = "READY_TO_ENTER"
        status_fa = "🟢 آماده ورود فوری (تایید تریگر)"
    elseif (bias == "long" && cur > entry_high * 1.005) || (bias == "short" && cur < entry_low * 0.995)
        trigger_status = "PULLBACK_REQUIRED"
        status_fa = "🟠 نیازمند بازگشت به زون (پولبک)"
    elseif final_score < 4.0
        trigger_status = "OVEREXTENDED"
        status_fa = "🔴 نامساعد جهت ورود (ریسک بالا)"
    else
        trigger_status = "WAITING_FOR_TRIGGER"
        status_fa = "🟡 در انتظار واکنش مطلوب کندلی"
    end

    return TimingAnalysis(
        final_score,
        trigger_status,
        status_fa,
        candle_sig,
        is_at_sr,
        reasons
    )
end

end
