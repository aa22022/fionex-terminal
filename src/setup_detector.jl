module SetupDetector

using Statistics, Dates
using ..MTFData
using ..AdvancedQuant

export detect_setup, SetupResult, MTFConfluenceReport

struct MTFConfluenceReport
    h1_bias::String
    h1_score::Float64
    h4_bias::String
    h4_score::Float64
    d1_bias::String
    d1_score::Float64
    confluence_aligned::Bool
end

struct SetupResult
    symbol::String
    bias::String
    setup_type::String
    entry_low::Float64
    entry_high::Float64
    target1::Float64
    target2::Float64
    stop_loss::Float64
    risk_reward::Float64
    trade_quality::String
    confidence::Float64
    trend_score::Float64
    momentum_score::Float64
    volatility_score::Float64
    reasons_for::Vector{String}
    reasons_against::Vector{String}
    timeframe::String
    quant::AdvancedQuant.AdvancedAnalysis
    mtf::MTFConfluenceReport
    trade_type::String
end

function analyze_single_timeframe(closes::Vector{Float64})::Tuple{String, Float64}
    n = length(closes)
    n < 2 && return ("NEUTRAL", 50.0)
    ma5 = mean(closes[max(1, n-4):end])
    ma15 = mean(closes[max(1, n-14):end])
    prev_idx = max(1, n-5)
    prev_p = max(closes[prev_idx], 1e-6)
    change = (closes[end] - prev_p) / prev_p * 100.0
    
    bias = "NEUTRAL"
    score = 50.0
    if closes[end] > ma5 && ma5 >= ma15
        bias = "BUY"
        score = 50.0 + clamp(change * 8.0, 2.0, 48.0)
    elseif closes[end] < ma5 && ma5 <= ma15
        bias = "SELL"
        score = 50.0 - clamp(abs(change) * 8.0, 2.0, 48.0)
    end
    return (bias, round(score, digits=1))
end

function detect_setup(symbol::String, mtf_candles::Dict{String, MTFCandles}, trade_type::String="SWING")::SetupResult
    tf1, tf2, tf3 = ("H1", "H4", "D1")
    
    if !haskey(mtf_candles, tf1) || isempty(mtf_candles[tf1].closes)
        empty_adv = AdvancedQuant.analyze_advanced_setup(MTFCandles(symbol, "D1", Float64[], Float64[], Float64[], Float64[], Float64[], DateTime[], "--", false))
        empty_mtf = MTFConfluenceReport("NEUTRAL", 50.0, "NEUTRAL", 50.0, "NEUTRAL", 50.0, false)
        return SetupResult(symbol, "NO_TRADE", "داده زمانی ناقص", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, "D", 0.0, 0.0, 0.0, 0.0, String[], String[], "M5/M15/M30", empty_adv, empty_mtf, trade_type)
    end

    c_tf1 = mtf_candles[tf1]
    c_tf2 = haskey(mtf_candles, tf2) && !isempty(mtf_candles[tf2].closes) ? mtf_candles[tf2] : c_tf1
    c_tf3 = haskey(mtf_candles, tf3) && !isempty(mtf_candles[tf3].closes) ? mtf_candles[tf3] : c_tf1

    tf1_bias, tf1_score = analyze_single_timeframe(c_tf1.closes)
    tf2_bias, tf2_score = analyze_single_timeframe(c_tf2.closes)
    tf3_bias, tf3_score = analyze_single_timeframe(c_tf3.closes)

    adv_analysis = AdvancedQuant.analyze_advanced_setup(c_tf2)

    weighted_score = trade_type == "DAYTRADE" ? 
        (tf1_score * 0.40) + (tf2_score * 0.40) + (tf3_score * 0.20) :
        (tf1_score * 0.20) + (tf2_score * 0.40) + (tf3_score * 0.40)
    
    bias = "NO_TRADE"
    setup_type = trade_type == "DAYTRADE" ? "دی‌تریدینگ رنج" : "تحلیل رنج تعادلی"
    confidence = weighted_score
    
    if weighted_score >= 52.0
        bias = "BUY"
        setup_type = trade_type == "DAYTRADE" ? "دی‌ترید صعودی شتاب بالا (Day Trade)" : "سویینگ صعودی چند تایم‌فریمی"
    elseif weighted_score <= 48.0
        bias = "SELL"
        setup_type = trade_type == "DAYTRADE" ? "دی‌ترید نزولی شتاب بالا (Day Trade)" : "سویینگ نزولی چند تایم‌فریمی"
        confidence = 100.0 - weighted_score
    end

    confluence_aligned = (tf1_bias == tf2_bias == tf3_bias) && tf1_bias != "NEUTRAL"
    mtf_report = MTFConfluenceReport(tf1_bias, tf1_score, tf2_bias, tf2_score, tf3_bias, tf3_score, confluence_aligned)

    last_price = c_tf1.closes[end]
    std_p = length(c_tf1.closes) >= 2 ? std(c_tf1.closes[max(1, end-10):end]) : last_price * 0.003
    atr = max(std_p, last_price * (trade_type == "DAYTRADE" ? 0.0015 : 0.004))

    sl_mult = trade_type == "DAYTRADE" ? 1.2 : 2.0
    tp1_mult = trade_type == "DAYTRADE" ? 1.6 : 2.5
    tp2_mult = trade_type == "DAYTRADE" ? 3.0 : 4.5

    if bias == "BUY"
        stop_loss = last_price - (atr * sl_mult)
        target1 = last_price + (atr * tp1_mult)
        target2 = last_price + (atr * tp2_mult)
    elseif bias == "SELL"
        stop_loss = last_price + (atr * sl_mult)
        target1 = last_price - (atr * tp1_mult)
        target2 = last_price - (atr * tp2_mult)
    else
        stop_loss = 0.0
        target1 = 0.0
        target2 = 0.0
    end

    trade_quality = "C"
    if confidence >= 80.0
        trade_quality = confluence_aligned ? "A+" : "A"
    elseif confidence >= 65.0
        trade_quality = "B"
    elseif confidence >= 50.0
        trade_quality = "C"
    else
        trade_quality = "D"
    end

    entry_low = last_price * (trade_type == "DAYTRADE" ? 0.9995 : 0.999)
    entry_high = last_price * (trade_type == "DAYTRADE" ? 1.0005 : 1.001)
    
    risk = abs(last_price - stop_loss)
    reward = abs(target1 - last_price)
    rr_ratio = risk > 0.0 ? round(reward / risk, digits=2) : 0.0

    reasons_for = copy(adv_analysis.key_insights)
    reasons_against = String[]

    if confluence_aligned
        push!(reasons_for, "🔥 تاییدیه همسویی همزمان هر ۳ تایم‌فریم")
    end
    if trade_type == "DAYTRADE"
        push!(reasons_for, "⚡ سیگنال نوسان‌گیری فعال روزانه")
    end

    return SetupResult(
        symbol, bias, setup_type,
        entry_low, entry_high,
        target1, target2, stop_loss, rr_ratio,
        trade_quality, round(confidence, digits=1),
        round(weighted_score, digits=1),
        tf2_score, atr,
        reasons_for, reasons_against,
        trade_type == "DAYTRADE" ? "کوتاه‌مدت (M5/M15/M30)" : "چند تایم‌فریمی (H1/H4/D1)",
        adv_analysis,
        mtf_report,
        trade_type
    )
end

end