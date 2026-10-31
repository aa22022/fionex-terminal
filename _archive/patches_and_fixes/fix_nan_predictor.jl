content = read("src/predictor.jl", String)

macro_new = """
function safe_mean(v)
    vals = [x for x in v if isfinite(x)]
    return isempty(vals) ? 0.0 : mean(vals)
end

function safe_cor(x::Vector{Float64}, y::Vector{Float64})
    n = min(length(x), length(y))
    if n < 3
        return 0.0
    end
    xx = x[end-n+1:end]
    yy = y[end-n+1:end]
    sx = std(xx)
    sy = std(yy)
    if !isfinite(sx) || !isfinite(sy) || sx < 1e-12 || sy < 1e-12
        return 0.0
    end
    c = cor(xx, yy)
    return isfinite(c) ? c : 0.0
end

function macro_adjustment(gold_prices::Vector{Float64}, dxy_prices::Vector{Float64},
                          us10y_prices::Vector{Float64}, vix_prices::Vector{Float64})
    n = length(gold_prices)
    adj = 0.0
    signals = String[]

    # --- DXY vs طلا: همبستگی معکوس ---
    if length(dxy_prices) >= 10
        nd = min(n, length(dxy_prices))
        gp = log_returns(gold_prices[end-nd+1:end])
        dp = log_returns(dxy_prices[end-nd+1:end])
        if length(gp) == length(dp) && length(gp) > 5
            c = safe_cor(gp, dp)
            dxy_trend = safe_mean(dp[max(1,end-6):end])
            dxy_adj = -c * dxy_trend * 0.7
            adj += isfinite(dxy_adj) ? dxy_adj : 0.0

            dxy_cur = last(dxy_prices)
            if dxy_cur > 104
                push!(signals, "DXY=$(round(dxy_cur,digits=1)) بالا → فشار نزولی بر طلا (همبستگی=$(round(c,digits=2)))")
                adj -= 0.001
            elseif dxy_cur < 100
                push!(signals, "DXY=$(round(dxy_cur,digits=1)) پایین → حمایت از طلا (همبستگی=$(round(c,digits=2)))")
                adj += 0.001
            else
                push!(signals, "DXY=$(round(dxy_cur,digits=1)) خنثی (همبستگی=$(round(c,digits=2)))")
            end
        end
    end

    # --- US10Y vs طلا: همبستگی معکوس ---
    if length(us10y_prices) >= 10
        nd = min(n, length(us10y_prices))
        gp = log_returns(gold_prices[end-nd+1:end])
        rp = log_returns(us10y_prices[end-nd+1:end])
        if length(gp) == length(rp) && length(gp) > 5
            rate_trend = safe_mean(rp[max(1,end-6):end])
            rate_adj = -rate_trend * 0.5
            adj += isfinite(rate_adj) ? rate_adj : 0.0

            us10y_cur = last(us10y_prices)
            if us10y_cur > 5.0
                push!(signals, "US10Y=$(round(us10y_cur,digits=2))% بسیار بالا → فشار بر طلا")
                adj -= 0.0015
            elseif us10y_cur > 4.5
                push!(signals, "US10Y=$(round(us10y_cur,digits=2))% بالا → فشار ملایم بر طلا")
                adj -= 0.0005
            elseif us10y_cur < 3.5
                push!(signals, "US10Y=$(round(us10y_cur,digits=2))% پایین → حمایت از طلا")
                adj += 0.001
            else
                push!(signals, "US10Y=$(round(us10y_cur,digits=2))% خنثی")
            end
        end
    end

    # --- VIX vs طلا: همبستگی مستقیم ---
    if length(vix_prices) >= 10
        nd = min(n, length(vix_prices))
        gp = log_returns(gold_prices[end-nd+1:end])
        vp = log_returns(vix_prices[end-nd+1:end])
        if length(gp) == length(vp) && length(gp) > 5
            c = safe_cor(gp, vp)
            vix_trend = safe_mean(vp[max(1,end-6):end])
            vix_adj = c * vix_trend * 0.3
            adj += isfinite(vix_adj) ? vix_adj : 0.0

            vix_cur = last(vix_prices)
            if vix_cur > 30
                push!(signals, "VIX=$(round(vix_cur,digits=1)) بسیار بالا → طلا پناهگاه امن → صعودی")
                adj += 0.002
            elseif vix_cur > 20
                push!(signals, "VIX=$(round(vix_cur,digits=1)) بالا → تقاضا برای طلا")
                adj += 0.001
            elseif vix_cur < 15
                push!(signals, "VIX=$(round(vix_cur,digits=1)) پایین → ریسک‌پذیری بالا → فشار بر طلا")
                adj -= 0.0005
            else
                push!(signals, "VIX=$(round(vix_cur,digits=1)) معمولی")
            end
        end
    end

    adj = isfinite(adj) ? adj : 0.0
    return clamp(adj, -0.02, 0.02), signals
end
"""

content = replace(
    content,
    r"(?s)function macro_adjustment\(gold_prices::Vector\{Float64\}, dxy_prices::Vector\{Float64\},\s*us10y_prices::Vector\{Float64\}, vix_prices::Vector\{Float64\}\).*?^end"m => macro_new
)

content = replace(
    content,
    "gold_point = last(gold_daily)" =>
    """for i in eachindex(gold_daily)
        if !isfinite(gold_daily[i])
            gold_daily[i] = i == 1 ? last(gold_prices) : gold_daily[i-1]
        end
    end

    gold_point = last(gold_daily)"""
)

content = replace(
    content,
    "usd_point = last(usd_pred_daily)" =>
    """for i in eachindex(usd_pred_daily)
        if !isfinite(usd_pred_daily[i])
            usd_pred_daily[i] = i == 1 ? last(usd_irr) : usd_pred_daily[i-1]
        end
        if !isfinite(usd_lo[i])
            usd_lo[i] = usd_pred_daily[i] * 0.99
        end
        if !isfinite(usd_hi[i])
            usd_hi[i] = usd_pred_daily[i] * 1.01
        end
    end

    usd_point = last(usd_pred_daily)"""
)

content = replace(
    content,
    "iran_point = last(iran_pred)" =>
    """for i in eachindex(iran_pred)
        if !isfinite(iran_pred[i])
            iran_pred[i] = i == 1 ? last(iran_gold) : iran_pred[i-1]
        end
    end

    iran_point = last(iran_pred)"""
)

write("src/predictor.jl", content)
println("predictor.jl NaN-safe patch applied")
