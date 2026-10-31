module MathEngine

using Statistics, LinearAlgebra, StatsBase

export calculate_all_ratios, CorrelationResult, RatioAnalysis

struct CorrelationResult
    currency::String
    name_fa::String
    pearson::Float64
    spearman::Float64
    beta::Float64
    r_squared::Float64
    granger_f::Float64
    cointegration::Float64
    impact_score::Float64
    direction::String
end

struct RatioAnalysis
    correlations::Vector{CorrelationResult}
    gold_oz_stats::Dict{String,Float64}
    iran_gold_stats::Dict{String,Float64}
    dxy_estimate::Float64
    fear_greed::Float64
end

function safe_cor(x, y)
    n = min(length(x), length(y))
    if n < 5
        return 0.0
    end
    xx = x[end-n+1:end]
    yy = y[end-n+1:end]
    sx = std(xx)
    sy = std(yy)
    if sx < 1e-15 || sy < 1e-15
        return 0.0
    end
    return clamp(cor(xx, yy), -1.0, 1.0)
end

function calc_spearman(x::Vector{Float64}, y::Vector{Float64})
    n = min(length(x), length(y))
    if n < 5
        return 0.0
    end
    xx = x[end-n+1:end]
    yy = y[end-n+1:end]
    rx = ordinalrank(xx)
    ry = ordinalrank(yy)
    return safe_cor(Float64.(rx), Float64.(ry))
end

function calc_beta(x::Vector{Float64}, y::Vector{Float64})
    n = min(length(x), length(y))
    if n < 10
        return 0.0
    end
    xx = x[end-n+1:end]
    yy = y[end-n+1:end]
    rx = diff(log.(max.(xx, 1e-10)))
    ry = diff(log.(max.(yy, 1e-10)))
    v = var(rx)
    if v < 1e-15
        return 0.0
    end
    return cov(rx, ry) / v
end

function calc_r_squared(x::Vector{Float64}, y::Vector{Float64})
    n = min(length(x), length(y))
    if n < 5
        return 0.0
    end
    xx = x[end-n+1:end]
    yy = y[end-n+1:end]
    X = hcat(ones(n), xx)
    try
        coeffs = X \ yy
        y_pred = X * coeffs
        ss_res = sum((yy .- y_pred).^2)
        ss_tot = sum((yy .- mean(yy)).^2)
        if ss_tot < 1e-15
            return 0.0
        end
        return clamp(1.0 - ss_res / ss_tot, 0.0, 1.0)
    catch
        return 0.0
    end
end

function calc_granger(x::Vector{Float64}, y::Vector{Float64}, lags::Int=5)
    n = min(length(x), length(y))
    if n < 2 * lags + 5
        return 0.0
    end
    xx = x[end-n+1:end]
    yy = y[end-n+1:end]
    T = n - lags
    Y = yy[lags+1:end]
    X_r = zeros(T, lags)
    for i in 1:lags
        X_r[:, i] = yy[lags+1-i:end-i]
    end
    X_r = hcat(ones(T), X_r)
    X_x = zeros(T, lags)
    for i in 1:lags
        X_x[:, i] = xx[lags+1-i:end-i]
    end
    X_u = hcat(X_r, X_x)
    try
        c_r = X_r \ Y
        c_u = X_u \ Y
        rss_r = sum((Y .- X_r * c_r).^2)
        rss_u = sum((Y .- X_u * c_u).^2)
        denom = rss_u / max(1, T - 2 * lags - 1)
        if denom < 1e-15
            return 0.0
        end
        f = ((rss_r - rss_u) / lags) / denom
        return max(0.0, f)
    catch
        return 0.0
    end
end

function calc_cointegration(x::Vector{Float64}, y::Vector{Float64})
    n = min(length(x), length(y))
    if n < 15
        return 0.0
    end
    xx = x[end-n+1:end]
    yy = y[end-n+1:end]
    X = hcat(ones(n), xx)
    try
        coeffs = X \ yy
        resid = yy .- X * coeffs
        dy = diff(resid)
        y_lag = resid[1:end-1]
        Xd = hcat(ones(length(dy)), y_lag)
        c = Xd \ dy
        pred = Xd * c
        se = sqrt(sum((dy .- pred).^2) / max(1, length(dy) - 2))
        XtX_inv = inv(Xd' * Xd)
        se_c = se * sqrt(abs(XtX_inv[2, 2]))
        if se_c < 1e-15
            return 0.0
        end
        return c[2] / se_c
    catch
        return 0.0
    end
end

function calc_rsi(prices::Vector{Float64}, period::Int=14)
    if length(prices) < period + 1
        return 50.0
    end
    changes = diff(prices[end-period:end])
    gains = [max(0.0, c) for c in changes]
    losses = [max(0.0, -c) for c in changes]
    ag = mean(gains)
    al = mean(losses)
    if al < 1e-15
        return 100.0
    end
    rs = ag / al
    return round(100.0 - 100.0 / (1.0 + rs), digits=2)
end

function calc_fear_greed(prices::Vector{Float64})
    if length(prices) < 20
        return 50.0
    end
    returns = diff(log.(max.(prices, 1e-10)))
    vol20 = std(returns[max(1,end-19):end]) * sqrt(252) * 100
    ma = mean(prices[max(1, end-49):end])
    cur = last(prices)
    ratio = (cur - ma) / ma * 100
    mom = (cur - prices[max(1, end-13)]) / prices[max(1, end-13)] * 100
    fg = 50.0 + ratio * 5.0 + mom * 3.0 - (vol20 - 15.0) * 2.0
    return clamp(round(fg, digits=1), 0.0, 100.0)
end

function calculate_all_ratios(data::Dict)
    currencies = data["currencies"]
    gold_prices = data["gold_oz"]["prices"]
    iran_gold = data["iran_gold"]["prices"]
    usd_irr = data["usd_irr"]["prices"]

    results = CorrelationResult[]

    for c in currencies
        cp = c.prices
        if length(cp) < 10 || length(gold_prices) < 10
            continue
        end
        pe = safe_cor(cp, gold_prices)
        sp = calc_spearman(cp, gold_prices)
        bt = calc_beta(cp, gold_prices)
        r2 = calc_r_squared(cp, gold_prices)
        gf = calc_granger(cp, gold_prices)
        ci = calc_cointegration(cp, gold_prices)
        impact = abs(pe) * 0.25 + abs(sp) * 0.15 + min(abs(bt), 5) / 5 * 0.2 +
                 abs(r2) * 0.2 + min(gf, 10) / 10 * 0.1 + min(abs(ci), 5) / 5 * 0.1
        dir = pe > 0 ? "مستقیم" : "معکوس"
        push!(results, CorrelationResult(
            c.symbol, c.name_fa,
            round(pe, digits=4), round(sp, digits=4),
            round(bt, digits=4), round(r2, digits=4),
            round(gf, digits=4), round(ci, digits=4),
            round(impact, digits=4), dir
        ))
    end

    sort!(results, by=x -> x.impact_score, rev=true)

    gold_stats = Dict{String, Float64}(
        "current" => last(gold_prices),
        "mean_30d" => mean(gold_prices[max(1, end-29):end]),
        "std_30d" => std(gold_prices[max(1, end-29):end]),
        "min_30d" => minimum(gold_prices[max(1, end-29):end]),
        "max_30d" => maximum(gold_prices[max(1, end-29):end]),
        "volatility" => round(std(diff(log.(max.(gold_prices, 1e-10)))) * sqrt(252) * 100, digits=2),
        "rsi_14" => calc_rsi(gold_prices, 14),
        "ma_20" => mean(gold_prices[max(1, end-19):end]),
        "ma_50" => length(gold_prices) >= 50 ? mean(gold_prices[end-49:end]) : mean(gold_prices)
    )

    iran_stats = Dict{String, Float64}(
        "current" => last(iran_gold),
        "mean_30d" => mean(iran_gold[max(1, end-29):end]),
        "usd_irr" => last(usd_irr)
    )

    dxy = 103.5
    fg = calc_fear_greed(gold_prices)

    return RatioAnalysis(results, gold_stats, iran_stats, dxy, fg)
end

end
