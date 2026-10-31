module DataFetcher

using Dates, Statistics, JSON3, SQLite, DBInterface, HTTP

export fetch_all_data, fetch_upcoming_events, fetch_live_forex_rates, CurrencyData

struct CurrencyData
    symbol::String
    name_fa::String
    prices::Vector{Float64}
    dates::Vector{DateTime}
    latest::Float64
    change_pct::Float64
end

const BROWSER_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
const DB_PATH = joinpath(@__DIR__, "..", "data", "forecast.db")
const TROY_GRAM = 31.1034768

# ==================================================================
# دریافت خام URL
# ==================================================================
function fetch_raw_url(url::String; timeout::Int=8)::Union{String, Nothing}
    try
        cmd = `curl.exe -4 -s -L -k --connect-timeout $timeout --max-time $(timeout + 5) -H "User-Agent: $BROWSER_UA" -H "Accept: application/json, text/html, */*" $url`
        out = read(cmd, String)
        if length(out) > 50
            return out
        end
    catch
    end
    return nothing
end

# ==================================================================
# 🎯 تابع اصلی: دریافت کل داده‌ها از TGJU JSON API
# ==================================================================
function fetch_tgju_api()::Dict{String, Any}
    result = Dict{String, Any}()
    
    urls = [
        "http://call1.tgju.org/ajax.json",
        "http://call2.tgju.org/ajax.json"
    ]
    
    raw = nothing
    for url in urls
        raw = fetch_raw_url(url; timeout=10)
        raw !== nothing && break
    end
    
    raw === nothing && return result
    
    try
        j = JSON3.read(raw)
        if !haskey(j, :current)
            return result
        end
        
        current = j.current
        
        # تبدیل عدد با حذف کاما
        parse_price(s) = begin
            s_str = string(s)
            s_clean = replace(s_str, "," => "")
            v = tryparse(Float64, s_clean)
            v === nothing ? 0.0 : v
        end
        
        # استخراج یک آیتم
        function extract_item(key::Symbol)
            if !haskey(current, key)
                return nothing
            end
            item = current[key]
            return Dict{String, Any}(
                "price" => parse_price(item.p),
                "high" => haskey(item, :h) ? parse_price(item.h) : 0.0,
                "low" => haskey(item, :l) ? parse_price(item.l) : 0.0,
                "change" => haskey(item, :d) ? parse_price(item.d) : 0.0,
                "change_pct" => haskey(item, :dp) ? Float64(item.dp) : 0.0,
                "direction" => haskey(item, :dt) ? string(item.dt) : "",
                "time" => haskey(item, :ts) ? string(item.ts) : ""
            )
        end
        
        # ارزها (ریال → تومان با ÷ ۱۰)
        currencies_keys = Dict(
            "usd" => :price_dollar_rl,
            "eur" => :price_eur,
            "gbp" => :price_gbp,
            "aed" => :price_aed,
            "try" => :price_try,
            "cny" => :price_cny,
            "jpy" => :price_jpy,
            "cad" => :price_cad,
            "aud" => :price_aud,
            "chf" => :price_chf
        )
        
        result["currencies"] = Dict{String, Any}()
        for (name, key) in currencies_keys
            item = extract_item(key)
            if item !== nothing
                item["price_toman"] = item["price"] / 10.0
                item["high_toman"] = item["high"] / 10.0
                item["low_toman"] = item["low"] / 10.0
                item["change_toman"] = item["change"] / 10.0
                result["currencies"][name] = item
            end
        end
        
        # طلا و فلزات (ریال → تومان)
        metals_keys = Dict(
            "gold_18k" => :geram18,
            "gold_24k" => :geram24,
            "mesghal" => :mesghal,
            "gold_melted" => :gold_mini_size
        )
        
        result["metals"] = Dict{String, Any}()
        for (name, key) in metals_keys
            item = extract_item(key)
            if item !== nothing
                item["price_toman"] = item["price"] / 10.0
                item["high_toman"] = item["high"] / 10.0
                item["low_toman"] = item["low"] / 10.0
                item["change_toman"] = item["change"] / 10.0
                result["metals"][name] = item
            end
        end
        
        # سکه‌ها (ریال → تومان)
        coins_keys = Dict(
            "emami" => :sekee,
            "bahar" => :sekeb,
            "nim" => :nim,
            "rob" => :rob,
            "gerami" => :gerami
        )
        
        result["coins"] = Dict{String, Any}()
        for (name, key) in coins_keys
            item = extract_item(key)
            if item !== nothing
                item["price_toman"] = item["price"] / 10.0
                item["high_toman"] = item["high"] / 10.0
                item["low_toman"] = item["low"] / 10.0
                item["change_toman"] = item["change"] / 10.0
                result["coins"][name] = item
            end
        end
        
        # انس طلا (دلار - بدون تبدیل)
        ons = extract_item(:ons)
        if ons !== nothing
            result["gold_oz"] = ons
        end
        
    catch e
        @warn "خطا در پارس JSON TGJU" exception=e
    end
    
    return result
end

# ==================================================================
# دریافت نرخ‌های زنده فارکس (برای نمودارها)
# ==================================================================
function fetch_live_forex_rates()::Dict{String, Float64}
    rates = Dict{String, Float64}("USD" => 1.0)
    raw = fetch_raw_url("https://api.frankfurter.app/latest?from=USD&to=EUR,GBP,JPY,CHF,CAD,AUD,NZD,CNY,TRY"; timeout=8)
    raw === nothing && return rates
    try
        j = JSON3.read(raw)
        if haskey(j, :rates)
            for (k, v) in pairs(j.rates)
                sym = uppercase(string(k))
                val = tryparse(Float64, string(v))
                if val !== nothing && val > 0.0
                    rates[sym] = val
                end
            end
        end
    catch
    end
    return rates
end

# ==================================================================
# بازیابی آخرین قیمت‌های معتبر دیتابیس
# ==================================================================
function get_last_snapshot_prices()::Dict{String, Float64}
    res = Dict{String, Float64}("gold_oz" => 0.0, "usd_irr" => 0.0, "iran_gold" => 0.0)
    try
        if isfile(DB_PATH)
            db = SQLite.DB(DB_PATH)
            rows = DBInterface.execute(db, "SELECT gold_oz, usd_irr, iran_gold FROM snapshots WHERE gold_oz > 100 AND usd_irr > 1000 ORDER BY id DESC LIMIT 1")
            if !isnothing(rows) && !isempty(rows)
                r = first(rows)
                g = tryparse(Float64, string(r.gold_oz))
                u = tryparse(Float64, string(r.usd_irr))
                i = tryparse(Float64, string(r.iran_gold))
                g !== nothing && g > 0.0 && (res["gold_oz"] = g)
                u !== nothing && u > 0.0 && (res["usd_irr"] = u)
                i !== nothing && i > 0.0 && (res["iran_gold"] = i)
            end
        end
    catch
    end
    return res
end

# ==================================================================
# تاریخچه UDF نوبیتکس (برای نمودارها)
# ==================================================================
function fetch_crypto_udf_history(symbol::String, days::Int, current_time::DateTime)::Tuple{Vector{Float64}, Vector{DateTime}}
    prices = Float64[]
    dates = DateTime[]
    to_ts = Int(round(datetime2unix(current_time)))
    from_ts = Int(round(datetime2unix(current_time - Day(days + 15))))

    urls = [
        "https://apiv2.nobitex.ir/market/udf/history?symbol=$symbol&resolution=D&from=$from_ts&to=$to_ts",
        "https://api.nobitex.ir/market/udf/history?symbol=$symbol&resolution=D&from=$from_ts&to=$to_ts"
    ]

    for url in urls
        raw_nobi = fetch_raw_url(url; timeout=7)
        raw_nobi === nothing && continue
        try
            j = JSON3.read(raw_nobi)
            if haskey(j, :s) && j.s == "ok" && haskey(j, :c) && haskey(j, :t)
                for i in 1:length(j.c)
                    p = tryparse(Float64, string(j.c[i]))
                    p !== nothing && p > 0.0 && push!(prices, p)
                    push!(dates, unix2datetime(Float64(j.t[i])))
                end
                length(prices) > 2 && return prices, dates
            end
        catch
        end
    end
    return prices, dates
end

# ==================================================================
# همگام‌سازی زمانی
# ==================================================================
function align_series_to_dates(
    source_prices::Vector{Float64},
    source_dates::Vector{DateTime},
    target_dates::Vector{DateTime},
    anchor_price::Float64
)::Vector{Float64}
    n = length(target_dates)
    n == 0 && return Float64[]

    if isempty(source_prices) || all(x -> x <= 0.0, source_prices)
        anchor = anchor_price > 0.0 ? anchor_price : 1.0
        return fill(anchor, n)
    end

    aligned = Float64[]
    for t_dt in target_dates
        idx = findlast(d -> d <= t_dt, source_dates)
        if idx !== nothing
            push!(aligned, source_prices[idx])
        else
            push!(aligned, source_prices[1])
        end
    end

    for i in 1:length(aligned)
        if aligned[i] <= 0.0
            aligned[i] = (i > 1 ? aligned[i-1] : (anchor_price > 0.0 ? anchor_price : 1.0))
        end
    end
    return aligned
end

# ==================================================================
# تجمیع نهایی
# ==================================================================
function fetch_all_data(history_days::Int=180)
    days = clamp(history_days, 60, 365)
    current_time = now()

    # 🎯 دریافت از JSON API
    tgju = fetch_tgju_api()

    # استخراج قیمت‌های اصلی
    currencies = get(tgju, "currencies", Dict{String, Any}())
    metals = get(tgju, "metals", Dict{String, Any}())
    coins = get(tgju, "coins", Dict{String, Any}())
    gold_oz_data = get(tgju, "gold_oz", nothing)

    usd_toman = haskey(currencies, "usd") ? currencies["usd"]["price_toman"] : 0.0
    gold_18_toman = haskey(metals, "gold_18k") ? metals["gold_18k"]["price_toman"] : 0.0
    gold_oz_usd = gold_oz_data !== nothing ? gold_oz_data["price"] : 0.0
    coin_emami = haskey(coins, "emami") ? coins["emami"]["price_toman"] : 0.0

    # Fallback به Nobitex در صورت عدم دسترسی TGJU
    if usd_toman <= 0.0 || gold_oz_usd <= 0.0
        try
            nobi_raw = fetch_raw_url("https://apiv2.nobitex.ir/market/stats"; timeout=6)
            if nobi_raw !== nothing
                nj = JSON3.read(nobi_raw)
                if haskey(nj, :stats)
                    if usd_toman <= 0.0 && haskey(nj.stats, :"usdt-rls")
                        usd_toman = tryparse(Float64, string(nj.stats[:"usdt-rls"].latest)) / 10.0
                    end
                    if gold_oz_usd <= 0.0 && haskey(nj.stats, :"paxg-usdt")
                        gold_oz_usd = tryparse(Float64, string(nj.stats[:"paxg-usdt"].latest))
                    end
                end
            end
        catch
        end
    end

    # Fallback نهایی به دیتابیس
    db_backup = get_last_snapshot_prices()
    if usd_toman <= 0.0 && db_backup["usd_irr"] > 0.0
        usd_toman = db_backup["usd_irr"]
    end
    if gold_oz_usd <= 0.0 && db_backup["gold_oz"] > 0.0
        gold_oz_usd = db_backup["gold_oz"]
    end
    if gold_18_toman <= 0.0 && db_backup["iran_gold"] > 0.0
        gold_18_toman = db_backup["iran_gold"]
    end

    # تاریخچه‌ها (فقط برای نمودارها)
    raw_usd_p, raw_usd_d = fetch_crypto_udf_history("USDTIRT", days, current_time)
    raw_gold_p, raw_gold_d = fetch_crypto_udf_history("PAXGUSDT", days, current_time)

    base_dates = if !isempty(raw_gold_d)
        raw_gold_d
    elseif !isempty(raw_usd_d)
        raw_usd_d
    else
        [DateTime(current_time - Day(days - i)) for i in 1:days]
    end

    gold_prices = align_series_to_dates(raw_gold_p, raw_gold_d, base_dates, gold_oz_usd)
    if gold_oz_usd > 0.0 && !isempty(gold_prices); gold_prices[end] = gold_oz_usd; end

    usd_prices = align_series_to_dates(raw_usd_p, raw_usd_d, base_dates, usd_toman)
    if usd_toman > 0.0 && !isempty(usd_prices); usd_prices[end] = usd_toman; end

    # طلای ۱۸ عیار تاریخچه از فرمول
    iran_prices = Float64[]
    for i in 1:length(base_dates)
        push!(iran_prices, (gold_prices[i] / TROY_GRAM) * 0.75 * usd_prices[i] * 1.012)
    end
    if gold_18_toman > 0.0 && !isempty(iran_prices); iran_prices[end] = gold_18_toman; end

    # فارکس
    fx_rates = fetch_live_forex_rates()
    fx_symbols = ["EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD", "CNY", "TRY"]
    names_fa = Dict(
        "EUR"=>"یورو", "GBP"=>"پوند انگلیس", "JPY"=>"ین ژاپن", "CHF"=>"فرانک سوئیس",
        "CAD"=>"دلار کانادا", "AUD"=>"دلار استرالیا", "NZD"=>"دلار نیوزیلند",
        "CNY"=>"یوان چین", "TRY"=>"لیر ترکیه"
    )

    currency_list = CurrencyData[]
    for sym in fx_symbols
        live_rate = get(fx_rates, sym, 0.0)
        c_prices = live_rate > 0.0 ? fill(live_rate, length(base_dates)) : fill(0.0, length(base_dates))
        push!(currency_list, CurrencyData(sym, get(names_fa, sym, sym), c_prices, base_dates, live_rate, 0.0))
    end

    return Dict{String, Any}(
        "gold_oz" => Dict("prices" => gold_prices, "dates" => base_dates, "provider" => "TGJU"),
        "usd_irr" => Dict("prices" => usd_prices, "dates" => base_dates, "provider" => "TGJU"),
        "iran_gold" => Dict("prices" => iran_prices, "dates" => base_dates, "provider" => "TGJU"),
        "currencies" => currency_list,
        "rates" => fx_rates,
        "tgju" => tgju  # 🎯 کل داده‌های TGJU
    )
end

function fetch_upcoming_events(days_ahead::Int=14)
    return Dict[]
end

end