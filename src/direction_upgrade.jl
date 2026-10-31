using Statistics, Dates

function _safe_pct_change(cur::Float64, prev::Float64)
    return abs(prev) < 1e-12 ? 0.0 : (cur / prev - 1.0) * 100.0
end

function breakout_signal(prices::Vector{Float64}; lookback::Int=20)
    n = length(prices)
    n < lookback + 2 && return 0.0, "Breakout=N/A"
    prev = @view prices[end-lookback:end-1]
    cur = last(prices); hi = maximum(prev); lo = minimum(prev)
    if cur > hi * 1.002
        return 0.020, "Breakout ↑ بالای $(round(hi, digits=1))"
    elseif cur < lo * 0.998
        return -0.020, "Breakout ↓ زیر $(round(lo, digits=1))"
    else
        return 0.0, "Range20d"
    end
end

function direction_probability_gold(prices::Vector{Float64}, dxy::Float64, vix::Float64, us10y::Float64, sentiment_score::Float64=0.0)
    n = length(prices)
    n < 30 && return 0.5, "NEUTRAL", 0.0, ["Direction model: data low"]
    cur = last(prices); signals = String[]; score = 0.0
    r5 = _safe_pct_change(cur, prices[end-5]); score += clamp(r5 * 1.2, -6.0, 6.0)
    ma10 = mean(@view prices[end-9:end]); ma20 = mean(@view prices[end-19:end])
    score += ma10 > ma20 ? 5.0 : -5.0
    br_adj, br_msg = breakout_signal(prices; lookback=20)
    score += br_adj * 350.0; push!(signals, br_msg)
    prob_up = 1.0 / (1.0 + exp(-score / 9.0))
    label = prob_up > 0.56 ? "UP" : (prob_up < 0.44 ? "DOWN" : "NEUTRAL")
    label_fa = label == "UP" ? "تمایل صعودی" : (label == "DOWN" ? "تمایل نزولی" : "خنثی")
    pushfirst!(signals, "Bias: $label_fa | P↑=$(round(prob_up*100, digits=1))%")
    return prob_up, label, abs(prob_up - 0.5) * 2.0, signals
end

function direction_probability_usd(usd_prices::Vector{Float64}, gold_prices::Vector{Float64}, dxy::Float64, vix::Float64, sentiment_usd::Float64=0.0)
    n = length(usd_prices)
    n < 20 && return 0.5, "NEUTRAL", 0.0, ["USD Direction: data low"]
    cur = last(usd_prices); signals = String[]; score = 0.0
    r5 = _safe_pct_change(cur, usd_prices[end-5]); score += clamp(r5 * 1.0, -5.0, 5.0)
    prob_up = 1.0 / (1.0 + exp(-score / 8.0))
    label = prob_up > 0.56 ? "UP" : (prob_up < 0.44 ? "DOWN" : "NEUTRAL")
    label_fa = label == "UP" ? "دلار صعودی" : (label == "DOWN" ? "دلار نزولی" : "دلار خنثی")
    pushfirst!(signals, "USD Bias: $label_fa | P↑=$(round(prob_up*100, digits=1))%")
    return prob_up, label, abs(prob_up - 0.5) * 2.0, signals
end

function model_agreement_boost(model_preds::Vector{Vector{Float64}}, last_price::Float64, dir_prob::Float64)
    return ones(Float64, length(model_preds))
end

function widen_band(point::Float64, low::Float64, high::Float64, event_risk::Float64)
    event_risk <= 0.0 && return low, high
    width = max(point - low, high - point)
    extra = max(width * 0.35, point * event_risk * 0.8)
    return low - extra, high + extra
end

function ensemble_confidence(final_preds::Vector{Float64}, base_confs::Vector{Float64}, dir_prob::Float64, regime_conf::Float64, event_risk::Float64)
    base = isempty(base_confs) ? 0.45 : clamp(mean(base_confs), 0.20, 0.90)
    return clamp(0.5 * base + 0.3 * (abs(dir_prob - 0.5) * 2.0) + 0.2 * regime_conf - min(event_risk * 4.0, 0.08), 0.35, 0.82)
end