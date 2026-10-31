println("Generating Excel Report...")

include("src/data_fetcher.jl")
include("src/macro_data.jl")
include("src/math_engine.jl")
include("src/predictor.jl")
include("src/backtest_engine.jl")
include("src/news_sentiment.jl")
include("src/storage.jl")

using .DataFetcher, .MacroData, .MathEngine, .Predictor, .BacktestEngine, .NewsSentiment, .Storage
using Dates, Statistics

println("  Fetching data...")
data = fetch_all_data(1100)
macrodata = fetch_macro_data(180)
data["macro"] = macrodata
data["events"] = fetch_upcoming_events(14)
data["sentiment"] = try fetch_news_sentiment(24) catch; nothing end

println("  Analysis & Prediction...")
analysis = calculate_all_ratios(data)
prediction = predict_next_week(data, analysis)

println("  Backtest 240 days...")
bt = run_historical_backtest(
    data["gold_oz"]["prices"], data["gold_oz"]["dates"],
    data["usd_irr"]["prices"], data["usd_irr"]["dates"],
    data["iran_gold"]["prices"], data["iran_gold"]["dates"];
    test_days=240, min_train=30
)

println("  Walk-forward...")
wf = Predictor.walk_forward_multi(
    data["gold_oz"]["prices"],
    data["usd_irr"]["prices"],
    data["iran_gold"]["prices"];
    window=60, step=5
)

# ─── Sheet 1: Summary ───
fname = "report_$(Dates.format(now(),"yyyymmdd_HHMM")).csv"

open(fname, "w") do f
    # Header
    println(f, "═══ گزارش تحلیلی سامانه پیش‌بینی طلا و ارز ═══")
    println(f, "تاریخ,$(Dates.format(now(),"yyyy-mm-dd HH:MM"))")
    println(f, "")

    # Current Prices
    println(f, "═══ وضعیت فعلی بازار ═══")
    println(f, "شاخص,مقدار")
    println(f, "انس جهانی (USD),$(round(last(data["gold_oz"]["prices"]),digits=2))")
    println(f, "دلار آزاد (تومان),$(round(last(data["usd_irr"]["prices"]),digits=0))")
    println(f, "طلای 18 عیار (تومان),$(round(last(data["iran_gold"]["prices"]),digits=0))")
    try println(f, "DXY,$(round(macrodata["dxy"]["current"],digits=2))") catch end
    try println(f, "US10Y,$(round(macrodata["us10y"]["current"],digits=2))%") catch end
    try println(f, "VIX,$(round(macrodata["vix"]["current"],digits=2))") catch end
    println(f, "RSI,$(analysis.gold_oz_stats["rsi_14"])")
    println(f, "نوسان,$(analysis.gold_oz_stats["volatility"])%")
    println(f, "")

    # Prediction
    println(f, "═══ پیش‌بینی 7 روز آینده ═══")
    println(f, "تاریخ,انس (USD),دلار (تومان),طلا18 (تومان)")
    for (i,d) in enumerate(prediction.target_dates)
        println(f, "$(d),$(round(prediction.gold_oz_daily[i],digits=2)),$(round(prediction.usd_irr_daily[i],digits=0)),$(round(prediction.iran_gold_daily[i],digits=0))")
    end
    println(f, "")
    println(f, "هدف نهایی,$(round(prediction.gold_oz_point,digits=2)),$(round(prediction.usd_irr_point,digits=0)),$(round(prediction.iran_gold_point,digits=0))")
    println(f, "حد پایین,$(round(prediction.gold_oz_low,digits=2)),$(round(prediction.usd_irr_low,digits=0)),$(round(prediction.iran_gold_low,digits=0))")
    println(f, "حد بالا,$(round(prediction.gold_oz_high,digits=2)),$(round(prediction.usd_irr_high,digits=0)),$(round(prediction.iran_gold_high,digits=0))")
    println(f, "روند,$(prediction.trend)")
    println(f, "اطمینان,$(prediction.confidence)%")
    println(f, "سکه بهار آزادی,$(round(prediction.coin_point,digits=0)),$(round(prediction.coin_low,digits=0)),$(round(prediction.coin_high,digits=0))")
    println(f, "")

    # Method Weights
    println(f, "═══ وزن مدل‌ها ═══")
    println(f, "مدل,وزن")
    for (k,v) in sort(collect(prediction.method_weights), by=x->-x[2])
        println(f, "$(k),$(round(v*100,digits=1))%")
    end
    println(f, "")

    # Backtest Summary
    println(f, "═══ بک‌تست $(bt.total_days) روزه ═══")
    println(f, "شاخص,MAPE,جهت درست")
    println(f, "انس جهانی,$(round(bt.gold_mape,digits=2))%,$(round(bt.gold_direction_accuracy,digits=1))%")
    println(f, "دلار آزاد,$(round(bt.usd_mape,digits=2))%,$(round(bt.usd_direction_accuracy,digits=1))%")
    println(f, "طلای 18 عیار,$(round(bt.iran_mape,digits=2))%,$(round(bt.iran_direction_accuracy,digits=1))%")
    println(f, "")

    # Walk-Forward
    println(f, "═══ Walk-Forward Validation ═══")
    println(f, "شاخص,نمونه,MAPE,جهت,میانه,بهترین,بدترین")
    for (key, label) in [("gold_h1","انس 1 روزه"),("gold_h3","انس 3 روزه"),("gold_h7","انس 7 روزه"),
                          ("usd_h1","دلار 1 روزه"),("usd_h3","دلار 3 روزه"),
                          ("iran_h1","طلا18 1 روزه"),("iran_h3","طلا18 3 روزه")]
        d = wf[key]
        println(f, "$(label),$(d["count"]),$(d["mape"])%,$(d["direction"])%,$(d["median_error"])%,$(d["best_error"])%,$(d["worst_error"])%")
    end
    println(f, "")

    # Signals
    println(f, "═══ سیگنال‌ها ═══")
    for s in prediction.signals
        ss = strip(s)
        if !isempty(ss)
            println(f, "$(replace(ss, ","=>";"))")
        end
    end
    println(f, "")

    # Backtest Detail - Gold
    println(f, "═══ بک‌تست انس - روز به روز ═══")
    println(f, "#,تاریخ,واقعی,پیش‌بینی,خطا%,جهت")
    for (i,r) in enumerate(bt.gold_results)
        dm = r.direction_correct ? "✓" : "✗"
        println(f, "$(i),$(r.date),$(r.actual),$(r.predicted),$(r.error_pct),$(dm)")
    end
    println(f, "")

    # Backtest Detail - USD
    println(f, "═══ بک‌تست دلار - روز به روز ═══")
    println(f, "#,تاریخ,واقعی,پیش‌بینی,خطا%,جهت")
    for (i,r) in enumerate(bt.usd_results)
        dm = r.direction_correct ? "✓" : "✗"
        println(f, "$(i),$(r.date),$(r.actual),$(r.predicted),$(r.error_pct),$(dm)")
    end
    println(f, "")

    # Backtest Detail - Iran Gold
    println(f, "═══ بک‌تست طلا18 - روز به روز ═══")
    println(f, "#,تاریخ,واقعی,پیش‌بینی,خطا%,جهت")
    for (i,r) in enumerate(bt.iran_results)
        dm = r.direction_correct ? "✓" : "✗"
        println(f, "$(i),$(r.date),$(r.actual),$(r.predicted),$(r.error_pct),$(dm)")
    end
    println(f, "")

    # Correlations
    println(f, "═══ همبستگی ارزها با طلا ═══")
    println(f, "نماد,نام,پیرسون,اسپیرمن,بتا,R2,تأثیر,جهت")
    for c in analysis.correlations
        println(f, "$(c.currency),$(c.name_fa),$(c.pearson),$(c.spearman),$(c.beta),$(c.r_squared),$(round(c.impact_score*100,digits=1))%,$(c.direction)")
    end
    println(f, "")
    println(f, "═══ پایان گزارش ═══")
end

println()
println("═══════════════════════════════════════")
println("  فایل Excel/CSV ساخته شد: $(fname)")
println("  در Excel باز کن: UTF-8 CSV")
println("═══════════════════════════════════════")
