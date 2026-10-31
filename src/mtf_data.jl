module MTFData

using Dates, Statistics, JSON3, HTTP

export fetch_mtf_candles, MTFCandles, get_all_timeframes

const BROWSER_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

# ------------------------------------------------------------------
# ساختار داده OHLCV چند تایم‌فریمی
# ------------------------------------------------------------------
struct MTFCandles
    symbol::String
    timeframe::String        # "H1", "H4", "D1"
    opens::Vector{Float64}
    highs::Vector{Float64}
    lows::Vector{Float64}
    closes::Vector{Float64}
    volumes::Vector{Float64}
    timestamps::Vector{DateTime}
    source::String           # منبع دریافت داده
    is_valid::Bool
end

# ------------------------------------------------------------------
# موتور دریافت خام با سوئیچ هوشمند بین curl IPv4 و PowerShell WinINet
# ------------------------------------------------------------------
function fetch_raw(url::String; timeout::Int=8)::Union{String, Nothing}
    try
        cmd = `curl.exe -4 -s -L -k --connect-timeout $timeout --max-time $(timeout + 4) -H "User-Agent: $BROWSER_UA" $url`
        out = read(cmd, String)
        if length(out) > 10 && !occursin("تعلیق دسترسی", out) && !occursin("Access denied", out)
            return out
        end
    catch
    end
    try
        ps_cmd = `powershell.exe -NoProfile -NonInteractive -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; (Invoke-WebRequest -Uri '$url' -UseBasicParsing -TimeoutSec $timeout -Headers @{'User-Agent'='$BROWSER_UA'}).Content"`
        out_ps = read(ps_cmd, String)
        if length(out_ps) > 10 && !occursin("تعلیق دسترسی", out_ps)
            return out_ps
        end
    catch
    end
    return nothing
end

# ------------------------------------------------------------------
# ۱. دریافت کندل کریپتو از Nobitex UDF با resolution قابل تنظیم
# ------------------------------------------------------------------
function fetch_crypto_mtf(symbol::String, resolution::String, days_back::Int)::MTFCandles
    empty_result = MTFCandles(symbol, resolution, Float64[], Float64[], Float64[], Float64[], Float64[], DateTime[], "Nobitex", false)
    
    current_time = now()
    to_ts = Int(round(datetime2unix(current_time)))
    from_ts = Int(round(datetime2unix(current_time - Day(days_back))))
    
    urls = [
        "https://apiv2.nobitex.ir/market/udf/history?symbol=$symbol&resolution=$resolution&from=$from_ts&to=$to_ts",
        "https://api.nobitex.ir/market/udf/history?symbol=$symbol&resolution=$resolution&from=$from_ts&to=$to_ts"
    ]
    
    tf_name = resolution == "60" ? "H1" : (resolution == "240" ? "H4" : "D1")
    
    for url in urls
        raw = fetch_raw(url; timeout=10)
        raw === nothing && continue
        try
            j = JSON3.read(raw)
            if haskey(j, :s) && j.s == "ok" && haskey(j, :c) && haskey(j, :t)
                opens = Float64[]
                highs = Float64[]
                lows = Float64[]
                closes = Float64[]
                volumes = Float64[]
                timestamps = DateTime[]
                
                for i in 1:length(j.c)
                    o = tryparse(Float64, string(j.o[i]))
                    h = tryparse(Float64, string(j.h[i]))
                    l = tryparse(Float64, string(j.l[i]))
                    c = tryparse(Float64, string(j.c[i]))
                    v = haskey(j, :v) ? tryparse(Float64, string(j.v[i])) : 1000.0
                    
                    if o !== nothing && h !== nothing && l !== nothing && c !== nothing && c > 0.0
                        push!(opens, o)
                        push!(highs, h)
                        push!(lows, l)
                        push!(closes, c)
                        push!(volumes, v === nothing ? 1000.0 : v)
                        push!(timestamps, unix2datetime(Float64(j.t[i])))
                    end
                end
                
                if length(closes) > 5
                    return MTFCandles(symbol, tf_name, opens, highs, lows, closes, volumes, timestamps, "Nobitex", true)
                end
            end
        catch
        end
    end
    return empty_result
end

# ------------------------------------------------------------------
# ۲. دریافت کندل فارکس از Stooq CSV (فوق‌العاده سریع و پایدار)
# ------------------------------------------------------------------
function fetch_forex_stooq(symbol::String, interval::String)::MTFCandles
    empty_result = MTFCandles(symbol, interval, Float64[], Float64[], Float64[], Float64[], Float64[], DateTime[], "Stooq", false)
    
    # تبدیل interval به فرمت Stooq: d=daily, h=hourly
    stooq_interval = interval == "H1" ? "h" : (interval == "H4" ? "h" : "d")
    sym_lower = lowercase(symbol)
    
    url = "https://stooq.com/q/d/l/?s=$sym_lower&i=$stooq_interval"
    raw = fetch_raw(url; timeout=10)
    raw === nothing && return empty_result
    
    try
        lines = split(raw, "\n")
        opens = Float64[]
        highs = Float64[]
        lows = Float64[]
        closes = Float64[]
        volumes = Float64[]
        timestamps = DateTime[]
        
        for line in lines
            line_str = strip(line)
            isempty(line_str) && continue
            startswith(line_str, "Date") && continue  # اسکیپ هدر
            
            parts = split(line_str, ",")
            length(parts) < 5 && continue
            
            try
                dt_str = String(parts[1])
                # فرمت‌های احتمالی: "2024-01-15" یا "2024-01-15 14:00:00"
                dt = if occursin(" ", dt_str)
                    DateTime(dt_str, dateformat"yyyy-mm-dd HH:MM:SS")
                else
                    DateTime(Date(dt_str))
                end
                
                o = tryparse(Float64, String(parts[2]))
                h = tryparse(Float64, String(parts[3]))
                l = tryparse(Float64, String(parts[4]))
                c = tryparse(Float64, String(parts[5]))
                v = length(parts) >= 6 ? tryparse(Float64, String(parts[6])) : 1000.0
                
                if o !== nothing && h !== nothing && l !== nothing && c !== nothing && c > 0.0
                    push!(opens, o)
                    push!(highs, h)
                    push!(lows, l)
                    push!(closes, c)
                    push!(volumes, v === nothing ? 1000.0 : v)
                    push!(timestamps, dt)
                end
            catch
                continue
            end
        end
        
        # اگر H4 خواسته شد، از داده‌های H1 سمپل بگیریم
        if interval == "H4" && length(closes) > 4
            return resample_to_h4(symbol, opens, highs, lows, closes, volumes, timestamps)
        end
        
        if length(closes) > 5
            return MTFCandles(symbol, interval, opens, highs, lows, closes, volumes, timestamps, "Stooq", true)
        end
    catch
    end
    return empty_result
end

# ------------------------------------------------------------------
# ۳. تبدیل کندل H1 به H4 (Resampling)
# ------------------------------------------------------------------
function resample_to_h4(symbol::String, opens::Vector{Float64}, highs::Vector{Float64}, lows::Vector{Float64}, closes::Vector{Float64}, volumes::Vector{Float64}, timestamps::Vector{DateTime})::MTFCandles
    h4_opens = Float64[]
    h4_highs = Float64[]
    h4_lows = Float64[]
    h4_closes = Float64[]
    h4_volumes = Float64[]
    h4_times = DateTime[]
    
    n = length(closes)
    for i in 1:4:n
        end_idx = min(i + 3, n)
        push!(h4_opens, opens[i])
        push!(h4_highs, maximum(highs[i:end_idx]))
        push!(h4_lows, minimum(lows[i:end_idx]))
        push!(h4_closes, closes[end_idx])
        push!(h4_volumes, sum(volumes[i:end_idx]))
        push!(h4_times, timestamps[i])
    end
    
    return MTFCandles(symbol, "H4", h4_opens, h4_highs, h4_lows, h4_closes, h4_volumes, h4_times, "Stooq-Resampled", length(h4_closes) > 5)
end

# ------------------------------------------------------------------
# ۴. دریافت کندل از Yahoo Finance (پشتیبان قدرتمند)
# ------------------------------------------------------------------
function fetch_yahoo_chart(yahoo_symbol::String, interval::String, range_str::String)::MTFCandles
    empty_result = MTFCandles(yahoo_symbol, interval, Float64[], Float64[], Float64[], Float64[], Float64[], DateTime[], "Yahoo", false)
    
    yahoo_int = interval == "H1" ? "1h" : (interval == "H4" ? "1h" : "1d")
    url = "https://query1.finance.yahoo.com/v8/finance/chart/$yahoo_symbol?interval=$yahoo_int&range=$range_str"
    
    raw = fetch_raw(url; timeout=10)
    raw === nothing && return empty_result
    
    try
        j = JSON3.read(raw)
        if haskey(j, :chart) && haskey(j.chart, :result) && !isempty(j.chart.result)
            result = j.chart.result[1]
            ts_array = result.timestamp
            quote_data = result.indicators.quote[1]
            
            opens = Float64[]
            highs = Float64[]
            lows = Float64[]
            closes = Float64[]
            volumes = Float64[]
            timestamps = DateTime[]
            
            for i in 1:length(ts_array)
                o_raw = quote_data.open[i]
                h_raw = quote_data.high[i]
                l_raw = quote_data.low[i]
                c_raw = quote_data.close[i]
                v_raw = haskey(quote_data, :volume) ? quote_data.volume[i] : 1000.0
                
                if o_raw !== nothing && c_raw !== nothing
                    o = Float64(o_raw)
                    h = h_raw === nothing ? o : Float64(h_raw)
                    l = l_raw === nothing ? o : Float64(l_raw)
                    c = Float64(c_raw)
                    v = v_raw === nothing ? 1000.0 : Float64(v_raw)
                    
                    if c > 0.0
                        push!(opens, o)
                        push!(highs, h)
                        push!(lows, l)
                        push!(closes, c)
                        push!(volumes, v)
                        push!(timestamps, unix2datetime(Float64(ts_array[i])))
                    end
                end
            end
            
            # ریسمپل به H4 در صورت لزوم
            if interval == "H4" && length(closes) > 4
                return resample_to_h4(yahoo_symbol, opens, highs, lows, closes, volumes, timestamps)
            end
            
            if length(closes) > 5
                return MTFCandles(yahoo_symbol, interval, opens, highs, lows, closes, volumes, timestamps, "Yahoo", true)
            end
        end
    catch
    end
    return empty_result
end

# ------------------------------------------------------------------
# ۵. تابع اصلی: دریافت هر ۳ تایم‌فریم برای هر نماد
# ------------------------------------------------------------------
function fetch_mtf_candles(symbol::String, category::String)::Dict{String, MTFCandles}
    result = Dict{String, MTFCandles}()
    
    if category == "crypto"
        # نوبیتکس UDF با ۳ resolution
        result["H1"] = fetch_crypto_mtf(symbol, "60", 15)
        result["H4"] = fetch_crypto_mtf(symbol, "240", 45)
        result["D1"] = fetch_crypto_mtf(symbol, "D", 180)
    else
        # فارکس با اولویت Stooq → Yahoo
        h1_stooq = fetch_forex_stooq(symbol, "H1")
        result["H1"] = h1_stooq.is_valid ? h1_stooq : fetch_yahoo_chart("$symbol=X", "H1", "1mo")
        
        h4_data = fetch_forex_stooq(symbol, "H4")
        result["H4"] = h4_data.is_valid ? h4_data : fetch_yahoo_chart("$symbol=X", "H4", "3mo")
        
        d1_stooq = fetch_forex_stooq(symbol, "D1")
        result["D1"] = d1_stooq.is_valid ? d1_stooq : fetch_yahoo_chart("$symbol=X", "D1", "6mo")
    end
    
    return result
end

# ------------------------------------------------------------------
# ۶. تابع batch: دریافت MTF برای چند نماد به صورت موازی
# ------------------------------------------------------------------
function get_all_timeframes(symbols_with_category::Vector{Tuple{String, String}})::Dict{String, Dict{String, MTFCandles}}
    result = Dict{String, Dict{String, MTFCandles}}()
    for (sym, cat) in symbols_with_category
        try
            result[sym] = fetch_mtf_candles(sym, cat)
        catch e
            @warn "خطا در دریافت MTF برای $sym" exception=e
            result[sym] = Dict{String, MTFCandles}()
        end
    end
    return result
end

end