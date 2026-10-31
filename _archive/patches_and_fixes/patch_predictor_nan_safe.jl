content = read("src/predictor.jl", String)

helper = raw"""
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
"""

if !occursin("function safe_mean(", content)
    content = replace(
        content,
        "export predict_next_week, PredictionResult" =>
        "export predict_next_week, PredictionResult\n\n" * helper
    )
end

# امن‌سازی macro_adjustment
content = replace(content, "c = cor(gp, dp)" => "c = safe_cor(gp, dp)")
content = replace(content, "dxy_trend = mean(dp[max(1,end-6):end])" => "dxy_trend = safe_mean(dp[max(1,end-6):end])")
content = replace(content, "rate_trend = mean(rp[max(1,end-6):end])" => "rate_trend = safe_mean(rp[max(1,end-6):end])")
content = replace(content, "c = cor(gp, vp)" => "c = safe_cor(gp, vp)")
content = replace(content, "vix_trend = mean(vp[max(1,end-6):end])" => "vix_trend = safe_mean(vp[max(1,end-6):end])")

# اگر macro_adj خراب شد، صفرش کن
content = replace(
    content,
    "macro_adj, macro_signals = macro_adjustment(gold_prices, dxy_prices, us10y_prices, vix_prices)" =>
    "macro_adj, macro_signals = macro_adjustment(gold_prices, dxy_prices, us10y_prices, vix_prices)\n    if !isfinite(macro_adj)\n        macro_adj = 0.0\n    end"
)

# اگر all_p يا mc_lo/mc_hi خراب بود
content = replace(
    content,
    "af = [all_p[m,end] for m in 1:6]; push!(af, mc_lo); push!(af, mc_hi)" =>
    "af = [all_p[m,end] for m in 1:6 if isfinite(all_p[m,end])]\n    isfinite(mc_lo) && push!(af, mc_lo)\n    isfinite(mc_hi) && push!(af, mc_hi)\n    isempty(af) && (af = [last(gold_prices)])"
)

# امن‌سازی gold_daily
content = replace(
    content,
    "gold_point = last(gold_daily)" =>
    "for i in eachindex(gold_daily)\n        if !isfinite(gold_daily[i])\n            gold_daily[i] = i == 1 ? last(gold_prices) : gold_daily[i-1]\n        end\n    end\n\n    gold_point = last(gold_daily)"
)

# امن‌سازی usd arrays
content = replace(
    content,
    "usd_point = last(usd_pred_daily)" =>
    "for i in eachindex(usd_pred_daily)\n        if !isfinite(usd_pred_daily[i])\n            usd_pred_daily[i] = i == 1 ? last(usd_irr) : usd_pred_daily[i-1]\n        end\n        if !isfinite(usd_lo[i])\n            usd_lo[i] = usd_pred_daily[i] * 0.99\n        end\n        if !isfinite(usd_hi[i])\n            usd_hi[i] = usd_pred_daily[i] * 1.01\n        end\n    end\n\n    usd_point = last(usd_pred_daily)"
)

# امن‌سازی iran arrays
content = replace(
    content,
    "iran_point = last(iran_pred)" =>
    "for i in eachindex(iran_pred)\n        if !isfinite(iran_pred[i])\n            iran_pred[i] = i == 1 ? last(iran_gold) : iran_pred[i-1]\n        end\n    end\n\n    iran_point = last(iran_pred)"
)

write("src/predictor.jl", content)
println("predictor.jl NaN-safe patch applied successfully")
