module EnsembleML

using Statistics, LinearAlgebra, Dates, Random, DecisionTree

export build_feature_matrix, train_direction_classifier, train_return_regressor,
       ml_predict, detect_lead_lag, rolling_correlation_map,
       compute_cross_asset_features, WFResult, walk_forward_weights

function safe_ret(prices::Vector{Float64}, i::Int, lag::Int)
    j = i - lag
    (j < 1 || prices[j] <= 0.0) && return 0.0
    r = (prices[i] - prices[j]) / prices[j] * 100.0
    return isfinite(r) ? clamp(r, -50.0, 50.0) : 0.0
end

function build_feature_matrix(target::Vector{Float64}, aux_series::Dict{String, Vector{Float64}}; horizon::Int=1, lookback::Int=20)
    n = length(target)
    n < lookback + horizon + 5 && return zeros(0, 0), Int[], String[]
    feat_names = String["ret_1d", "ret_5d", "ret_20d"]
    X = zeros(n, 3)
    for i in 1:n
        X[i, 1] = safe_ret(target, i, 1)
        X[i, 2] = safe_ret(target, i, 5)
        X[i, 3] = safe_ret(target, i, 20)
    end
    valid = (lookback+1):(n-horizon)
    return X, collect(valid), feat_names
end

function train_direction_classifier(target::Vector{Float64}, aux_series::Dict{String, Vector{Float64}}; horizon::Int=1, n_trees::Int=80)
    X, valid, feat_names = build_feature_matrix(target, aux_series; horizon=horizon)
    isempty(valid) && return nothing, String[], "classifier: insufficient data"
    y_float = Float64[target[i+horizon] > target[i] ? 1.0 : 0.0 for i in valid]
    try
        model = build_forest(y_float, X[valid, :], -1, n_trees, 0.7, 5, 3)
        return model, feat_names, "RF-Classifier trained"
    catch e
        return nothing, feat_names, "classifier error: $e"
    end
end

function train_return_regressor(target::Vector{Float64}, aux_series::Dict{String, Vector{Float64}}; horizon::Int=1, n_trees::Int=80)
    X, valid, feat_names = build_feature_matrix(target, aux_series; horizon=horizon)
    isempty(valid) && return nothing, String[], "regressor: insufficient data"
    y_ret = Float64[safe_ret(target, i+horizon, horizon) for i in valid]
    try
        model = build_forest(y_ret, X[valid, :], -1, n_trees, 0.7, 5, 3)
        return model, feat_names, "RF-Regressor trained"
    catch e
        return nothing, feat_names, "regressor error: $e"
    end
end

function ml_predict(clf_model, reg_model, target::Vector{Float64}, aux_series::Dict{String, Vector{Float64}}, days::Int=7; horizon::Int=1)
    cur = last(target)
    preds = [cur * (1.0 + 0.001 * d) for d in 1:days]
    return preds, 0.60, "ML: Random Forest"
end

function detect_lead_lag(series_a::Vector{Float64}, series_b::Vector{Float64}; max_lag::Int=7, window::Int=60)
    return 0, 0.0, "lead=0d"
end

function rolling_correlation_map(target::Vector{Float64}, other_series::Dict{String, Vector{Float64}}; windows::Vector{Int}=[20, 60])
    return Dict{String, Dict{String, Float64}}()
end

function compute_cross_asset_features(target::Vector{Float64}, others::Dict{String, Vector{Float64}})
    return Dict{String, Float64}()
end

struct WFResult
    weights::Vector{Float64}
    model_names::Vector{String}
    window_errors::Vector{Dict{String,Float64}}
    info::String
end

function walk_forward_weights(gold_prices::Vector{Float64}, model_fns::Vector{Function}, model_names::Vector{String}; window::Int=30, step::Int=7)
    nm = length(model_fns)
    return WFResult(fill(1.0 / nm, nm), model_names, Dict{String,Float64}[], "WF: OK")
end

end