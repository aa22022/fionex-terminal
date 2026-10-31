using Statistics, Dates

function calc_rsi_local(prices::Vector{Float64}, period::Int=14)
    n = length(prices)
    n <= period && return 50.0
    sum_gain = 0.0; sum_loss = 0.0
    for i in 2:(period+1)
        ch = prices[i] - prices[i-1]
        sum_gain += max(ch, 0.0)
        sum_loss += max(-ch, 0.0)
    end
    avg_gain = sum_gain / period
    avg_loss = sum_loss / period
    for i in (period+2):n
        ch = prices[i] - prices[i-1]
        avg_gain = (avg_gain * (period - 1) + max(ch, 0.0)) / period
        avg_loss = (avg_loss * (period - 1) + max(-ch, 0.0)) / period
    end
    return avg_loss < 1e-15 ? 100.0 : 100.0 - 100.0 / (1.0 + avg_gain / avg_loss)
end

function calc_macd_local(prices::Vector{Float64})
    n = length(prices)
    n < 26 && return 0.0, 0.0, 0.0
    alpha12 = 2.0 / 13.0; alpha26 = 2.0 / 27.0; alpha9 = 2.0 / 10.0
    ema12 = prices[1]; ema26 = prices[1]
    macd_line = Vector{Float64}(undef, n)
    for i in 1:n
        p = prices[i]
        ema12 = alpha12 * p + (1.0 - alpha12) * ema12
        ema26 = alpha26 * p + (1.0 - alpha26) * ema26
        macd_line[i] = ema12 - ema26
    end
    signal_line = macd_line[1]
    for i in 1:n
        signal_line = alpha9 * macd_line[i] + (1.0 - alpha9) * signal_line
    end
    return macd_line[end], signal_line, macd_line[end] - signal_line
end

# 1. Z-Score Mean Reversion
function zscore_signal(prices::Vector{Float64}, window::Int=20)
    n = length(prices)
    n < window + 5 && return 0.0, 0.0
    recent = @view prices[end-window+1:end]
    mu = mean(recent); sigma = std(recent)
    sigma < 1e-10 && return 0.0, 0.0
    z = (last(prices) - mu) / sigma
    return z, clamp(-z * 0.015, -0.04, 0.04)
end

# 2. Improved Macro Adjustment
function macro_regression_signal(gold_prices::Vector{Float64}, dxy::Float64, us10y::Float64, vix::Float64, dxy_hist::Vector{Float64}, us10y_hist::Vector{Float64}, vix_hist::Vector{Float64})
    signals = String[]; total_adj = 0.0
    n_dxy = length(dxy_hist)
    if n_dxy >= 5
        past_val = dxy_hist[end - min(4, n_dxy - 1)]
        dxy_chg = (dxy - past_val) / max(past_val, 1e-8)
        total_adj -= dxy_chg * 0.5
        if abs(dxy_chg) > 0.005
            dir = dxy_chg > 0 ? "↑ فشار نزولی" : "↓ حمایت صعودی"
            push!(signals, "DXY $(round(dxy, digits=1)) $dir ($(round(dxy_chg*100, digits=2))%)")
        end
    end
    if us10y > 5.0; total_adj -= 0.008; push!(signals, "US10Y $(us10y)% → فشار نزولی شدید")
    elseif us10y > 4.5; total_adj -= 0.004; push!(signals, "US10Y $(us10y)% → فشار نزولی متوسط")
    elseif us10y < 3.0; total_adj += 0.006; push!(signals, "US10Y $(us10y)% → حمایت صعودی")
    elseif us10y < 3.5; total_adj += 0.003; push!(signals, "US10Y $(us10y)% → حمایت ملایم") end

    if vix > 35.0; total_adj += 0.015; push!(signals, "VIX $(vix) → پناهگاه امن - صعود قوی")
    elseif vix > 25.0; total_adj += 0.007; push!(signals, "VIX $(vix) → تقاضای safe haven")
    elseif vix < 12.0; total_adj -= 0.003; push!(signals, "VIX $(vix) → ریسک‌پذیری بالا، فشار نزولی") end
    return clamp(total_adj, -0.03, 0.03), signals
end

# 3. Sentiment Adjustment
function sentiment_adjustment(sentiment_score::Float64, alert_level::String)
    base_adj = clamp(sentiment_score / 5000.0, -0.02, 0.02)
    mult = alert_level == "HIGH" ? 1.5 : (alert_level == "MEDIUM" ? 1.2 : 1.0)
    return base_adj * mult
end

# 4. Advanced Technical Analysis
function advanced_technical(prices::Vector{Float64}, days::Int=7)
    signals = String[]; score = 0.0; cur = last(prices); n = length(prices)
    if n > 14
        rsi = calc_rsi_local(prices, 14)
        if rsi > 80.0; score -= 20; push!(signals, "RSI=$(round(rsi, digits=1)) ← اشباع خرید شدید")
        elseif rsi > 70.0; score -= 12; push!(signals, "RSI=$(round(rsi, digits=1)) ← اشباع خرید")
        elseif rsi < 20.0; score += 20; push!(signals, "RSI=$(round(rsi, digits=1)) ← اشباع فروش شدید")
        elseif rsi < 30.0; score += 12; push!(signals, "RSI=$(round(rsi, digits=1)) ← اشباع فروش")
        elseif rsi > 55.0; score += 6; push!(signals, "RSI=$(round(rsi, digits=1)) ← صعودی")
        elseif rsi < 45.0; score -= 6; push!(signals, "RSI=$(round(rsi, digits=1)) ← نزولی") end
    end
    if n > 26
        _, _, hist = calc_macd_local(prices)
        score += hist > 0.0 ? 10.0 : -10.0
        push!(signals, hist > 0.0 ? "MACD=$(round(hist, digits=2)) ← صعودی" : "MACD=$(round(hist, digits=2)) ← نزولی")
    end
    if n >= 200
        ma50 = mean(@view prices[end-49:end]); ma100 = mean(@view prices[end-99:end]); ma200 = mean(@view prices[end-199:end])
        if cur > ma50 > ma100 > ma200; score += 25; push!(signals, "MA50>100>200 ← روند صعودی قوی")
        elseif cur > ma50 > ma200; score += 15; push!(signals, "قیمت بالای MA50,200 ← صعودی")
        elseif cur < ma50 < ma100 < ma200; score -= 25; push!(signals, "MA50<100<200 ← روند نزولی قوی") end
    elseif n >= 50
        ma10 = mean(@view prices[end-9:end]); ma20 = mean(@view prices[end-19:end]); ma50 = mean(@view prices[end-49:end])
        if ma10 > ma20 > ma50; score += 20; push!(signals, "MA10>20>50 ← ترتیب صعودی")
        elseif ma10 < ma20 < ma50; score -= 20; push!(signals, "MA10<20<50 ← ترتیب نزولی") end
    end
    trend_factor = clamp(score / 120.0, -0.07, 0.07)
    preds = [cur * (1.0 + trend_factor * Float64(d) / Float64(days)) for d in 1:days]
    conf = clamp(0.35 + abs(score) / 150.0, 0.35, 0.80)
    push!(signals, "─── امتیاز تکنیکال: $(round(score, digits=1))/120")
    return preds, conf, signals, score
end

# 5. Enhanced Regime Detection
function enhanced_regime_detect(prices::Vector{Float64}, dxy::Float64, vix::Float64, us10y::Float64, volume_proxy::Float64=1.0)
    n = length(prices)
    n < 30 && return "RANGING", "داده کافی نیست", 0.5
    recent_len = min(20, n-1)
    rets = [log(max(prices[n-recent_len+i], 1e-10) / max(prices[n-recent_len+i-1], 1e-10)) for i in 1:recent_len]
    vol_ann = std(rets) * sqrt(252.0) * 100.0
    mom5  = (last(prices) - prices[end-4]) / max(prices[end-4], 1e-10) * 100.0
    mom10 = n >= 10 ? (last(prices) - prices[end-9]) / max(prices[end-9], 1e-10) * 100.0 : mom5
    mom20 = n >= 20 ? (last(prices) - prices[end-19]) / max(prices[end-19], 1e-10) * 100.0 : mom10
    ma20 = mean(@view prices[end-min(19, n-1):end]); ma50 = n >= 50 ? mean(@view prices[end-49:end]) : mean(prices)
    score = mom20 * 0.35 + mom10 * 0.25 + mom5 * 0.15 + (ma20 > ma50 ? 15.0 : -15.0) * 0.15
    regime = vol_ann > 30.0 || vix > 35.0 ? "VOLATILE" : (score > 6.0 ? "TRENDING_UP" : (score < -6.0 ? "TRENDING_DOWN" : "RANGING"))
    return regime, "$regime | Vol=$(round(vol_ann, digits=1))% | Mom20=$(round(mom20, digits=2))%", 0.65
end

# 6. Adaptive Weights
function adaptive_weights(mapes::Vector{Float64}, confs::Vector{Float64}, regime::String, sentiment_score::Float64)
    n = length(mapes)
    base = [1.0 / (m + 0.005) for m in mapes]
    regime_boosts = if regime == "TRENDING_UP"
        [1.1, 1.0, 1.2, 0.9, 1.3, 1.0]
    elseif regime == "TRENDING_DOWN"
        [1.1, 0.9, 1.0, 1.0, 1.3, 0.9]
    elseif regime == "VOLATILE"
        [0.7, 0.7, 0.8, 1.8, 0.9, 0.8]
    elseif regime == "RANGING"
        [1.0, 1.3, 1.0, 1.2, 1.0, 1.0]
    else
        ones(n)
    end
    adj = base .* regime_boosts[1:min(n, length(regime_boosts))]
    total = sum(adj)
    return total > 0.0 ? adj ./ total : fill(1.0 / n, n)
end

# 7. Predict USD/IRR
function predict_usd_irr_v2(usd_prices::Vector{Float64}, gold_prices::Vector{Float64}, dxy::Float64, days::Int=7)
    cur_usd = last(usd_prices)
    _, z_adj = zscore_signal(usd_prices, 20)
    combined = [cur_usd * (1.0 + 0.001 * d) * (1.0 + z_adj * exp(-0.15 * d)) for d in 1:days]
    return combined, combined .* 0.98, combined .* 1.02, 0.65
end

# 8. Kelly Signal
function kelly_signal(win_rate::Float64, avg_win::Float64, avg_loss::Float64)
    if avg_loss < 1e-10 || win_rate <= 0.0 || win_rate >= 1.0
        return 0.0
    end
    b = avg_win / avg_loss
    f = (b * win_rate - (1.0 - win_rate)) / b
    return clamp(f, -0.5, 0.5)
end

# 9. Walk-Forward Validation
function walk_forward_validate(prices::Vector{Float64}; window::Int=60, step::Int=5, horizon::Int=1, min_train::Int=30)
    n = length(prices)
    if n < min_train + window + horizon
        return Dict("mape" => nothing, "direction" => nothing, "count" => 0)
    end
    errors = Float64[]
    dir_hits = Float64[]
    for i in (min_train + 1):step:(n - horizon)
        train = @view prices[max(1, i-window):i]
        actual = prices[i + horizon]
        pred = last(train) + mean(diff(train)) * Float64(horizon)
        if isfinite(pred) && actual > 0.0
            push!(errors, abs(pred - actual) / actual * 100.0)
            prev = prices[i]
            push!(dir_hits, (pred > prev) == (actual > prev) ? 1.0 : 0.0)
        end
    end
    return Dict(
        "mape" => isempty(errors) ? nothing : round(mean(errors), digits=3),
        "direction" => isempty(dir_hits) ? nothing : round(mean(dir_hits) * 100.0, digits=1),
        "count" => length(errors),
        "best_error" => isempty(errors) ? nothing : round(minimum(errors), digits=3),
        "worst_error" => isempty(errors) ? nothing : round(maximum(errors), digits=3),
        "median_error" => isempty(errors) ? nothing : round(median(errors), digits=3)
    )
end

# 10. Walk-Forward Multi Horizons
function walk_forward_multi(gold::Vector{Float64}, usd::Vector{Float64}, iran::Vector{Float64}; window::Int=60, step::Int=5)
    return Dict(
        "gold_h1" => walk_forward_validate(gold; window=window, step=step, horizon=1),
        "gold_h3" => walk_forward_validate(gold; window=window, step=step, horizon=3),
        "gold_h7" => walk_forward_validate(gold; window=window, step=step, horizon=7),
        "usd_h1"  => walk_forward_validate(usd;  window=window, step=step, horizon=1),
        "usd_h3"  => walk_forward_validate(usd;  window=window, step=step, horizon=3),
        "iran_h1" => walk_forward_validate(iran; window=window, step=step, horizon=1),
        "iran_h3" => walk_forward_validate(iran; window=window, step=step, horizon=3)
    )
end

# 11. Auto-Tuning Weights via Walk-Forward (حیاتی برای Predictor.jl)
function auto_tune_weights(prices::Vector{Float64}, predict_fns::Vector, fn_names::Vector{String}; window::Int=60, val_days::Int=20, min_train::Int=30)
    n = length(prices)
    nf = length(predict_fns)
    if n < min_train + val_days + 10
        return fill(1.0 / nf, nf), Dict{String,Float64}()
    end

    mapes = zeros(nf)
    counts = zeros(Int, nf)

    for offset in val_days:-1:1
        train_end = n - offset
        train_end < min_train && continue
        train = prices[1:train_end]
        actual = prices[train_end + 1]
        actual <= 0.0 && continue

        for m in 1:nf
            try
                pred_res = predict_fns[m](train, 1)
                pred_val = if isa(pred_res, Tuple)
                    p = pred_res[1]
                    isa(p, Vector) ? (isempty(p) ? NaN : p[1]) : Float64(p)
                elseif isa(pred_res, Vector)
                    isempty(pred_res) ? NaN : pred_res[1]
                else
                    Float64(pred_res)
                end

                if isfinite(pred_val)
                    err = abs(pred_val - actual) / actual
                    if isfinite(err)
                        mapes[m] += err
                        counts[m] += 1
                    end
                end
            catch
            end
        end
    end

    avg_mapes = Float64[]
    mape_dict = Dict{String,Float64}()
    for m in 1:nf
        avg = counts[m] > 0 ? mapes[m] / counts[m] : 1.0
        push!(avg_mapes, avg)
        mape_dict[fn_names[m]] = round(avg * 100.0, digits=3)
    end

    inv_w = [1.0 / (m + 0.005) for m in avg_mapes]
    total = sum(inv_w)
    weights = total > 0.0 ? inv_w ./ total : fill(1.0 / nf, nf)

    return weights, mape_dict
end