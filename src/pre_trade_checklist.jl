module PreTradeChecklist

using Statistics, Dates

export ChecklistResult, ChecklistItem, evaluate_pre_trade_checklist

struct ChecklistItem
    check_name::String
    check_name_fa::String
    passed::Bool
    detail::String
    importance::String  # "critical", "important", "nice_to_have"
end

struct ChecklistResult
    symbol::String
    bias::String
    total_checks::Int
    passed_checks::Int
    pass_rate::Float64
    approved::Bool
    approval_fa::String
    items::Vector{ChecklistItem}
end

function evaluate_pre_trade_checklist(
    setup,
    events::Vector,
    portfolio_risk,
    journal_stats::Dict
)
    items = ChecklistItem[]
    
    # 1. News Event Check (Critical)
    has_upcoming_news = length(events) > 0
    push!(items, ChecklistItem(
        "news_event",
        "بررسی رویدادهای اقتصادی پیش رو",
        !has_upcoming_news,
        has_upcoming_news ? "⚠ $(length(events)) رویداد مهم در تقویم اقتصادی وجود دارد" : "✅ هیچ رویداد مهمی در ۴۸ ساعت آینده نیست",
        "critical"
    ))
    
    # 2. Correlation Exposure (Critical)
    corr_ok = true
    corr_detail = "✅ ریسک همبستگی در محدوده مجاز"
    if portfolio_risk !== nothing
        if portfolio_risk.portfolio_health == "OVER_EXPOSED"
            corr_ok = false
            corr_detail = "⚠ پورتفولیو در وضعیت OVER_EXPOSED - ریسک تجمیعی بالا"
        end
    end
    push!(items, ChecklistItem(
        "correlation_exposure",
        "بررسی ریسک همبستگی پورتفولیو",
        corr_ok,
        corr_detail,
        "critical"
    ))
    
    # 3. Historical Win Rate (Important)
    sym_wr = get(journal_stats, "win_rate", 0.0)
    wr_ok = sym_wr >= 45.0 || journal_stats["resolved_count"] < 5
    wr_detail = journal_stats["resolved_count"] < 5 ?
        "ℹ داده تاریخی کافی نیست ($(journal_stats["resolved_count"]) ترید)" :
        (wr_ok ? "✅ وین‌ریت تاریخی: $(sym_wr)%" : "⚠ وین‌ریت پایین: $(sym_wr)%")
    push!(items, ChecklistItem(
        "win_rate_history",
        "بررسی وین‌ریت تاریخی سیستم",
        wr_ok,
        wr_detail,
        "important"
    ))
    
    # 4. Timing Score (Important)
    timing_ok = setup.timing !== nothing && setup.timing.timing_score >= 5.0
    timing_detail = setup.timing === nothing ? "ℹ اطلاعات تایمینگ در دسترس نیست" :
        (timing_ok ? "✅ امتیاز تایمینگ: $(setup.timing.timing_score)/10" : "⚠ تایمینگ ضعیف: $(setup.timing.timing_score)/10")
    push!(items, ChecklistItem(
        "timing_score",
        "بررسی امتیاز تایمینگ ورود",
        timing_ok,
        timing_detail,
        "important"
    ))
    
    # 5. Market Structure (Important)
    struct_ok = true
    struct_detail = "✅ ساختار بازار مطلوب"
    if setup.advanced !== nothing
        if setup.advanced.is_overextended
            struct_ok = false
            struct_detail = "⚠ قیمت در وضعیت اشباع و کشیدگی بیش‌ازحد"
        end
    end
    push!(items, ChecklistItem(
        "market_structure",
        "بررسی ساختار بازار (HH/HL/BOS)",
        struct_ok,
        struct_detail,
        "important"
    ))
    
    # 6. RSI Overextension (Important)
    rsi_ok = true
    rsi_detail = "✅ RSI در محدوده نرمال"
    if setup.advanced !== nothing && setup.advanced.is_overextended
        rsi_ok = false
        rsi_detail = "⚠ اشباع خرید/فروش شدید - ریسک ورود بالا"
    end
    push!(items, ChecklistItem(
        "rsi_check",
        "بررسی وضعیت RSI و اشباع",
        rsi_ok,
        rsi_detail,
        "important"
    ))
    
    # 7. MTF Confluence (Nice to have)
    mtf_ok = setup.mtf_confluence >= 0.35
    mtf_detail = mtf_ok ? "✅ همگرایی چندتایم‌فریمی: $(round(Int, setup.mtf_confluence*100))%" :
        "⚠ همگرایی ضعیف بین تایم‌فریم‌ها: $(round(Int, setup.mtf_confluence*100))%"
    push!(items, ChecklistItem(
        "mtf_confluence",
        "بررسی همگرایی چند تایم‌فریمی",
        mtf_ok,
        mtf_detail,
        "nice_to_have"
    ))
    
    # 8. Risk/Reward Ratio (Nice to have)
    rr_ok = setup.risk_reward >= 1.3
    rr_detail = rr_ok ? "✅ نسبت ریسک به ریوارد مطلوب: 1:$(setup.risk_reward)" :
        "⚠ نسبت ریسک به ریوارد ضعیف: 1:$(setup.risk_reward)"
    push!(items, ChecklistItem(
        "risk_reward",
        "بررسی نسبت ریسک به ریوارد",
        rr_ok,
        rr_detail,
        "nice_to_have"
    ))
    
    # Calculate approval
    total = length(items)
    passed = count(i -> i.passed, items)
    critical_items = filter(i -> i.importance == "critical", items)
    critical_passed = count(i -> i.passed, critical_items)
    
    pass_rate = total > 0 ? (passed / total) * 100 : 0.0
    
    approved = critical_passed == length(critical_items) && pass_rate >= 62.5
    
    approval_fa = if approved && pass_rate >= 87.5
        "🟢 مجوز ورود صادر شد (تأیید کامل)"
    elseif approved
        "🟡 مجوز ورود مشروط (با احتیاط)"
    else
        "🔴 ورود پیشنهاد نمی‌شود"
    end
    
    return ChecklistResult(
        setup.symbol, setup.bias,
        total, passed,
        round(pass_rate, digits=1),
        approved, approval_fa,
        items
    )
end

end
