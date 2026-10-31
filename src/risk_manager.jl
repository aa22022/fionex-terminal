module RiskManager

using Statistics

export PositionRisk, calculate_position_size, compute_kelly

struct PositionRisk
    symbol::String
    bias::String
    entry_price::Float64
    stop_loss::Float64
    take_profit::Float64
    risk_reward::Float64
    
    # Capital Management
    account_balance::Float64
    max_risk_pct::Float64
    kelly_fraction::Float64
    final_risk_pct::Float64
    
    # Lot Sizing
    position_size_units::Float64
    position_size_lots::Float64
    required_margin::Float64
    risk_usd::Float64
    reward_usd::Float64
end

function compute_kelly(win_rate::Float64, risk_reward::Float64; leverage_factor::Float64=0.25)
    b = max(risk_reward, 0.1)
    p = win_rate
    q = 1.0 - p
    f_star = (b * p - q) / b
    kelly_adj = f_star * leverage_factor
    return clamp(kelly_adj, 0.0, 0.05)
end

function calculate_position_size(
    symbol::String,
    bias::String,
    entry::Float64,
    sl::Float64,
    tp::Float64,
    rr::Float64,
    account_balance::Float64,
    historical_win_rate::Float64;
    max_risk_pct::Float64 = 2.0,
    leverage::Int = 100,
    is_crypto::Bool = false
)
    if entry <= 0 || sl <= 0 || entry == sl
        return PositionRisk(symbol, bias, entry, sl, tp, rr, account_balance, max_risk_pct, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    end

    kelly_frac = compute_kelly(historical_win_rate, rr; leverage_factor=0.25) * 100.0
    final_risk_pct = kelly_frac > 0 ? min(max_risk_pct, kelly_frac) : max_risk_pct * 0.5
    risk_usd = account_balance * (final_risk_pct / 100.0)
    stop_distance_pct = abs(entry - sl) / entry
    position_size_units = risk_usd / max(stop_distance_pct * entry, 1e-10)
    position_size_lots = is_crypto ? position_size_units : position_size_units / 100000.0
    notional_value = position_size_units * entry
    required_margin = notional_value / Float64(leverage)
    reward_usd = risk_usd * rr

    return PositionRisk(
        symbol, bias, entry, sl, tp, rr,
        account_balance, max_risk_pct,
        round(kelly_frac, digits=2),
        round(final_risk_pct, digits=2),
        round(position_size_units, digits=4),
        round(position_size_lots, digits=3),
        round(required_margin, digits=2),
        round(risk_usd, digits=2),
        round(reward_usd, digits=2)
    )
end

end
