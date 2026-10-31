module RelationshipEngine

using Statistics, LinearAlgebra, Dates

export compute_relationships, RelationshipMap, AssetRelation

struct AssetRelation
    asset_a::String
    asset_b::String
    pearson_20d::Float64
    pearson_60d::Float64
    spearman_20d::Float64
    lead_lag_days::Int
    lead_lag_corr::Float64
    beta_30d::Float64
    partial_corr::Float64
    regime_corr::Dict{String,Float64}
    direction::String
    strength::String
end

struct RelationshipMap
    relations::Vector{AssetRelation}
    dependency_scores::Dict{String,Float64}
    leading_assets::Vector{String}
    lagging_assets::Vector{String}
    computed_at::String
end

function safe_cor(x::Vector{Float64}, y::Vector{Float64})
    n = min(length(x), length(y))
    n < 5 && return 0.0
    
    xx = @view x[end-n+1:end]
    yy = @view y[end-n+1:end]
    
    sx = std(xx)
    sy = std(yy)
    (sx < 1e-10 || sy < 1e-10) && return 0.0
    
    c = cor(xx, yy)
    return isfinite(c) ? clamp(c, -1.0, 1.0) : 0.0
end

function log_returns(prices::Vector{Float64})
    n = length(prices)
    n < 2 && return Float64[]
    rets = Vector{Float64}(undef, n-1)
    for i in 2:n
        p_prev = max(prices[i-1], 1e-10)
        p_cur = max(prices[i], 1e-10)
        rets[i-1] = log(p_cur / p_prev)
    end
    return rets
end

function detect_lead_lag(a::Vector{Float64}, b::Vector{Float64}; max_lag::Int=10)
    na = length(a)
    nb = length(b)
    n = min(na, nb, 120)
    n < max_lag + 10 && return 0, 0.0

    ra = log_returns(collect(@view a[end-n+1:end]))
    rb = log_returns(collect(@view b[end-n+1:end]))

    best_lag = 0
    best_corr = 0.0

    for lag in -max_lag:max_lag
        if lag >= 0
            xa = @view ra[1:end-lag]
            xb = @view rb[1+lag:end]
        else
            xa = @view ra[1-lag:end]
            xb = @view rb[1:end+lag]
        end
        length(xa) < 5 && continue
        
        c = cor(xa, xb)
        if isfinite(c) && abs(c) > abs(best_corr)
            best_corr = c
            best_lag  = lag
        end
    end

    return best_lag, round(best_corr, digits=4)
end

function partial_correlation(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64})
    n = min(length(x), length(y), length(z))
    n < 10 && return 0.0

    x_ = @view x[end-n+1:end]
    y_ = @view y[end-n+1:end]
    z_ = @view z[end-n+1:end]

    rxy = safe_cor(collect(x_), collect(y_))
    rxz = safe_cor(collect(x_), collect(z_))
    ryz = safe_cor(collect(y_), collect(z_))

    denom = sqrt(max(1.0 - rxz^2, 1e-15) * max(1.0 - ryz^2, 1e-15))
    denom < 1e-10 && return 0.0
    pc = (rxy - rxz * ryz) / denom
    return isfinite(pc) ? clamp(pc, -1.0, 1.0) : 0.0
end

function compute_beta(target::Vector{Float64}, reference::Vector{Float64}; window::Int=30)
    n = min(length(target), length(reference), window)
    n < 10 && return 0.0
    
    rt = log_returns(collect(@view target[end-n+1:end]))
    rr = log_returns(collect(@view reference[end-n+1:end]))
    length(rt) < 5 && return 0.0
    
    vr = var(rr)
    vr < 1e-15 && return 0.0
    beta = cov(rt, rr) / vr
    return isfinite(beta) ? clamp(beta, -10.0, 10.0) : 0.0
end

function regime_corr(target::Vector{Float64}, reference::Vector{Float64})
    result = Dict{String,Float64}()
    n = min(length(target), length(reference))
    n < 40 && return result

    t = @view target[end-n+1:end]
    r = @view reference[end-n+1:end]

    vol_thresh = 0.15
    low_vol_idx  = Int[]
    high_vol_idx = Int[]

    for i in 10:n
        sub_t = collect(@view t[max(1, i-9):i])
        vol = std(log_returns(sub_t)) * sqrt(252.0)
        if vol < vol_thresh
            push!(low_vol_idx, i)
        else
            push!(high_vol_idx, i)
        end
    end

    if length(low_vol_idx) >= 5
        result["calm"] = safe_cor(collect(@view t[low_vol_idx]), collect(@view r[low_vol_idx]))
    end

    if length(high_vol_idx) >= 5
        result["volatile"] = safe_cor(collect(@view t[high_vol_idx]), collect(@view r[high_vol_idx]))
    end

    n2 = div(n, 2)
    result["recent"]   = safe_cor(collect(@view t[end-n2+1:end]), collect(@view r[end-n2+1:end]))
    result["older"]    = safe_cor(collect(@view t[1:n2]), collect(@view r[1:n2]))
    result["full"]     = safe_cor(collect(t), collect(r))

    return result
end

function classify_direction(corr::Float64)
    if corr > 0.4
        return "strong_positive"
    elseif corr > 0.15
        return "mild_positive"
    elseif corr < -0.4
        return "strong_negative"
    elseif corr < -0.15
        return "mild_negative"
    else
        return "neutral"
    end
end

function classify_strength(corr::Float64)
    a = abs(corr)
    if a > 0.7
        return "very_strong"
    elseif a > 0.5
        return "strong"
    elseif a > 0.3
        return "moderate"
    elseif a > 0.15
        return "weak"
    else
        return "negligible"
    end
end

function compute_relationships(
    target_name::String,
    target::Vector{Float64},
    others::Dict{String, Vector{Float64}};
    control_series::Union{Vector{Float64}, Nothing} = nothing
)
    relations = AssetRelation[]
    dep_scores = Dict{String,Float64}()

    for (name, series) in others
        length(series) < 20 && continue

        p20  = safe_cor(target, series)
        p60  = length(target) >= 60 ? safe_cor(collect(@view target[end-59:end]), collect(length(series) >= 60 ? (@view series[end-59:end]) : series)) : p20
        sp20 = safe_cor(sort(collect(@view target[end-min(20, length(target))+1:end])), sort(length(series) >= 20 ? collect(@view series[end-19:end]) : series))

        lag, lag_corr = detect_lead_lag(target, series; max_lag=7)
        beta = compute_beta(target, series)
        pc   = control_series !== nothing ? partial_correlation(target, series, control_series) : p20
        rc   = regime_corr(target, series)

        dep = abs(p20) * 0.30 + abs(p60) * 0.20 + abs(pc) * 0.20 + abs(lag_corr) * 0.15 + min(abs(beta), 5.0) / 5.0 * 0.15
        dep_scores[name] = round(clamp(dep, 0.0, 1.0), digits=4)

        push!(relations, AssetRelation(
            target_name, name,
            round(p20,  digits=4),
            round(p60,  digits=4),
            round(sp20, digits=4),
            lag, lag_corr,
            round(beta, digits=4),
            round(pc,   digits=4),
            rc,
            classify_direction(p20),
            classify_strength(p20)
        ))
    end

    sort!(relations, by = r -> abs(r.pearson_20d), rev=true)

    leading  = String[]
    lagging  = String[]
    for (name, series) in others
        lag, _ = detect_lead_lag(series, target; max_lag=5)
        lag > 0 && push!(leading, name)
        
        lag_rev, _ = detect_lead_lag(target, series; max_lag=5)
        lag_rev > 0 && push!(lagging, name)
    end

    return RelationshipMap(
        relations,
        dep_scores,
        leading,
        lagging,
        string(Dates.now())[1:19]
    )
end

end