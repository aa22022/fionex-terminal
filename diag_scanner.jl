push!(LOAD_PATH, "src")
using Dates, Statistics

include("src/data_fetcher.jl")
include("src/market_registry.jl")
include("src/setup_detector.jl")

using .DataFetcher
using .MarketRegistry
using .SetupDetector

println("=====================================================")
println("       🔬 گزارش کالبدشکافی دقیق داده‌های Fionex")
println("=====================================================\n")

# ۱. دریافت داده‌های خام
println("📥 ۱. دریافت داده‌ها از data_fetcher...")
d = DataFetcher.fetch_all_data(180)

# ۲. بررسی داده‌های اصلی
gold_p = d["gold_oz"]["prices"]
usd_p  = d["usd_irr"]["prices"]
iran_p = d["iran_gold"]["prices"]

println("\n📊 ۲. بررسی طول و آخرین مقدار دارایی‌های اصلی:")
println("   → طلا (gold_oz)      : ", length(gold_p), " رکورد | آخرین: ", round(gold_p[end], digits=2), " USD")
println("   → دلار (usd_irr)     : ", length(usd_p), " رکورد | آخرین: ", round(Int, usd_p[end]), " تومان")
println("   → طلای ۱۸ (iran_gold) : ", length(iran_p), " رکورد | آخرین: ", round(Int, iran_p[end]), " تومان")

# ۳. بررسی کریپتو
btc_p = haskey(d, "btc") ? d["btc"]["prices"] : Float64[]
eth_p = haskey(d, "eth") ? d["eth"]["prices"] : Float64[]
sol_p = haskey(d, "sol") ? d["sol"]["prices"] : Float64[]

println("\n🪙 ۳. بررسی رمزارزها:")
println("   → BTC : ", length(btc_p), " رکورد | آخرین: ", (isempty(btc_p) ? "خالی" : string(round(btc_p[end], digits=2))))
println("   → ETH : ", length(eth_p), " رکورد | آخرین: ", (isempty(eth_p) ? "خالی" : string(round(eth_p[end], digits=2))))
println("   → SOL : ", length(sol_p), " رکورد | آخرین: ", (isempty(sol_p) ? "خالی" : string(round(sol_p[end], digits=2))))

# ۴. بررسی فارکس
println("\n💱 ۴. بررسی ارزهای فارکس:")
currs = d["currencies"]
for c in currs
    p_len = length(c.prices)
    last_v = isempty(c.prices) ? 0.0 : c.prices[end]
    println("   → ", c.symbol, " (", c.name_fa, ") : ", p_len, " رکورد | آخرین: ", round(last_v, digits=4))
end

# ۵. شبیه‌سازی ساخت rates_dict در وب‌سرور
println("\n🧮 ۵. بررسی تشکیل rates_dict برای اسکنر:")
rates_dict = Dict{String, Vector{Float64}}()
usd_rates = Dict{String, Vector{Float64}}()
for c in currs; usd_rates[c.symbol] = c.prices; end
usd_rates["USD"] = fill(1.0, length(gold_p))
usd_rates["USDT"] = fill(1.0, length(gold_p))
!isempty(btc_p) && (usd_rates["BTC"] = btc_p)
!isempty(eth_p) && (usd_rates["ETH"] = eth_p)
!isempty(sol_p) && (usd_rates["SOL"] = sol_p)

for pair in MarketRegistry.ALL_FX_PAIRS
    if pair.category == "crypto"
        key_lc = lowercase(pair.base)
        if haskey(d, key_lc)
            rates_dict[pair.symbol] = d[key_lc]["prices"]
        end
    elseif haskey(usd_rates, pair.base) && haskey(usd_rates, pair.quote_)
        b_prices = usd_rates[pair.base]
        q_prices = usd_rates[pair.quote_]
        n_len = min(length(b_prices), length(q_prices))
        if n_len > 0
            rates_dict[pair.symbol] = [q_prices[end-n_len+i] / b_prices[end-n_len+i] for i in 1:n_len]
        end
    end
end

println("   تعداد کل جفت‌های محاسبه‌شده در rates_dict: ", length(rates_dict), " از ", length(MarketRegistry.ALL_FX_PAIRS))
for (sym, p_arr) in rates_dict
    println("   → ", sym, " : ", length(p_arr), " کندل | آخرین قیمت: ", (isempty(p_arr) ? "خالی" : string(round(p_arr[end], digits=4))))
end

# ۶. اجرای تست اسکنر روی جفت‌ها
println("\n🎯 ۶. خروجی ستاپ‌دتکتور برای جفت‌ها:")
valid_count = 0
for (sym, p_arr) in rates_dict
    if length(p_arr) >= 5 && p_arr[end] > 0.0
        res = SetupDetector.detect_setup(sym, p_arr)
        println("   ✓ ", sym, " -> جهت: ", res.bias, " | کیفیت: ", res.trade_quality, " | R/R: ", res.risk_reward, " | تارگت: ", round(res.target1, digits=4))
        valid_count += 1
    else
        println("   ✗ ", sym, " -> غیرقابل تحلیل (قیمت صفر یا طول ناکافی)")
    end
end
println("\n   مجموع ستاپ‌های معتبر شناسایی‌شده: ", valid_count)

println("\n=====================================================")