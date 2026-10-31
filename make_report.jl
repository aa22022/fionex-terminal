println("Generating Professional Report...")
println()

include("src/data_fetcher.jl")
include("src/macro_data.jl")
include("src/math_engine.jl")
include("src/predictor.jl")
include("src/backtest_engine.jl")
include("src/news_sentiment.jl")
include("src/storage.jl")

using .DataFetcher
using .MacroData
using .MathEngine
using .Predictor
using .BacktestEngine
using .NewsSentiment
using .Storage
using Dates, Statistics

# ─── Fetch Data ───
println("  Fetching data (1100 days)...")
data = fetch_all_data(1100)

println("  Macro data...")
macrodata = fetch_macro_data(180)
data["macro"] = macrodata

println("  Events...")
data["events"] = fetch_upcoming_events(14)

println("  News sentiment...")
sentiment = try fetch_news_sentiment(24) catch; nothing end
data["sentiment"] = sentiment

println("  Analysis...")
analysis = calculate_all_ratios(data)

println("  Prediction...")
prediction = predict_next_week(data, analysis)

# ─── Backtest 240 days ───
println("  Backtest 240 days...")
bt = run_historical_backtest(
    data["gold_oz"]["prices"], data["gold_oz"]["dates"],
    data["usd_irr"]["prices"], data["usd_irr"]["dates"],
    data["iran_gold"]["prices"], data["iran_gold"]["dates"];
    test_days=240, min_train=30
)

println("  Results: gold=$(round(bt.gold_mape,digits=2))% usd=$(round(bt.usd_mape,digits=2))% iran=$(round(bt.iran_mape,digits=2))%")

# ─── Walk-Forward ───
println("  Walk-forward validation...")
wf = Predictor.walk_forward_multi(
    data["gold_oz"]["prices"],
    data["usd_irr"]["prices"],
    data["iran_gold"]["prices"];
    window=60, step=5
)

# ─── Build Report ───
println("  Building report...")

report_date = Dates.format(now(), "yyyy-mm-dd HH:MM")
gold_cur = round(last(data["gold_oz"]["prices"]), digits=2)
usd_cur = round(last(data["usd_irr"]["prices"]), digits=0)
iran_cur = round(last(data["iran_gold"]["prices"]), digits=0)

dxy_val = try round(macrodata["dxy"]["current"], digits=2) catch; "--" end
us10y_val = try round(macrodata["us10y"]["current"], digits=2) catch; "--" end
vix_val = try round(macrodata["vix"]["current"], digits=2) catch; "--" end

# Backtest table rows
function bt_table_rows(results, max_rows=240)
    rows = ""
    for (i, r) in enumerate(results[1:min(max_rows, length(results))])
        ec = r.error_pct < 1 ? "#26a67a" : r.error_pct < 2 ? "#c49a3c" : "#c4444e"
        dc = r.direction_correct ? "#26a67a" : "#c4444e"
        dm = r.direction_correct ? "✓" : "✗"
        rows *= """<tr>
            <td>$(i)</td>
            <td>$(r.date)</td>
            <td style="text-align:right">$(r.actual)</td>
            <td style="text-align:right">$(r.predicted)</td>
            <td style="text-align:right;color:$(ec)">$(r.error_pct)%</td>
            <td style="text-align:center;color:$(dc)">$(dm)</td>
        </tr>"""
    end
    return rows
end

# Monthly breakdown
function monthly_breakdown(results)
    months = Dict{String,Vector{Float64}}()
    for r in results
        m = r.date[1:7]
        if !haskey(months, m); months[m] = Float64[]; end
        push!(months[m], r.error_pct)
    end
    sorted = sort(collect(months), by=x->x[1])
    rows = ""
    for (m, errs) in sorted
        avg = round(mean(errs), digits=2)
        mx = round(maximum(errs), digits=2)
        mn = round(minimum(errs), digits=2)
        cnt = length(errs)
        ec = avg < 1 ? "#26a67a" : avg < 2 ? "#c49a3c" : "#c4444e"
        rows *= """<tr>
            <td>$(m)</td>
            <td>$(cnt)</td>
            <td style="color:$(ec)"><b>$(avg)%</b></td>
            <td style="color:#26a67a">$(mn)%</td>
            <td style="color:#c4444e">$(mx)%</td>
        </tr>"""
    end
    return rows
end

# Walk-forward row
function wf_row(label, d)
    if d === nothing; return ""; end
    mc = d["mape"] === nothing ? "--" : "$(d["mape"])%"
    dc = d["direction"] === nothing ? "--" : "$(d["direction"])%"
    md = d["median_error"] === nothing ? "--" : "$(d["median_error"])%"
    be = d["best_error"] === nothing ? "--" : "$(d["best_error"])%"
    we = d["worst_error"] === nothing ? "--" : "$(d["worst_error"])%"
    cnt = d["count"]
    return """<tr><td>$(label)</td><td>$(cnt)</td><td><b>$(mc)</b></td><td>$(dc)</td><td>$(md)</td><td style="color:#26a67a">$(be)</td><td style="color:#c4444e">$(we)</td></tr>"""
end

# Prediction rows
global pred_gold_rows = ""
for (i, d) in enumerate(prediction.target_dates)
    global pred_gold_rows *= "<tr><td>$(d)</td><td style=\"text-align:right\">$(round(prediction.gold_oz_daily[i],digits=2))</td></tr>"
end

global pred_usd_rows = ""
for (i, d) in enumerate(prediction.target_dates)
    global pred_usd_rows *= "<tr><td>$(d)</td><td style=\"text-align:right\">$(round(prediction.usd_irr_daily[i],digits=0))</td></tr>"
end

global pred_iran_rows = ""
for (i, d) in enumerate(prediction.target_dates)
    global pred_iran_rows *= "<tr><td>$(d)</td><td style=\"text-align:right\">$(round(prediction.iran_gold_daily[i],digits=0))</td></tr>"
end

# Method weights
global mw_rows = ""
for (k,v) in sort(collect(prediction.method_weights), by=x->-x[2])
    pct = round(v*100, digits=1)
    global mw_rows *= "<tr><td>$(k)</td><td><b>$(pct)%</b></td></tr>"
end

# Signals
sig_html = join(["<div style=\"padding:3px 8px;border-right:2px solid #2a3340;margin-bottom:2px;font-size:11px\">$(s)</div>" for s in prediction.signals if !isempty(strip(s))], "\n")

# Sentiment
sent_html = ""
if sentiment !== nothing && sentiment.overall_score !== nothing
    sent_html = """
    <h3>تحلیل اخبار</h3>
    <table><tr><th>شاخص</th><th>مقدار</th></tr>
    <tr><td>سنتیمنت کلی</td><td>$(sentiment.overall_score)</td></tr>
    <tr><td>سنتیمنت طلا</td><td>$(sentiment.gold_score)</td></tr>
    <tr><td>سنتیمنت دلار</td><td>$(sentiment.usd_score)</td></tr>
    <tr><td>سطح هشدار</td><td>$(sentiment.alert_level)</td></tr>
    <tr><td>تعداد اخبار</td><td>$(length(sentiment.news_items))</td></tr>
    </table>"""
end

# Correlation top 5
global corr_rows = ""
for (i, c) in enumerate(analysis.correlations[1:min(5, length(analysis.correlations))])
    global corr_rows *= "<tr><td>$(c.currency)</td><td>$(c.name_fa)</td><td>$(c.pearson)</td><td>$(c.direction)</td><td>$(round(c.impact_score*100,digits=1))%</td></tr>"
end

html = """<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="UTF-8">
<title>گزارش تحلیلی سامانه پیش‌بینی طلا و ارز</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Vazirmatn:wght@300;400;500;600;700&display=swap');
* { margin:0; padding:0; box-sizing:border-box; }
body { font-family:'Vazirmatn',sans-serif; background:#fff; color:#1a1a2e; font-size:11px; line-height:1.6; direction:rtl; padding:20px 30px; }
h1 { font-size:18px; color:#0f1114; border-bottom:3px solid #b8975a; padding-bottom:8px; margin-bottom:16px; }
h2 { font-size:14px; color:#1a1a2e; border-bottom:2px solid #e5e7eb; padding-bottom:4px; margin:20px 0 10px; }
h3 { font-size:12px; color:#374151; margin:14px 0 6px; }
.header-info { display:flex; justify-content:space-between; margin-bottom:16px; font-size:10px; color:#6b7280; }
.kpi-grid { display:grid; grid-template-columns:repeat(6,1fr); gap:1px; background:#e5e7eb; border:1px solid #e5e7eb; margin-bottom:16px; }
.kpi { background:#fff; padding:10px; text-align:center; }
.kpi-label { font-size:9px; color:#6b7280; text-transform:uppercase; letter-spacing:0.5px; }
.kpi-value { font-size:16px; font-weight:700; color:#1a1a2e; margin-top:2px; }
.kpi-sub { font-size:9px; color:#9ca3af; margin-top:2px; }
table { width:100%; border-collapse:collapse; font-size:10px; margin-bottom:12px; }
th { background:#f3f4f6; color:#374151; padding:6px 4px; text-align:center; font-weight:600; border-bottom:2px solid #d1d5db; font-size:9px; text-transform:uppercase; }
td { padding:5px 4px; text-align:center; border-bottom:1px solid #f3f4f6; }
tr:nth-child(even) { background:#fafafa; }
.summary-box { background:#f8f9fa; border:1px solid #e5e7eb; padding:12px 16px; margin-bottom:12px; border-radius:4px; }
.warn { color:#c4444e; font-weight:600; }
.good { color:#26a67a; font-weight:600; }
.pred-grid { display:grid; grid-template-columns:repeat(3,1fr); gap:12px; margin-bottom:12px; }
.pred-card { background:#f8f9fa; border:1px solid #e5e7eb; padding:10px; border-radius:4px; }
.pred-card h4 { font-size:11px; color:#6b7280; margin-bottom:4px; }
.sig-box { background:#f8f9fa; border:1px solid #e5e7eb; padding:8px 12px; margin-bottom:12px; border-radius:4px; }
.footer { border-top:2px solid #e5e7eb; padding-top:8px; margin-top:20px; font-size:9px; color:#9ca3af; text-align:center; }
@media print { body { padding:10px 15px; } .no-print { display:none; } }
@page { size:A4; margin:15mm; }
</style>
</head>
<body>

<h1>📊 گزارش تحلیلی سامانه پیش‌بینی قیمت طلا و ارز</h1>

<div class="header-info">
    <span>تاریخ گزارش: $(report_date)</span>
    <span>بک‌تست: $(bt.total_days) روز</span>
    <span>Walk-Forward: $(wf["gold_h1"]["count"]) نمونه</span>
    <span>مدل: 6 الگوریتم ترکیبی + Regime + Direction</span>
</div>

<h2>1. وضعیت فعلی بازار</h2>
<div class="kpi-grid">
    <div class="kpi"><div class="kpi-label">انس جهانی</div><div class="kpi-value">\$$(gold_cur)</div></div>
    <div class="kpi"><div class="kpi-label">دلار آزاد</div><div class="kpi-value">$(usd_cur) ت</div></div>
    <div class="kpi"><div class="kpi-label">طلای 18 عیار</div><div class="kpi-value">$(iran_cur) ت</div></div>
    <div class="kpi"><div class="kpi-label">DXY</div><div class="kpi-value">$(dxy_val)</div></div>
    <div class="kpi"><div class="kpi-label">US10Y</div><div class="kpi-value">$(us10y_val)%</div></div>
    <div class="kpi"><div class="kpi-label">VIX</div><div class="kpi-value">$(vix_val)</div></div>
</div>

<h2>2. پیش‌بینی 7 روز آینده</h2>
<div class="summary-box">
    <b>روند:</b> $(prediction.trend) | <b>اطمینان:</b> $(prediction.confidence)% |
    <b>انس هدف:</b> $(round(prediction.gold_oz_point,digits=2)) |
    <b>دلار هدف:</b> $(round(prediction.usd_irr_point,digits=0)) |
    <b>طلا18 هدف:</b> $(round(prediction.iran_gold_point,digits=0))
</div>

<div class="pred-grid">
    <div class="pred-card">
        <h4>انس جهانی (دلار)</h4>
        <table><tr><th>تاریخ</th><th>پیش‌بینی</th></tr>$(pred_gold_rows)</table>
        <div style="font-size:9px;color:#6b7280">بازه: $(round(prediction.gold_oz_low,digits=0)) - $(round(prediction.gold_oz_high,digits=0))</div>
    </div>
    <div class="pred-card">
        <h4>دلار آزاد (تومان)</h4>
        <table><tr><th>تاریخ</th><th>پیش‌بینی</th></tr>$(pred_usd_rows)</table>
        <div style="font-size:9px;color:#6b7280">بازه: $(round(prediction.usd_irr_low,digits=0)) - $(round(prediction.usd_irr_high,digits=0))</div>
    </div>
    <div class="pred-card">
        <h4>طلای 18 عیار (تومان/گرم)</h4>
        <table><tr><th>تاریخ</th><th>پیش‌بینی</th></tr>$(pred_iran_rows)</table>
        <div style="font-size:9px;color:#6b7280">بازه: $(round(prediction.iran_gold_low,digits=0)) - $(round(prediction.iran_gold_high,digits=0))</div>
    </div>
</div>

<h2>3. سیگنال‌های تحلیلی</h2>
<div class="sig-box">$(sig_html)</div>

<h2>4. وزن مدل‌ها (Auto-Tuned)</h2>
<table><tr><th>مدل</th><th>وزن</th></tr>$(mw_rows)</table>

$(sent_html)

<h2>5. بک‌تست $(bt.total_days) روزه</h2>
<div class="kpi-grid" style="grid-template-columns:repeat(3,1fr)">
    <div class="kpi">
        <div class="kpi-label">انس جهانی</div>
        <div class="kpi-value">MAPE $(round(bt.gold_mape,digits=2))%</div>
        <div class="kpi-sub">جهت: $(round(bt.gold_direction_accuracy,digits=1))%</div>
    </div>
    <div class="kpi">
        <div class="kpi-label">دلار آزاد</div>
        <div class="kpi-value">MAPE $(round(bt.usd_mape,digits=2))%</div>
        <div class="kpi-sub">جهت: $(round(bt.usd_direction_accuracy,digits=1))%</div>
    </div>
    <div class="kpi">
        <div class="kpi-label">طلای 18 عیار</div>
        <div class="kpi-value">MAPE $(round(bt.iran_mape,digits=2))%</div>
        <div class="kpi-sub">جهت: $(round(bt.iran_direction_accuracy,digits=1))%</div>
    </div>
</div>

<h3>5.1 تفکیک ماهانه - انس</h3>
<table><tr><th>ماه</th><th>تعداد</th><th>MAPE میانگین</th><th>بهترین</th><th>بدترین</th></tr>
$(monthly_breakdown(bt.gold_results))</table>

<h3>5.2 تفکیک ماهانه - دلار</h3>
<table><tr><th>ماه</th><th>تعداد</th><th>MAPE میانگین</th><th>بهترین</th><th>بدترین</th></tr>
$(monthly_breakdown(bt.usd_results))</table>

<h3>5.3 تفکیک ماهانه - طلای 18 عیار</h3>
<table><tr><th>ماه</th><th>تعداد</th><th>MAPE میانگین</th><th>بهترین</th><th>بدترین</th></tr>
$(monthly_breakdown(bt.iran_results))</table>

<h2>6. Walk-Forward Validation</h2>
<table>
<tr><th>شاخص</th><th>نمونه</th><th>MAPE</th><th>جهت</th><th>میانه</th><th>بهترین</th><th>بدترین</th></tr>
$(wf_row("انس 1 روزه", wf["gold_h1"]))
$(wf_row("انس 3 روزه", wf["gold_h3"]))
$(wf_row("انس 7 روزه", wf["gold_h7"]))
$(wf_row("دلار 1 روزه", wf["usd_h1"]))
$(wf_row("دلار 3 روزه", wf["usd_h3"]))
$(wf_row("طلا18 1 روزه", wf["iran_h1"]))
$(wf_row("طلا18 3 روزه", wf["iran_h3"]))
</table>

<h2>7. جدول بک‌تست انس - روز به روز</h2>
<table>
<tr><th>#</th><th>تاریخ</th><th>واقعی</th><th>پیش‌بینی</th><th>خطا</th><th>جهت</th></tr>
$(bt_table_rows(bt.gold_results))
</table>

<h2>8. جدول بک‌تست دلار - روز به روز</h2>
<table>
<tr><th>#</th><th>تاریخ</th><th>واقعی</th><th>پیش‌بینی</th><th>خطا</th><th>جهت</th></tr>
$(bt_table_rows(bt.usd_results))
</table>

<h2>9. جدول بک‌تست طلای 18 عیار - روز به روز</h2>
<table>
<tr><th>#</th><th>تاریخ</th><th>واقعی</th><th>پیش‌بینی</th><th>خطا</th><th>جهت</th></tr>
$(bt_table_rows(bt.iran_results))
</table>

<h2>10. همبستگی ارزها با طلا (5 برتر)</h2>
<table>
<tr><th>نماد</th><th>نام</th><th>پیرسون</th><th>جهت</th><th>تأثیر</th></tr>
$(corr_rows)
</table>

<div class="footer">
    <p class="warn">هشدار: پیش‌بینی‌ها صرفاً تحلیلی هستند و تضمین سود ندارند.</p>
    <p>سامانه پیش‌بینی قیمت طلا و ارز | نسخه 5.0 | $(report_date)</p>
    <p>مدل: ARIMA + Holt-Winters + Ridge + Monte Carlo/GARCH + Technical + Currency Impact + Direction + Sentiment</p>
</div>

</body>
</html>"""

# Save
report_file = "report_$(Dates.format(now(),"yyyymmdd_HHMM")).html"
open(report_file, "w") do f
    write(f, html)
end

println()
println("═══════════════════════════════════════")
println("  گزارش ساخته شد: $(report_file)")
println("  برای PDF: باز کن در مرورگر → Ctrl+P → Save as PDF")
println("═══════════════════════════════════════")
