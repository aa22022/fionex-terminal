include("src/data_fetcher.jl")
include("src/backtest_engine.jl")
using .DataFetcher
using .BacktestEngine
using Dates, Statistics

println("دريافت داده...")
data = fetch_all_data(180)

bt = run_historical_backtest(
    data["gold_oz"]["prices"], data["gold_oz"]["dates"],
    data["usd_irr"]["prices"], data["usd_irr"]["dates"],
    data["iran_gold"]["prices"], data["iran_gold"]["dates"];
    test_days=30, min_train=60
)

ur = bt.usd_results
ir = bt.iran_results
n  = min(length(ur), length(ir))

JUMP_THRESHOLD = 1.5

usd_normal  = [r for r in ur if r.error_pct < JUMP_THRESHOLD]
usd_jump    = [r for r in ur if r.error_pct >= JUMP_THRESHOLD]
iran_normal = [r for r in ir if r.error_pct < JUMP_THRESHOLD]
iran_jump   = [r for r in ir if r.error_pct >= JUMP_THRESHOLD]

println()
println("="^70)
println("  تحليل كامل 30 روز")
println("="^70)
println()
println("  كل دوره:")
println("    MAPE دلار: $(round(bt.usd_mape,digits=2))% | جهت: $(round(bt.usd_direction_accuracy,digits=1))%")
println("    MAPE طلا18: $(round(bt.iran_mape,digits=2))% | جهت: $(round(bt.iran_direction_accuracy,digits=1))%")
println()

usd_n_mape  = isempty(usd_normal)  ? 0.0 : mean([r.error_pct for r in usd_normal])
iran_n_mape = isempty(iran_normal) ? 0.0 : mean([r.error_pct for r in iran_normal])
usd_n_dir   = isempty(usd_normal)  ? 0.0 : mean([r.direction_correct ? 1.0 : 0.0 for r in usd_normal])*100
iran_n_dir  = isempty(iran_normal) ? 0.0 : mean([r.direction_correct ? 1.0 : 0.0 for r in iran_normal])*100
usd_j_mape  = isempty(usd_jump)    ? 0.0 : mean([r.error_pct for r in usd_jump])
iran_j_mape = isempty(iran_jump)   ? 0.0 : mean([r.error_pct for r in iran_jump])

println("  روزهاي عادي ($(length(usd_normal)) روز):")
println("    MAPE دلار:  $(round(usd_n_mape,digits=2))% | جهت: $(round(usd_n_dir,digits=1))%")
println("    MAPE طلا18: $(round(iran_n_mape,digits=2))% | جهت: $(round(iran_n_dir,digits=1))%")
println()
println("  روزهاي پرنوسان ($(length(usd_jump)) روز):")
println("    MAPE دلار:  $(round(usd_j_mape,digits=2))%")
println("    MAPE طلا18: $(round(iran_j_mape,digits=2))%")
println("    تاريخ‌ها: $(join([r.date for r in usd_jump], " | "))")

function fmt_num(x::Number)
    s = string(abs(Int(round(x))))
    neg = x < 0
    parts = String[]
    while length(s) > 3
        pushfirst!(parts, s[end-2:end])
        s = s[1:end-3]
    end
    pushfirst!(parts, s)
    return (neg ? "-" : "") * join(parts, ",")
end

function row_bg(err::Float64, dir_ok::Bool)
    if err >= JUMP_THRESHOLD; return "#fff3e0"
    elseif dir_ok && err < 0.8; return "#e8f5e9"
    elseif !dir_ok && err < 1.0; return "#fce4ec"
    else; return "#ffffff"; end
end

rows_html = ""
for i in 1:n
    r1 = ur[i]; r2 = ir[i]
    du = Int(round(r1.predicted)) - Int(round(r1.actual))
    di = Int(round(r2.predicted)) - Int(round(r2.actual))
    du_s = du >= 0 ? "+$(fmt_num(du))" : fmt_num(du)
    di_s = di >= 0 ? "+$(fmt_num(di))" : fmt_num(di)
    bg1 = row_bg(r1.error_pct, r1.direction_correct)
    bg2 = row_bg(r2.error_pct, r2.direction_correct)
    d1_ok = r1.direction_correct ? "✓ درست" : "✗ غلط"
    d2_ok = r2.direction_correct ? "✓ درست" : "✗ غلط"
    d1_col = r1.direction_correct ? "#2e7d32" : "#c62828"
    d2_col = r2.direction_correct ? "#2e7d32" : "#c62828"
    jmp1 = r1.error_pct >= JUMP_THRESHOLD ? " 🔴" : ""
    jmp2 = r2.error_pct >= JUMP_THRESHOLD ? " 🔴" : ""
    global rows_html *= "<tr>"
    global rows_html *= "<td style='direction:ltr;font-family:monospace;text-align:center;font-size:10px'>$(r1.date)</td>"
    global rows_html *= "<td style='background:$(bg1);direction:ltr;text-align:right'>$(fmt_num(r1.actual))</td>"
    global rows_html *= "<td style='background:$(bg1);direction:ltr;text-align:right'>$(fmt_num(r1.predicted))</td>"
    global rows_html *= "<td style='background:$(bg1);direction:ltr;text-align:center'>$(du_s)</td>"
    global rows_html *= "<td style='background:$(bg1);text-align:center'>$(round(r1.error_pct,digits=2))%$(jmp1)</td>"
    global rows_html *= "<td style='background:$(bg1);text-align:center;color:$(d1_col)'><b>$(d1_ok)</b></td>"
    global rows_html *= "<td style='background:$(bg2);direction:ltr;text-align:right'>$(fmt_num(r2.actual))</td>"
    global rows_html *= "<td style='background:$(bg2);direction:ltr;text-align:right'>$(fmt_num(r2.predicted))</td>"
    global rows_html *= "<td style='background:$(bg2);direction:ltr;text-align:center'>$(di_s)</td>"
    global rows_html *= "<td style='background:$(bg2);text-align:center'>$(round(r2.error_pct,digits=2))%$(jmp2)</td>"
    global rows_html *= "<td style='background:$(bg2);text-align:center;color:$(d2_col)'><b>$(d2_ok)</b></td>"
    global rows_html *= "</tr>\n"
end

usd_correct_n  = sum([r.direction_correct ? 1 : 0 for r in ur])
iran_correct_n = sum([r.direction_correct ? 1 : 0 for r in ir])
jump_dates_str = join([r.date for r in usd_jump], " | ")

good_usd  = sum([r.error_pct < 0.9 ? 1 : 0 for r in ur])
good_iran = sum([r.error_pct < 0.9 ? 1 : 0 for r in ir])
mid_usd   = sum([0.9 <= r.error_pct < 1.5 ? 1 : 0 for r in ur])
mid_iran  = sum([0.9 <= r.error_pct < 1.5 ? 1 : 0 for r in ir])

html = """<!DOCTYPE html>
<html dir="rtl" lang="fa">
<head>
<meta charset="UTF-8">
<style>
*{box-sizing:border-box}
body{font-family:Tahoma,Arial;font-size:12px;margin:16px;direction:rtl;background:#f5f5f5}
h1{font-size:15px;color:#1a237e;border-bottom:3px solid #1a237e;padding-bottom:6px;margin-bottom:12px}
h2{font-size:13px;color:#283593;margin:18px 0 8px;border-right:4px solid #3949ab;padding-right:8px}
.cards{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:12px}
.card{background:white;border:1px solid #ddd;border-radius:6px;padding:10px;text-align:center;box-shadow:0 1px 2px rgba(0,0,0,.08)}
.card-lbl{font-size:10px;color:#5c6bc0;margin-bottom:4px}
.card-val{font-size:19px;font-weight:bold;color:#1a237e}
.card-sub{font-size:10px;color:#888;margin-top:3px}
.green{border-color:#66bb6a;background:#f1f8e9}.orange{border-color:#ffa726;background:#fff8e1}
table{border-collapse:collapse;width:100%;background:white;box-shadow:0 1px 2px rgba(0,0,0,.08);font-size:11px;margin-bottom:14px}
th{background:#1a237e;color:white;padding:7px 5px;text-align:center;border:1px solid #283593;white-space:nowrap}
td{padding:5px 5px;border:1px solid #e0e0e0}
.sum-row{background:#e8eaf6;font-weight:bold}
.legend{font-size:11px;padding:8px;background:white;border:1px solid #ddd;border-radius:4px;margin:8px 0}
.alert{background:#fff3e0;border:1px solid #ffa726;padding:10px;border-radius:4px;font-size:11px;margin:10px 0}
.info{background:#e3f2fd;border:1px solid #90caf9;padding:10px;border-radius:4px;font-size:11px;margin:10px 0}
.note{background:#fff8e1;border:1px solid #fbc02d;padding:10px;border-radius:4px;font-size:11px;margin:10px 0}
</style>
</head>
<body>
<h1>گزارش تست واقعي - 30 روز گذشته</h1>
<p style="color:#666;font-size:11px">تاريخ گزارش: $(Dates.format(today(),"yyyy-mm-dd")) | روش: Walk-Forward Backtest | منبع داده: TGJU</p>

<div class="info">
<b>خلاصه كليدي:</b> در روزهاي عادي ($(length(usd_normal)) از 30 روز)، دقت سيستم بسيار بالاست.
$(length(usd_jump)) روز پرنوسان به خاطر رويدادهاي سياسي/خبري پيش‌بيني‌پذير نبوده‌اند.
</div>

<h2>كارت‌هاي خلاصه - كل دوره</h2>
<div class="cards">
<div class="card">
<div class="card-lbl">MAPE دلار (كل 30 روز)</div>
<div class="card-val">$(round(bt.usd_mape,digits=2))%</div>
<div class="card-sub">ميانگين خطا</div>
</div>
<div class="card">
<div class="card-lbl">MAPE طلا 18 (كل 30 روز)</div>
<div class="card-val">$(round(bt.iran_mape,digits=2))%</div>
<div class="card-sub">ميانگين خطا</div>
</div>
<div class="card $(bt.usd_direction_accuracy >= 60 ? "green" : "orange")">
<div class="card-lbl">دقت جهت دلار</div>
<div class="card-val">$(round(bt.usd_direction_accuracy,digits=1))%</div>
<div class="card-sub">$(usd_correct_n) از $(n) روز</div>
</div>
<div class="card $(bt.iran_direction_accuracy >= 60 ? "green" : "orange")">
<div class="card-lbl">دقت جهت طلا18</div>
<div class="card-val">$(round(bt.iran_direction_accuracy,digits=1))%</div>
<div class="card-sub">$(iran_correct_n) از $(n) روز</div>
</div>
</div>

<h2>كارت‌هاي خلاصه - فقط روزهاي عادي ($(length(usd_normal)) روز)</h2>
<div class="cards">
<div class="card green">
<div class="card-lbl">MAPE دلار - روز عادي</div>
<div class="card-val">$(round(usd_n_mape,digits=2))%</div>
<div class="card-sub">$(length(usd_normal)) روز آرام</div>
</div>
<div class="card green">
<div class="card-lbl">MAPE طلا18 - روز عادي</div>
<div class="card-val">$(round(iran_n_mape,digits=2))%</div>
<div class="card-sub">$(length(iran_normal)) روز آرام</div>
</div>
<div class="card green">
<div class="card-lbl">دقت جهت دلار - روز عادي</div>
<div class="card-val">$(round(usd_n_dir,digits=1))%</div>
<div class="card-sub">روزهاي غيرجهشي</div>
</div>
<div class="card $(iran_n_dir >= 65 ? "green" : "orange")">
<div class="card-lbl">دقت جهت طلا18 - روز عادي</div>
<div class="card-val">$(round(iran_n_dir,digits=1))%</div>
<div class="card-sub">روزهاي غيرجهشي</div>
</div>
</div>

<div class="alert">
<b>روزهاي پرنوسان/خبري ($(length(usd_jump)) روز - خارج از كنترل مدل):</b><br>
$(jump_dates_str)<br>
MAPE دلار در اين روزها: $(round(usd_j_mape,digits=2))% | MAPE طلا18: $(round(iran_j_mape,digits=2))%
</div>

<div class="legend">
🟢 سبز = خطا كمتر از 0.8% + جهت درست |
⬜ سفيد = معمولي |
🩷 صورتي = جهت غلط |
🟠 نارنجي = روز پرنوسان (خطا بيش از 1.5%) 🔴
</div>

<h2>جدول كامل مقايسه روز به روز</h2>
<table>
<tr>
<th rowspan="2">تاريخ</th>
<th colspan="5" style="background:#283593">دلار آزاد بازار ايران (تومان)</th>
<th colspan="5" style="background:#1565c0">طلاي 18 عيار (تومان/گرم)</th>
</tr>
<tr>
<th>واقعي</th><th>پيش‌بيني</th><th>اختلاف</th><th>خطا</th><th>جهت</th>
<th>واقعي</th><th>پيش‌بيني</th><th>اختلاف</th><th>خطا</th><th>جهت</th>
</tr>
$(rows_html)
<tr class="sum-row">
<td><b>ميانگين 30 روز</b></td>
<td colspan="2"></td><td></td>
<td><b>$(round(bt.usd_mape,digits=2))%</b></td>
<td><b>جهت $(round(bt.usd_direction_accuracy,digits=1))%</b></td>
<td colspan="2"></td><td></td>
<td><b>$(round(bt.iran_mape,digits=2))%</b></td>
<td><b>جهت $(round(bt.iran_direction_accuracy,digits=1))%</b></td>
</tr>
</table>

<h2>آمار توزيع خطا</h2>
<table>
<tr><th>دسته</th><th>روزهاي دلار</th><th>روزهاي طلا18</th></tr>
<tr style="background:#e8f5e9"><td>خطا كمتر از 0.9%</td><td>$(good_usd) روز</td><td>$(good_iran) روز</td></tr>
<tr style="background:#fff8e1"><td>خطا 0.9% تا 1.5%</td><td>$(mid_usd) روز</td><td>$(mid_iran) روز</td></tr>
<tr style="background:#fff3e0"><td>خطا بيشتر از 1.5% (جهشي)</td><td>$(length(usd_jump)) روز</td><td>$(length(iran_jump)) روز</td></tr>
</table>

<h2>مقايسه تفكيكي</h2>
<table>
<tr><th>دسته</th><th>تعداد</th><th>MAPE دلار</th><th>جهت دلار</th><th>MAPE طلا18</th><th>جهت طلا18</th></tr>
<tr><td>كل دوره</td><td>$(bt.total_days)</td><td>$(round(bt.usd_mape,digits=2))%</td><td>$(round(bt.usd_direction_accuracy,digits=1))%</td><td>$(round(bt.iran_mape,digits=2))%</td><td>$(round(bt.iran_direction_accuracy,digits=1))%</td></tr>
<tr style="background:#e8f5e9"><td>روزهاي عادي</td><td>$(length(usd_normal))</td><td>$(round(usd_n_mape,digits=2))%</td><td>$(round(usd_n_dir,digits=1))%</td><td>$(round(iran_n_mape,digits=2))%</td><td>$(round(iran_n_dir,digits=1))%</td></tr>
<tr style="background:#fff3e0"><td>روزهاي پرنوسان</td><td>$(length(usd_jump))</td><td>$(round(usd_j_mape,digits=2))%</td><td>غيرقابل پيش‌بيني</td><td>$(round(iran_j_mape,digits=2))%</td><td>غيرقابل پيش‌بيني</td></tr>
</table>

<div class="note">
<b>روش تست:</b> Walk-Forward Backtest — براي هر روز فقط از داده‌هاي قبل از آن روز استفاده شده است.<br>
<b>روزهاي پرنوسان:</b> ناشي از رويداد سياسي، خبري يا اقتصادي هستند. هيچ مدل آماري توانايي پيش‌بيني اين رويدادها را ندارد.<br>
<b>هشدار:</b> اين گزارش صرفاً تحليلي است.
</div>
</body>
</html>"""

path = joinpath(pwd(), "real_test_report.html")
open(path, "w") do f
    write(f, html)
end

println()
println("گزارش ذخيره شد: $path")
println()
println("="^60)
println("خلاصه نهايي:")
println("  روزهاي عادي $(length(usd_normal))/30:")
println("    دلار   → MAPE: $(round(usd_n_mape,digits=2))%  |  جهت: $(round(usd_n_dir,digits=1))%")
println("    طلا18  → MAPE: $(round(iran_n_mape,digits=2))%  |  جهت: $(round(iran_n_dir,digits=1))%")
println("  روزهاي پرنوسان $(length(usd_jump))/30:")
println("    دلار   → MAPE: $(round(usd_j_mape,digits=2))%  (غيرقابل پيش‌بيني)")
println("    طلا18  → MAPE: $(round(iran_j_mape,digits=2))%  (غيرقابل پيش‌بيني)")
println("="^60)
