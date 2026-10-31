println("Generating Compact PDF Report...")

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

report_date = Dates.format(now(), "yyyy-mm-dd HH:MM")
gold_cur = round(last(data["gold_oz"]["prices"]), digits=2)
usd_cur = round(Int, last(data["usd_irr"]["prices"]))
iran_cur = round(Int, last(data["iran_gold"]["prices"]))
dxy_val = try round(macrodata["dxy"]["current"], digits=2) catch; "--" end
us10y_val = try round(macrodata["us10y"]["current"], digits=2) catch; "--" end
vix_val = try round(macrodata["vix"]["current"], digits=2) catch; "--" end

# Backtest rows compact
function bt_rows_compact(results)
    rows = ""
    for r in results
        ec = r.error_pct < 1 ? "#27ae60" : r.error_pct < 2 ? "#e67e22" : "#e74c3c"
        dc = r.direction_correct ? "#27ae60" : "#e74c3c"
        dm = r.direction_correct ? "✓" : "✗"
        rows *= "<tr><td>$(r.date)</td><td>$(r.actual)</td><td>$(r.predicted)</td><td style='color:$(ec)'>$(r.error_pct)%</td><td style='color:$(dc)'>$(dm)</td></tr>"
    end
    return rows
end

# Monthly stats
function monthly_stats(results)
    months = Dict{String,Vector{Float64}}()
    dirs = Dict{String,Vector{Bool}}()
    for r in results
        m = r.date[1:7]
        if !haskey(months, m); months[m] = Float64[]; dirs[m] = Bool[]; end
        push!(months[m], r.error_pct)
        push!(dirs[m], r.direction_correct)
    end
    rows = ""
    for (m, errs) in sort(collect(months), by=x->x[1])
        avg = round(mean(errs), digits=2)
        dir_pct = round(mean(dirs[m]) * 100, digits=1)
        cnt = length(errs)
        ec = avg < 1 ? "#27ae60" : avg < 2 ? "#e67e22" : "#e74c3c"
        dc = dir_pct >= 55 ? "#27ae60" : "#e74c3c"
        rows *= "<tr><td>$(m)</td><td>$(cnt)</td><td style='color:$(ec)'><b>$(avg)%</b></td><td style='color:$(dc)'>$(dir_pct)%</td></tr>"
    end
    return rows
end

# Pred rows
global pred_rows = ""
for (i,d) in enumerate(prediction.target_dates)
    chg_g = round((prediction.gold_oz_daily[i] - gold_cur) / gold_cur * 100, digits=2)
    chg_u = round((prediction.usd_irr_daily[i] - usd_cur) / usd_cur * 100, digits=2)
    gc = chg_g >= 0 ? "#27ae60" : "#e74c3c"
    uc = chg_u >= 0 ? "#27ae60" : "#e74c3c"
    global pred_rows *= "<tr><td>$(d)</td><td>$(round(prediction.gold_oz_daily[i],digits=2)) <span style='color:$(gc);font-size:9px'>($(chg_g)%)</span></td><td>$(round(Int,prediction.usd_irr_daily[i])) <span style='color:$(uc);font-size:9px'>($(chg_u)%)</span></td><td>$(round(Int,prediction.iran_gold_daily[i]))</td></tr>"
end

# Method weights
global mw_rows = ""
for (k,v) in sort(collect(prediction.method_weights), by=x->-x[2])
    pct = round(v*100, digits=1)
    bar_w = round(Int, pct * 3)
    global mw_rows *= "<tr><td>$(k)</td><td><div style='background:#3498db;width:$(bar_w)px;height:10px;display:inline-block;border-radius:2px'></div> $(pct)%</td></tr>"
end

# WF rows
function wf_row_html(label, d)
    d === nothing && return ""
    mc = d["mape"] === nothing ? "--" : "$(d["mape"])%"
    dc = d["direction"] === nothing ? "--%" : "$(d["direction"])%"
    ec = d["mape"] !== nothing && d["mape"] < 1.5 ? "#27ae60" : d["mape"] !== nothing && d["mape"] < 2.5 ? "#e67e22" : "#e74c3c"
    dc2 = d["direction"] !== nothing && d["direction"] >= 55 ? "#27ae60" : "#e74c3c"
    return "<tr><td>$(label)</td><td>$(d["count"])</td><td style='color:$(ec)'><b>$(mc)</b></td><td style='color:$(dc2)'>$(dc)</td><td>$(d["median_error"] === nothing ? "--" : "$(d["median_error"])%")</td><td style='color:#27ae60'>$(d["best_error"] === nothing ? "--" : "$(d["best_error"])%")</td><td style='color:#e74c3c'>$(d["worst_error"] === nothing ? "--" : "$(d["worst_error"])%")</td></tr>"
end

# Signals compact
sig_items = join(["<span style='background:#f8f9fa;padding:2px 6px;border-radius:3px;font-size:9px;margin:1px;display:inline-block'>$(s)</span>" for s in prediction.signals if !isempty(strip(s))], "\n")

html = """<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="UTF-8">
<title>گزارش تحلیلی طلا و ارز - $(report_date)</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;500;600;700&display=swap');
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Vazirmatn',sans-serif;background:#fff;color:#1a1a1a;font-size:10px;direction:rtl;padding:12px 16px}

/* Header */
.report-header{background:linear-gradient(135deg,#1a1a2e,#16213e);color:#fff;padding:14px 18px;border-radius:6px;margin-bottom:10px;display:flex;justify-content:space-between;align-items:center}
.report-header h1{font-size:15px;font-weight:700;color:#f0c040}
.report-header .meta{font-size:9px;color:#aaa;text-align:left}

/* KPI Row */
.kpi-row{display:grid;grid-template-columns:repeat(6,1fr);gap:4px;margin-bottom:8px}
.kpi{background:#f8f9fa;border:1px solid #e9ecef;border-radius:4px;padding:6px 8px;text-align:center}
.kpi-label{font-size:8px;color:#6c757d;text-transform:uppercase;letter-spacing:0.3px}
.kpi-value{font-size:14px;font-weight:700;color:#1a1a2e;margin-top:2px}
.kpi-sub{font-size:8px;color:#adb5bd;margin-top:1px}

/* Two column layout */
.two-col{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:8px}
.three-col{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin-bottom:8px}

/* Section */
.section{background:#fff;border:1px solid #dee2e6;border-radius:4px;padding:8px 10px;margin-bottom:8px}
.section-title{font-size:9px;font-weight:700;color:#495057;text-transform:uppercase;letter-spacing:0.5px;border-bottom:1px solid #e9ecef;padding-bottom:4px;margin-bottom:6px}

/* Table */
table{width:100%;border-collapse:collapse;font-size:9px}
th{background:#f1f3f5;color:#495057;padding:4px 5px;text-align:center;font-weight:700;font-size:8px;border-bottom:1px solid #dee2e6}
td{padding:3px 5px;text-align:center;border-bottom:1px solid #f8f9fa}
tr:hover{background:#f8f9fa}

/* Stats bar */
.stat-row{display:flex;justify-content:space-between;padding:3px 0;border-bottom:1px solid #f8f9fa;font-size:9px}
.stat-label{color:#6c757d}
.stat-value{font-weight:600;color:#1a1a2e}

/* Badges */
.badge{padding:2px 6px;border-radius:3px;font-size:8px;font-weight:600}
.badge-good{background:#d4edda;color:#155724}
.badge-warn{background:#fff3cd;color:#856404}
.badge-bad{background:#f8d7da;color:#721c24}

/* Warning */
.warning{background:#fff3cd;border:1px solid #ffc107;border-radius:4px;padding:6px 10px;font-size:9px;color:#856404;text-align:center;margin-top:8px}

@media print{
  body{padding:8px 10px}
  @page{size:A4;margin:10mm}
  .no-break{page-break-inside:avoid}
}
</style>
</head>
<body>

<!-- Header -->
<div class="report-header">
  <div>
    <h1>📊 گزارش تحلیلی سامانه پیش‌بینی طلا و ارز</h1>
    <div style="font-size:9px;color:#ccc;margin-top:3px">مدل ترکیبی: ARIMA + Holt-Winters + Ridge + Monte Carlo/GARCH + Technical + Direction + Sentiment</div>
  </div>
  <div class="meta">
    <div>تاریخ: $(report_date)</div>
    <div>بک‌تست: $(bt.total_days) روز</div>
    <div>Walk-Forward: $(wf["gold_h1"]["count"]) نمونه</div>
    <div>اطمینان: $(prediction.confidence)% | روند: $(prediction.trend)</div>
  </div>
</div>

<!-- KPIs -->
<div class="kpi-row">
  <div class="kpi"><div class="kpi-label">انس جهانی</div><div class="kpi-value">\$$(gold_cur)</div><div class="kpi-sub">USD/oz</div></div>
  <div class="kpi"><div class="kpi-label">دلار آزاد</div><div class="kpi-value">$(usd_cur)</div><div class="kpi-sub">تومان</div></div>
  <div class="kpi"><div class="kpi-label">طلای 18 عیار</div><div class="kpi-value">$(iran_cur)</div><div class="kpi-sub">تومان/گرم</div></div>
  <div class="kpi"><div class="kpi-label">DXY</div><div class="kpi-value">$(dxy_val)</div></div>
  <div class="kpi"><div class="kpi-label">US10Y</div><div class="kpi-value">$(us10y_val)%</div></div>
  <div class="kpi"><div class="kpi-label">VIX</div><div class="kpi-value">$(vix_val)</div></div>
</div>

<div class="two-col">
  <!-- Prediction -->
  <div class="section no-break">
    <div class="section-title">پیش‌بینی 7 روز آینده</div>
    <table>
      <tr><th>تاریخ</th><th>انس (USD)</th><th>دلار (ت)</th><th>طلا18 (ت)</th></tr>
      $(pred_rows)
    </table>
    <div style="margin-top:5px;font-size:9px;color:#6c757d">
      <div>انس: $(round(prediction.gold_oz_low,digits=0)) ← $(round(prediction.gold_oz_point,digits=2)) → $(round(prediction.gold_oz_high,digits=0))</div>
      <div>دلار: $(round(Int,prediction.usd_irr_low)) ← $(round(Int,prediction.usd_irr_point)) → $(round(Int,prediction.usd_irr_high))</div>
      <div>سکه: $(round(Int,prediction.coin_low)) ← $(round(Int,prediction.coin_point)) → $(round(Int,prediction.coin_high))</div>
    </div>
  </div>

  <!-- Signals + Weights -->
  <div>
    <div class="section no-break" style="margin-bottom:6px">
      <div class="section-title">سیگنال‌های تحلیلی</div>
      <div style="line-height:1.8">$(sig_items)</div>
    </div>
    <div class="section no-break">
      <div class="section-title">وزن مدل‌ها (Auto-Tuned)</div>
      <table>$(mw_rows)</table>
    </div>
  </div>
</div>

<!-- Backtest Summary -->
<div class="section no-break">
  <div class="section-title">بک‌تست $(bt.total_days) روزه - خلاصه عملکرد</div>
  <div class="three-col" style="gap:4px">
    <div style="text-align:center;padding:6px;background:#f8f9fa;border-radius:4px">
      <div style="font-size:9px;color:#6c757d">انس جهانی</div>
      <div style="font-size:16px;font-weight:700;color:$(bt.gold_mape<1.5 ? "#27ae60" : bt.gold_mape<2.5 ? "#e67e22" : "#e74c3c")">$(round(bt.gold_mape,digits=2))%</div>
      <div style="font-size:9px">MAPE | جهت: $(round(bt.gold_direction_accuracy,digits=1))%</div>
    </div>
    <div style="text-align:center;padding:6px;background:#f8f9fa;border-radius:4px">
      <div style="font-size:9px;color:#6c757d">دلار آزاد</div>
      <div style="font-size:16px;font-weight:700;color:$(bt.usd_mape<1.5 ? "#27ae60" : bt.usd_mape<2.5 ? "#e67e22" : "#e74c3c")">$(round(bt.usd_mape,digits=2))%</div>
      <div style="font-size:9px">MAPE | جهت: $(round(bt.usd_direction_accuracy,digits=1))%</div>
    </div>
    <div style="text-align:center;padding:6px;background:#f8f9fa;border-radius:4px">
      <div style="font-size:9px;color:#6c757d">طلای 18 عیار</div>
      <div style="font-size:16px;font-weight:700;color:$(bt.iran_mape<1.5 ? "#27ae60" : bt.iran_mape<2.5 ? "#e67e22" : "#e74c3c")">$(round(bt.iran_mape,digits=2))%</div>
      <div style="font-size:9px">MAPE | جهت: $(round(bt.iran_direction_accuracy,digits=1))%</div>
    </div>
  </div>
</div>

<!-- Walk-Forward -->
<div class="section no-break">
  <div class="section-title">Walk-Forward Validation</div>
  <table>
    <tr><th>شاخص</th><th>نمونه</th><th>MAPE</th><th>جهت</th><th>میانه</th><th>بهترین</th><th>بدترین</th></tr>
    $(wf_row_html("انس 1 روزه", wf["gold_h1"]))
    $(wf_row_html("انس 3 روزه", wf["gold_h3"]))
    $(wf_row_html("انس 7 روزه", wf["gold_h7"]))
    $(wf_row_html("دلار 1 روزه", wf["usd_h1"]))
    $(wf_row_html("دلار 3 روزه", wf["usd_h3"]))
    $(wf_row_html("طلا18 1 روزه", wf["iran_h1"]))
    $(wf_row_html("طلا18 3 روزه", wf["iran_h3"]))
  </table>
</div>

<div class="two-col">
  <!-- Monthly Gold -->
  <div class="section no-break">
    <div class="section-title">تفکیک ماهانه - انس</div>
    <table>
      <tr><th>ماه</th><th>روز</th><th>MAPE</th><th>جهت</th></tr>
      $(monthly_stats(bt.gold_results))
    </table>
  </div>

  <!-- Monthly USD -->
  <div class="section no-break">
    <div class="section-title">تفکیک ماهانه - دلار</div>
    <table>
      <tr><th>ماه</th><th>روز</th><th>MAPE</th><th>جهت</th></tr>
      $(monthly_stats(bt.usd_results))
    </table>
  </div>
</div>

<!-- Monthly Iran -->
<div class="section no-break">
  <div class="section-title">تفکیک ماهانه - طلای 18 عیار</div>
  <table>
    <tr><th>ماه</th><th>روز</th><th>MAPE</th><th>جهت</th></tr>
    $(monthly_stats(bt.iran_results))
  </table>
</div>

<!-- Backtest Detail Tables -->
<div class="section">
  <div class="section-title">بک‌تست انس - روز به روز ($(bt.total_days) روز)</div>
  <table>
    <tr><th>تاریخ</th><th>واقعی</th><th>پیش‌بینی</th><th>خطا%</th><th>جهت</th></tr>
    $(bt_rows_compact(bt.gold_results))
  </table>
</div>

<div class="section">
  <div class="section-title">بک‌تست دلار - روز به روز ($(bt.total_days) روز)</div>
  <table>
    <tr><th>تاریخ</th><th>واقعی</th><th>پیش‌بینی</th><th>خطا%</th><th>جهت</th></tr>
    $(bt_rows_compact(bt.usd_results))
  </table>
</div>

<div class="section">
  <div class="section-title">بک‌تست طلای 18 عیار - روز به روز ($(bt.total_days) روز)</div>
  <table>
    <tr><th>تاریخ</th><th>واقعی</th><th>پیش‌بینی</th><th>خطا%</th><th>جهت</th></tr>
    $(bt_rows_compact(bt.iran_results))
  </table>
</div>

<!-- Correlations -->
<div class="section no-break">
  <div class="section-title">همبستگی ارزها با طلا</div>
  <table>
    <tr><th>نماد</th><th>نام</th><th>پیرسون</th><th>اسپیرمن</th><th>بتا</th><th>R²</th><th>تأثیر</th><th>جهت</th></tr>
    $(join(["<tr><td><b>$(c.currency)</b></td><td>$(c.name_fa)</td><td>$(c.pearson)</td><td>$(c.spearman)</td><td>$(c.beta)</td><td>$(c.r_squared)</td><td>$(round(c.impact_score*100,digits=1))%</td><td>$(c.direction)</td></tr>" for c in analysis.correlations], "\n"))
  </table>
</div>

<div class="warning">
  ⚠️ هشدار: پیش‌بینی‌ها صرفاً تحلیلی هستند و تضمین سود ندارند | $(report_date) | نسخه 5.0
</div>

</body>
</html>"""

fname = "compact_report_$(Dates.format(now(),"yyyymmdd_HHMM")).html"
open(fname, "w") do f
    write(f, html)
end

println()
println("═══════════════════════════════════════")
println("  گزارش فشرده ساخته شد: $(fname)")
println("  Ctrl+P → Save as PDF → Scale:75%")
println("═══════════════════════════════════════")
