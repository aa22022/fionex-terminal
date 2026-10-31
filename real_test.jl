# تست واقعي يك ماه گذشته
# اجرا: julia real_test.jl

include("src/data_fetcher.jl")
include("src/backtest_engine.jl")

using .DataFetcher
using .BacktestEngine
using Dates, Statistics

println("="^60)
println("  تست واقعي يك ماه گذشته")
println("="^60)
println()

# دريافت داده واقعي
println("دريافت داده‌هاي واقعي...")
data = fetch_all_data(180)

gold_prices = data["gold_oz"]["prices"]
gold_dates  = data["gold_oz"]["dates"]
usd_prices  = data["usd_irr"]["prices"]
usd_dates   = data["usd_irr"]["dates"]
iran_prices = data["iran_gold"]["prices"]
iran_dates  = data["iran_gold"]["dates"]

println("  انس: $(length(gold_prices)) روز | آخرين: $(round(last(gold_prices),digits=2)) دلار")
println("  دلار: $(length(usd_prices)) روز | آخرين: $(round(last(usd_prices),digits=0)) تومان")
println("  طلا18: $(length(iran_prices)) روز | آخرين: $(round(last(iran_prices),digits=0)) تومان")
println()

# اجراي بك‌تست 30 روز
println("اجراي بك‌تست 30 روز...")
bt = run_historical_backtest(
    gold_prices, gold_dates,
    usd_prices, usd_dates,
    iran_prices, iran_dates;
    test_days=30,
    min_train=60
)

println()
println("="^60)
println("  نتايج كلي")
println("="^60)
println("  MAPE دلار:   $(round(bt.usd_mape, digits=3))%")
println("  MAPE طلا18:  $(round(bt.iran_mape, digits=3))%")
println("  جهت دلار:    $(round(bt.usd_direction_accuracy, digits=1))%")
println("  جهت طلا18:   $(round(bt.iran_direction_accuracy, digits=1))%")
println()

# ساخت CSV
println("ساخت فايل CSV...")

usd_rows  = bt.usd_results
iran_rows = bt.iran_results

# هدر
header = "تاريخ,دلار واقعي (تومان),دلار پيش‌بيني (تومان),خطاي دلار (%),جهت دلار,طلا18 واقعي (تومان),طلا18 پيش‌بيني (تومان),خطاي طلا18 (%),جهت طلا18"

rows = String[header]

n = min(length(usd_rows), length(iran_rows))
for i in 1:n
    ur = usd_rows[i]
    ir = iran_rows[i]

    usd_dir_str  = ur.direction_correct ? "درست" : "غلط"
    iran_dir_str = ir.direction_correct ? "درست" : "غلط"

    row = "$(ur.date),$(Int(round(ur.actual))),$(Int(round(ur.predicted))),$(round(ur.error_pct,digits=3)),$(usd_dir_str),$(Int(round(ir.actual))),$(Int(round(ir.predicted))),$(round(ir.error_pct,digits=3)),$(iran_dir_str)"

    push!(rows, row)
end

# اضافه كردن ستون خلاصه
push!(rows, "")
push!(rows, "خلاصه")
push!(rows, "ميانگين خطاي دلار,$(round(bt.usd_mape,digits=3))%")
push!(rows, "ميانگين خطاي طلا18,$(round(bt.iran_mape,digits=3))%")
push!(rows, "دقت جهت دلار,$(round(bt.usd_direction_accuracy,digits=1))%")
push!(rows, "دقت جهت طلا18,$(round(bt.iran_direction_accuracy,digits=1))%")
push!(rows, "تعداد روز,$(bt.total_days)")

# ذخيره
csv_path = joinpath(pwd(), "real_test_result.csv")
open(csv_path, "w") do f
    write(f, "\ufeff")  # BOM براي اكسل فارسي
    write(f, join(rows, "\n"))
end

println()
println("فايل ذخيره شد:")
println("  $(csv_path)")
println()

# نمايش جدول در كنسول
println("="^100)
println(rpad("تاريخ", 12), " | ",
        lpad("دلار واقعي", 12), " | ",
        lpad("دلار پيش‌بيني", 14), " | ",
        lpad("خطا%", 8), " | ",
        rpad("جهت", 6), " | ",
        lpad("طلا18 واقعي", 14), " | ",
        lpad("طلا18 پيش‌بيني", 16), " | ",
        lpad("خطا%", 8), " | ",
        rpad("جهت", 6))
println("-"^100)

for i in 1:n
    ur = usd_rows[i]
    ir = iran_rows[i]
    ud = ur.direction_correct ? "✓" : "✗"
    id = ir.direction_correct ? "✓" : "✗"

    println(rpad(ur.date, 12), " | ",
            lpad(string(Int(round(ur.actual))), 12), " | ",
            lpad(string(Int(round(ur.predicted))), 14), " | ",
            lpad(string(round(ur.error_pct, digits=2))*"%", 8), " | ",
            rpad(ud, 6), " | ",
            lpad(string(Int(round(ir.actual))), 14), " | ",
            lpad(string(Int(round(ir.predicted))), 16), " | ",
            lpad(string(round(ir.error_pct, digits=2))*"%", 8), " | ",
            rpad(id, 6))
end

println("-"^100)
println(rpad("ميانگين", 12), " | ",
        lpad("", 12), " | ",
        lpad("", 14), " | ",
        lpad(string(round(bt.usd_mape,digits=2))*"%", 8), " | ",
        rpad("$(round(bt.usd_direction_accuracy,digits=0))%", 6), " | ",
        lpad("", 14), " | ",
        lpad("", 16), " | ",
        lpad(string(round(bt.iran_mape,digits=2))*"%", 8), " | ",
        rpad("$(round(bt.iran_direction_accuracy,digits=0))%", 6))
println("="^100)

println()
println("فايل CSV آماده است: real_test_result.csv")
println("براي باز كردن در اكسل:")
println("  1. فايل را در اكسل باز كنيد")
println("  2. اگر ستون‌ها جدا نشدند: Data → Text to Columns → Delimited → Comma")
