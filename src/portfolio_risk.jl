module PortfolioRisk

using Statistics, LinearAlgebra

export CurrencyExposure, CorrelationAlert, PortfolioAssessment, evaluate_portfolio_risk

struct CurrencyExposure
    currency::String
    net_lots::Float64          # مجموع خالص لات‌ها (+ خرید / - فروش)
    net_direction::String      # "LONG", "SHORT", "NEUTRAL"
    trade_count::Int           # تعداد معاملات باز روی این ارز
    risk_usd_allocated::Float64 # حجم ریسک دلاری درگیر روی این ارز
    exposure_level::String     # "HIGH_RISK" (>3 trades), "MODERATE", "BALANCED"
end

struct CorrelationAlert
    pair_a::String
    pair_b::String
    correlation_20d::Float64
    bias_a::String
    bias_b::String
    is_conflicted::Bool        # آیا دو پوزیشن ریسک یکدیگر را تشدید می‌کنند؟
    warning_fa::String
    action_fa::String
end

struct PortfolioAssessment
    account_balance::Float64
    total_risk_usd::Float64
    total_risk_pct::Float64
    max_allowed_risk_pct::Float64
    is_risk_capped::Bool
    scaling_factor::Float64    # ضریب تعدیل حجم (مثلا 0.7 اگر ریسک بیش از حد باشد)
    exposures::Vector{CurrencyExposure}
    correlation_alerts::Vector{CorrelationAlert}
    portfolio_health::String   # "OPTIMAL", "CAUTION", "OVER_EXPOSED"
    summary_fa::String
end

function safe_cor(x::Vector{Float64}, y::Vector{Float64})
    n = min(length(x), length(y))
    n < 5 && return 0.0
    xx = x[end-n+1:end]; yy = y[end-n+1:end]
    sx = std(xx); sy = std(yy)
    (sx < 1e-10 || sy < 1e-10) && return 0.0
    c = cor(xx, yy)
    isfinite(c) ? clamp(c, -1.0, 1.0) : 0.0
end

function evaluate_portfolio_risk(
    active_setups,
    rates_dict::Dict{String, Vector{Float64}};
    account_balance::Float64 = 1000.0,
    max_portfolio_risk_pct::Float64 = 5.0 # حداکثر مجاز ریسک پورتفولیو ۵٪
)
    # فیلتر ستاپ‌های معتبر ترید
    valid_setups = filter(s -> s.trade_quality in ["A+", "A", "B"] && s.bias in ["long", "short"] && s.risk_info !== nothing, active_setups)
    
    if isempty(valid_setups)
        return PortfolioAssessment(
            account_balance, 0.0, 0.0, max_portfolio_risk_pct,
            false, 1.0, CurrencyExposure[], CorrelationAlert[],
            "OPTIMAL", "هیچ معامله بازی در پورتفولیو وجود ندارد؛ ریسک در حداقل است."
        )
    end

    # 1. محاسبه اکسپوژر خالص هر ارز
    currency_lots = Dict{String, Float64}()
    currency_risks = Dict{String, Float64}()
    currency_counts = Dict{String, Int}()

    total_risk_usd = 0.0

    for s in valid_setups
        lots = s.risk_info.position_size_lots
        risk = s.risk_info.risk_usd
        total_risk_usd += risk
        
        base_ccy = s.base
        quote_ccy = s.quote_ccy
        
        # ارز پایه (Base)
        if !haskey(currency_lots, base_ccy); currency_lots[base_ccy] = 0.0; currency_risks[base_ccy] = 0.0; currency_counts[base_ccy] = 0; end
        # ارز متقابل (Quote)
        if !haskey(currency_lots, quote_ccy); currency_lots[quote_ccy] = 0.0; currency_risks[quote_ccy] = 0.0; currency_counts[quote_ccy] = 0; end

        if s.bias == "long"
            currency_lots[base_ccy] += lots
            currency_lots[quote_ccy] -= lots
        else # short
            currency_lots[base_ccy] -= lots
            currency_lots[quote_ccy] += lots
        end

        currency_risks[base_ccy] += risk * 0.5
        currency_risks[quote_ccy] += risk * 0.5
        currency_counts[base_ccy] += 1
        currency_counts[quote_ccy] += 1
    end

    exposures = CurrencyExposure[]
    for ccy in keys(currency_lots)
        nl = currency_lots[ccy]
        cnt = currency_counts[ccy]
        dir = nl > 0.001 ? "LONG" : (nl < -0.001 ? "SHORT" : "NEUTRAL")
        level = cnt >= 3 ? "HIGH_RISK" : (cnt == 2 ? "MODERATE" : "BALANCED")
        
        push!(exposures, CurrencyExposure(
            ccy, round(nl, digits=3), dir, cnt,
            round(currency_risks[ccy], digits=2), level
        ))
    end
    sort!(exposures, by=e -> -abs(e.net_lots))

    # 2. بررسی ریسک همبستگی بین پوزیشن‌ها
    correlation_alerts = CorrelationAlert[]
    n_setups = length(valid_setups)

    for i in 1:n_setups
        for j in (i+1):n_setups
            s1 = valid_setups[i]
            s2 = valid_setups[j]
            
            p1 = get(rates_dict, s1.symbol, Float64[])
            p2 = get(rates_dict, s2.symbol, Float64[])
            
            (length(p1) < 20 || length(p2) < 20) && continue
            
            c20 = safe_cor(p1, p2)
            
            # حالت خطر ۱: همبستگی مستقیم قوی (> 0.70) در همان جهت
            if c20 > 0.65 && s1.bias == s2.bias
                warn_text = "همبستگی مستقیم قوی ($(round(c20, digits=2))) بین $(s1.symbol) و $(s2.symbol)؛ هر دو در جهت $(s1.bias) هستند."
                act_text = "پیشنهاد: حجم هر دو معامله را ۵۰٪ کاهش دهید تا ریسک مضاعف بر حساب تحمیل نشود."
                push!(correlation_alerts, CorrelationAlert(s1.symbol, s2.symbol, round(c20, digits=2), s1.bias, s2.bias, true, warn_text, act_text))
            
            # حالت خطر ۲: همبستگی معکوس قوی (< -0.65) در جهت‌های مخالف
            elseif c20 < -0.65 && s1.bias != s2.bias
                warn_text = "همبستگی معکوس قوی ($(round(c20, digits=2))) بین $(s1.symbol) و $(s2.symbol)؛ جهت‌های مخالف عملاً ریسک یکسانی دارند."
                act_text = "پیشنهاد: یکی از دو موقعیت را لغو کرده یا ریسک را تعدیل کنید."
                push!(correlation_alerts, CorrelationAlert(s1.symbol, s2.symbol, round(c20, digits=2), s1.bias, s2.bias, true, warn_text, act_text))
            end
        end
    end

    # 3. سقف ریسک کل و محاسبه Scaling Factor
    total_risk_pct = (total_risk_usd / account_balance) * 100.0
    is_risk_capped = total_risk_pct > max_portfolio_risk_pct
    
    scaling_factor = is_risk_capped ? (max_portfolio_risk_pct / total_risk_pct) : 1.0
    
    # 4. وضعیت سلامت پورتفولیو
    has_high_exposure = any(e -> e.exposure_level == "HIGH_RISK", exposures)
    has_corr_conflict = !isempty(correlation_alerts)
    
    health = "OPTIMAL"
    summary = "وضعیت پورتفولیو کاملاً بهینه و متوازن است."
    
    if is_risk_capped || (has_high_exposure && has_corr_conflict)
        health = "OVER_EXPOSED"
        summary = "⚠️ هشدار ریسک تجمیعی: تمرکز بالای ریسک روی یک ارز خاص و همبستگی پوزیشن‌ها شناسایی شد."
    elseif has_high_exposure || has_corr_conflict || total_risk_pct > max_portfolio_risk_pct * 0.7
        health = "CAUTION"
        summary = "⚡ وضعیت نیازمند احتیاط: پوزیشن‌های هم‌راستا روی دلار/ارزها باز هستند."
    end

    return PortfolioAssessment(
        account_balance,
        round(total_risk_usd, digits=2),
        round(total_risk_pct, digits=2),
        max_portfolio_risk_pct,
        is_risk_capped,
        round(scaling_factor, digits=2),
        exposures,
        correlation_alerts,
        health,
        summary
    )
end

end
