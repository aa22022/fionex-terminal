module AdaptiveML

using Statistics, LinearAlgebra, DecisionTree, Random
using ..TradeJournal

export AdaptiveInsight, train_setup_classifier, predict_setup_quality,
       compute_feature_importance, get_adaptive_insights

struct AdaptiveInsight
    has_model::Bool
    training_samples::Int
    model_accuracy::Float64
    feature_importances::Dict{String, Float64}
    best_features::Vector{String}
    worst_features::Vector{String}
    recommended_filters::Vector{String}
    grade_adjustments::Dict{String, Float64}
    insights_fa::Vector{String}
end

function get_adaptive_insights()
    stats = TradeJournal.get_journal_stats()
    return AdaptiveInsight(
        false, get(stats, "total_signals", 0), 0.0,
        Dict{String,Float64}(), String[], String[], String[],
        Dict{String,Float64}(),
        ["سیستم در حال جمع‌آوری داده‌های ترید است."]
    )
end

function train_setup_classifier()
    return nothing, String[], "حداقل ۸ ترید بسته شده نیاز است."
end

function predict_setup_quality(model, setup, feature_names::Vector{String})
    return 0.5, "ML: Standby"
end

function compute_feature_importance(model, X, y, feature_names)
    return Dict{String, Float64}()
end

end