module StrengthEngine

using Statistics, Dates

export compute_all_strengths, generate_daily_report, CurrencyStrength

struct CurrencyStrength
    currency::String
    name_fa::String
    score::Float64          # 0-100
    momentum_5d::Float64    # درصد تغییر ۵ روزه
    momentum_20d::Float64   # درصد تغییر ۲۰ روزه
    trend_bias::String      # صعودی/نزولی/خنثی
    rank::Int               # از ۱ (قوی‌ترین) تا N
    strength_level::String  # ⭐⭐⭐⭐⭐ / ⭐⭐⭐⭐ / ⭐⭐⭐ / ⭐⭐ / ⭐
end

const CURRENCY_FA_NAMES = Dict(
    "USD" => "دلار آمریکا",
    "EUR" => "یورو",
    "GBP" => "پوند انگلیس",
    "JPY" => "ین ژاپن",
    "CHF" => "فرانک سوئیس",
    "CAD" => "دلار کانادا",
    "AUD" => "دلار استرالیا",
    "NZD" => "دلار نیوزیلند",
    "CNY" => "یوان چین",
    "TRY" => "لیر ترکیه"
)

# محاسبه درصد تغییرات یک ارز نسبت به USD در بازه مشخص
function calc_change_pct(prices::Vector{Float64}, days::Int)::Float64
    n = length(prices)
    n < days + 1 && return 0.0
    p_now = prices[end]
    p_past = prices[end - days]
    p_past == 0.0 && return 0.0
    return ((p_now - p_past) / p_past) * 100.0
end

function compute_all_strengths(rates_dict::Dict{String, Vector{Float64}}, base_pairs_map::Any, ccys::Vector{String})::Vector{CurrencyStrength}
    strengths = CurrencyStrength[]
    
    for ccy in ccys
        # محاسبه میانگین قدرت این ارز در برابر تمام جفت‌های اصلی
        momentum_5_sum = 0.0
        momentum_20_sum = 0.0
        count_valid = 0
        
        # هر جفت‌ارز را چک می‌کنیم
        for (pair_sym, prices) in rates_dict
            if length(prices) < 21
                continue
            end
            
            # اگر ارز ما در پایه (Base) است => قدرت آن مستقیم است
            if startswith(pair_sym, ccy)
                m5 = calc_change_pct(prices, 5)
                m20 = calc_change_pct(prices, 20)
                # اگر ارز ما پایه است، افزایش قیمت جفت = قدرت ارز ما
                momentum_5_sum += m5
                momentum_20_sum += m20
                count_valid += 1
            # اگر ارز ما در کوت (Quote) است => قدرت آن معکوس است
            elseif endswith(pair_sym, ccy)
                m5 = calc_change_pct(prices, 5)
                m20 = calc_change_pct(prices, 20)
                # اگر ارز ما کوت است، افزایش قیمت جفت = ضعف ارز ما
                momentum_5_sum -= m5
                momentum_20_sum -= m20
                count_valid += 1
            end
        end
        
        if count_valid == 0
            push!(strengths, CurrencyStrength(ccy, get(CURRENCY_FA_NAMES, ccy, ccy), 50.0, 0.0, 0.0, "خنثی", 0, "⭐⭐"))
            continue
        end
        
        avg_m5 = momentum_5_sum / count_valid
        avg_m20 = momentum_20_sum / count_valid
        
        # نرمال‌سازی امتیاز قدرت به بازه 0-100
        # از تانژانت هایپربولیک برای مقیاس‌بندی نرم استفاده می‌کنیم
        raw_score = (avg_m5 * 2.0 + avg_m20) / 3.0
        score = 50.0 + (tanh(raw_score / 5.0) * 50.0)
        score = clamp(score, 0.0, 100.0)
        
        trend_bias = if score >= 65.0
            "قوی صعودی"
        elseif score >= 55.0
            "صعودی"
        elseif score >= 45.0
            "خنثی"
        elseif score >= 35.0
            "نزولی"
        else
            "قوی نزولی"
        end
        
        strength_level = if score >= 80.0
            "⭐⭐⭐⭐⭐"
        elseif score >= 65.0
            "⭐⭐⭐⭐"
        elseif score >= 50.0
            "⭐⭐⭐"
        elseif score >= 35.0
            "⭐⭐"
        else
            "⭐"
        end
        
        push!(strengths, CurrencyStrength(
            ccy,
            get(CURRENCY_FA_NAMES, ccy, ccy),
            round(score, digits=1),
            round(avg_m5, digits=2),
            round(avg_m20, digits=2),
            trend_bias,
            0,  # رتبه در ادامه پر می‌شود
            strength_level
        ))
    end
    
    # مرتب‌سازی بر اساس امتیاز قدرت
    sort!(strengths, by = x -> -x.score)
    
    # اختصاص رتبه به هر ارز
    ranked = CurrencyStrength[]
    for (i, s) in enumerate(strengths)
        push!(ranked, CurrencyStrength(
            s.currency, s.name_fa, s.score, s.momentum_5d, s.momentum_20d,
            s.trend_bias, i, s.strength_level
        ))
    end
    
    return ranked
end

function generate_daily_report(setups::Any, strengths::Any)::String
    a_plus_count = 0
    a_count = 0
    b_count = 0
    
    if setups isa AbstractVector
        for s in setups
            try
                q = string(s.trade_quality)
                if q == "A+"
                    a_plus_count += 1
                elseif q == "A"
                    a_count += 1
                elseif q == "B"
                    b_count += 1
                end
            catch
            end
        end
    end
    
    strongest = ""
    weakest = ""
    if strengths isa AbstractVector && length(strengths) > 0
        strongest = strengths[1].currency
        weakest = strengths[end].currency
    end
    
    return "گزارش روزانه: $a_plus_count ستاپ A+ | $a_count ستاپ A | $b_count ستاپ B | قوی‌ترین: $strongest | ضعیف‌ترین: $weakest"
end

end