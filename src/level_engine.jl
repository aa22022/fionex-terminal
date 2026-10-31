module LevelEngine

using Statistics, Dates

export KeyLevels, PriceLevel, compute_key_levels

# ============================================================
# Data Types
# ============================================================

struct PriceLevel
    price::Float64
    level_type::String        # support/resistance/pivot/fib/round/swing
    source::String            # "S1", "R1", "Fib 61.8%", "PP", "H1", ...
    strength::Float64         # 0-1 (چقدر مهم است)
    touches::Int              # چند بار تست شده
    distance_pct::Float64     # فاصله از قیمت فعلی (%)
end

struct KeyLevels
    symbol::String
    current::Float64
    atr_daily::Float64
    atr_pct::Float64

    # Grouped levels (تمام سطوح تفکیک شده)
    all_supports::Vector{PriceLevel}
    all_resistances::Vector{PriceLevel}

    # Main summary levels
    support1::Float64
    support2::Float64
    support3::Float64
    resistance1::Float64
    resistance2::Float64
    resistance3::Float64

    # Special levels
    pivot::Float64
    day_high::Float64
    day_low::Float64
    week_high::Float64
    week_low::Float64

    # Nearest & positioning
    nearest_support::Float64
    nearest_resistance::Float64
    dist_to_support::Float64      # %
    dist_to_resistance::Float64   # %
    position_in_range::Float64    # 0-1

    # Breakout & risk
    breakout_level_up::Float64
    breakout_level_dn::Float64
    stop_zone_long::Float64
    stop_zone_short::Float64

    # Confluence zones (سطوحی که چند نوع سطح در ناحیه‌شان است)
    confluence_zones::Vector{Dict{String,Any}}
end

# ============================================================
# Basic Helpers
# ============================================================

function calc_atr(prices::Vector{Float64}, period::Int=14)
    n = length(prices)
    n < period+1 && return std(prices) * 0.01
    ranges = [abs(prices[i]-prices[i-1]) for i in max(2, n-period):n]
    isempty(ranges) ? 0.001 : mean(ranges)
end

# ============================================================
# 1) Swing Detection (Quality-Weighted)
# ============================================================

function detect_swings(prices::Vector{Float64}, window::Int=3)
    n = length(prices)
    highs = Tuple{Int, Float64, Int}[]  # (index, price, strength)
    lows  = Tuple{Int, Float64, Int}[]

    for i in (window+1):(n-window)
        left  = prices[i-window:i-1]
        right = prices[i+1:i+window]

        # Swing High
        if prices[i] >= maximum(left) && prices[i] >= maximum(right)
            # Strength = چقدر از اطراف بزرگتره
            strength = round(Int, min((prices[i] - max(maximum(left), maximum(right))) / prices[i] * 10000))
            push!(highs, (i, prices[i], max(1, strength)))
        end

        # Swing Low
        if prices[i] <= minimum(left) && prices[i] <= minimum(right)
            strength = round(Int, min((min(minimum(left), minimum(right)) - prices[i]) / prices[i] * 10000))
            push!(lows, (i, prices[i], max(1, strength)))
        end
    end

    return highs, lows
end

# ============================================================
# 2) Fibonacci Retracements
# ============================================================

function compute_fibonacci(prices::Vector{Float64}, lookback::Int=50)
    n = length(prices)
    lb = min(lookback, n)
    slice = prices[end-lb+1:end]

    swing_high = maximum(slice)
    swing_low = minimum(slice)
    range = swing_high - swing_low
    range < 1e-10 && return PriceLevel[]

    # Determine trend direction (last leg)
    is_uptrend = prices[end] > mean(slice)

    levels = PriceLevel[]
    fib_ratios = [(0.236, "23.6%"), (0.382, "38.2%"), (0.5, "50.0%"),
                  (0.618, "61.8%"), (0.786, "78.6%")]

    for (ratio, label) in fib_ratios
        if is_uptrend
            # Retracements from swing high
            fib_price = swing_high - range * ratio
            level_type = fib_price < prices[end] ? "support" : "resistance"
        else
            fib_price = swing_low + range * ratio
            level_type = fib_price < prices[end] ? "support" : "resistance"
        end

        dist = (fib_price - prices[end]) / prices[end] * 100
        # Fib 50% و 61.8% مهم‌ترین‌اند
        strength = ratio == 0.618 ? 0.85 : ratio == 0.5 ? 0.75 : ratio == 0.382 ? 0.65 : 0.5

        push!(levels, PriceLevel(
            fib_price, level_type, "Fib $label", strength, 0, round(dist, digits=3)
        ))
    end

    return levels
end

# ============================================================
# 3) Pivot Points (Classic)
# ============================================================

function compute_pivots_classic(high::Float64, low::Float64, close::Float64)
    pp = (high + low + close) / 3
    r1 = 2*pp - low
    s1 = 2*pp - high
    r2 = pp + (high - low)
    s2 = pp - (high - low)
    r3 = high + 2*(pp - low)
    s3 = low - 2*(high - pp)

    return Dict("PP" => pp, "R1" => r1, "R2" => r2, "R3" => r3,
                "S1" => s1, "S2" => s2, "S3" => s3)
end

function compute_pivots_camarilla(high::Float64, low::Float64, close::Float64)
    range = high - low
    return Dict(
        "H4" => close + range * 1.1 / 2,
        "H3" => close + range * 1.1 / 4,
        "L3" => close - range * 1.1 / 4,
        "L4" => close - range * 1.1 / 2
    )
end

# ============================================================
# 4) Round Numbers
# ============================================================

function find_round_numbers(current::Float64, atr::Float64)
    levels = Float64[]

    # Detect scale
    scale = if current > 100
        # مثلا USDJPY (150.25)
        1.0
    elseif current > 10
        0.5
    elseif current > 1
        # EURUSD (1.0850)
        0.005
    else
        0.001
    end

    # Round to nearest scale
    base = round(current / scale) * scale

    # 4 levels up, 4 down
    for i in -4:4
        i == 0 && continue
        level = base + i * scale
        push!(levels, level)
    end

    return levels
end

# ============================================================
# 5) Level Strength Scoring (Touch Count)
# ============================================================

function count_touches(prices::Vector{Float64}, level::Float64; tolerance::Float64=0.002)
    tol_price = level * tolerance
    touches = 0
    in_zone = false

    for p in prices
        if abs(p - level) < tol_price
            if !in_zone
                touches += 1
                in_zone = true
            end
        else
            in_zone = false
        end
    end

    return touches
end

# ============================================================
# 6) Merge Nearby Levels
# ============================================================

function merge_levels(levels::Vector{PriceLevel}, tolerance::Float64=0.002)
    isempty(levels) && return levels
    sorted = sort(levels, by=l -> l.price)

    merged = PriceLevel[]
    current_group = [sorted[1]]

    for i in 2:length(sorted)
        prev = current_group[end]
        curr = sorted[i]

        if abs(curr.price - prev.price) / max(prev.price, 1e-10) < tolerance
            push!(current_group, curr)
        else
            # Merge current group
            avg_price = mean([l.price for l in current_group])
            total_strength = min(1.0, sum([l.strength for l in current_group]) * 0.7)
            total_touches = sum([l.touches for l in current_group])
            sources = join(unique([l.source for l in current_group]), " + ")

            push!(merged, PriceLevel(
                avg_price, current_group[1].level_type, sources,
                total_strength, total_touches, current_group[1].distance_pct
            ))

            current_group = [curr]
        end
    end

    # Last group
    if !isempty(current_group)
        avg_price = mean([l.price for l in current_group])
        total_strength = min(1.0, sum([l.strength for l in current_group]) * 0.7)
        total_touches = sum([l.touches for l in current_group])
        sources = join(unique([l.source for l in current_group]), " + ")

        push!(merged, PriceLevel(
            avg_price, current_group[1].level_type, sources,
            total_strength, total_touches, current_group[1].distance_pct
        ))
    end

    return merged
end

# ============================================================
# 7) Confluence Detection
# ============================================================

function find_confluence_zones(all_levels::Vector{PriceLevel}, current::Float64;
                               zone_size::Float64=0.005)
    zones = Dict{String,Any}[]
    used = Set{Int}()

    for i in 1:length(all_levels)
        i in used && continue
        base = all_levels[i]
        group = [base]

        for j in (i+1):length(all_levels)
            j in used && continue
            if abs(all_levels[j].price - base.price) / max(base.price, 1e-10) < zone_size
                push!(group, all_levels[j])
                push!(used, j)
            end
        end

        if length(group) >= 2  # حداقل 2 نوع سطح
            push!(used, i)
            avg_price = mean([l.price for l in group])
            sources = [l.source for l in group]
            total_strength = min(1.0, sum([l.strength for l in group]) * 0.5)

            push!(zones, Dict{String,Any}(
                "price" => round(avg_price, digits=5),
                "types" => sources,
                "count" => length(group),
                "strength" => round(total_strength, digits=3),
                "dist_pct" => round((avg_price - current) / current * 100, digits=3),
                "is_support" => avg_price < current
            ))
        end
    end

    return sort(zones, by=z -> abs(z["dist_pct"]))
end

# ============================================================
# MAIN COMPUTATION
# ============================================================

function compute_key_levels(
    symbol::String,
    prices::Vector{Float64};
    lookbacks::Vector{Int} = [10, 20, 50]
)
    n = length(prices)
    cur = last(prices)
    atr = calc_atr(prices, min(14, n-1))
    atr_pct = cur > 0 ? atr / cur * 100 : 0.0

    all_levels = PriceLevel[]

    # ── 1. Rolling High/Low Levels ──
    for lb in lookbacks
        lb = min(lb, n)
        sl = prices[end-lb+1:end]
        rh = maximum(sl)
        rl = minimum(sl)

        dist_h = (rh - cur) / cur * 100
        dist_l = (cur - rl) / cur * 100

        if rh > cur * 1.0001
            touches = count_touches(prices, rh; tolerance=0.003)
            push!(all_levels, PriceLevel(
                rh, "resistance", "High $(lb)d", 0.6, touches, round(dist_h, digits=3)
            ))
        end
        if rl < cur * 0.9999
            touches = count_touches(prices, rl; tolerance=0.003)
            push!(all_levels, PriceLevel(
                rl, "support", "Low $(lb)d", 0.6, touches, round(dist_l, digits=3)
            ))
        end
    end

    # ── 2. Swing Levels ──
    if n >= 15
        recent = prices[end-min(80,n)+1:end]
        swing_highs, swing_lows = detect_swings(recent, 3)

        for (_, price, strength_int) in swing_highs
            price > cur * 1.0001 || continue
            touches = count_touches(prices, price; tolerance=0.003)
            base_strength = min(0.9, 0.4 + strength_int * 0.02)
            push!(all_levels, PriceLevel(
                price, "resistance", "Swing High", base_strength, touches,
                round((price - cur) / cur * 100, digits=3)
            ))
        end
        for (_, price, strength_int) in swing_lows
            price < cur * 0.9999 || continue
            touches = count_touches(prices, price; tolerance=0.003)
            base_strength = min(0.9, 0.4 + strength_int * 0.02)
            push!(all_levels, PriceLevel(
                price, "support", "Swing Low", base_strength, touches,
                round((cur - price) / cur * 100, digits=3)
            ))
        end
    end

    # ── 3. Fibonacci ──
    for level in compute_fibonacci(prices, min(60, n))
        push!(all_levels, level)
    end

    # ── 4. Pivots ──
    if n >= 5
        h = maximum(prices[end-4:end-1])
        l = minimum(prices[end-4:end-1])
        c = prices[end-1]
        pivots = compute_pivots_classic(h, l, c)

        for (label, price) in pivots
            level_type = price > cur ? "resistance" : (price < cur ? "support" : "pivot")
            strength = label == "PP" ? 0.7 : startswith(label, "S1") || startswith(label, "R1") ? 0.65 : 0.5
            dist = (price - cur) / cur * 100
            push!(all_levels, PriceLevel(
                price, level_type, "Pivot $label", strength, 0, round(dist, digits=3)
            ))
        end
    end

    # ── 5. Round Numbers ──
    for rn in find_round_numbers(cur, atr)
        level_type = rn > cur ? "resistance" : "support"
        dist = (rn - cur) / cur * 100
        push!(all_levels, PriceLevel(
            rn, level_type, "Round Number", 0.4, 0, round(dist, digits=3)
        ))
    end

    # ── 6. MA Levels ──
    for w in [20, 50, 100]
        if n >= w
            ma = mean(prices[end-w+1:end])
            level_type = ma > cur ? "resistance" : "support"
            dist = (ma - cur) / cur * 100
            strength = w == 50 ? 0.7 : w == 20 ? 0.5 : 0.55
            push!(all_levels, PriceLevel(
                ma, level_type, "MA$w", strength, 0, round(dist, digits=3)
            ))
        end
    end

    # ── 7. ATR Bands ──
    if n >= 20
        ma20 = mean(prices[end-19:end])
        push!(all_levels, PriceLevel(
            ma20 + 1.5*atr, "resistance", "ATR+1.5σ", 0.45, 0,
            round((ma20 + 1.5*atr - cur) / cur * 100, digits=3)
        ))
        push!(all_levels, PriceLevel(
            ma20 - 1.5*atr, "support", "ATR-1.5σ", 0.45, 0,
            round((cur - (ma20 - 1.5*atr)) / cur * 100, digits=3)
        ))
    end

    # ── Split & Merge ──
    supports = filter(l -> l.price < cur * 0.9999, all_levels)
    resistances = filter(l -> l.price > cur * 1.0001, all_levels)

    supports = merge_levels(supports, 0.002)
    resistances = merge_levels(resistances, 0.002)

    # Sort by importance (distance-weighted strength)
    sort!(supports, by=l -> -l.strength - l.touches * 0.1 + abs(l.distance_pct) * 0.05)
    sort!(resistances, by=l -> -l.strength - l.touches * 0.1 + abs(l.distance_pct) * 0.05)

    # Extract main levels
    function get_or_default(lst, idx, default_price, is_res)
        idx > length(lst) && return default_price
        return lst[idx].price
    end

    s1 = get_or_default(supports, 1, cur * 0.995, false)
    s2 = get_or_default(supports, 2, cur * 0.985, false)
    s3 = get_or_default(supports, 3, cur * 0.975, false)
    r1 = get_or_default(resistances, 1, cur * 1.005, true)
    r2 = get_or_default(resistances, 2, cur * 1.015, true)
    r3 = get_or_default(resistances, 3, cur * 1.025, true)

    # Pivot
    pivot_val = if n >= 5
        h = maximum(prices[end-4:end-1])
        l = minimum(prices[end-4:end-1])
        c = prices[end-1]
        (h + l + c) / 3
    else
        cur
    end

    # Day/Week High-Low
    day_high = n >= 1  ? prices[end] : cur
    day_low  = n >= 1  ? prices[end] : cur
    week_high = n >= 5 ? maximum(prices[end-min(4,n-1):end]) : cur
    week_low  = n >= 5 ? minimum(prices[end-min(4,n-1):end]) : cur

    dist_r = (r1 - cur) / cur * 100
    dist_s = (cur - s1) / cur * 100
    range_sz = r1 - s1
    pos_in_range = range_sz > 0 ? (cur - s1) / range_sz : 0.5

    bo_up = r1 + atr * 0.3
    bo_dn = s1 - atr * 0.3
    stop_long = s1 - atr * 0.5
    stop_short = r1 + atr * 0.5

    # Confluence
    confluence = find_confluence_zones(vcat(supports, resistances), cur; zone_size=0.005)

    return KeyLevels(
        symbol, round(cur, digits=5),
        round(atr, digits=5), round(atr_pct, digits=3),

        supports[1:min(10, length(supports))],
        resistances[1:min(10, length(resistances))],

        round(s1, digits=5), round(s2, digits=5), round(s3, digits=5),
        round(r1, digits=5), round(r2, digits=5), round(r3, digits=5),

        round(pivot_val, digits=5),
        round(day_high, digits=5), round(day_low, digits=5),
        round(week_high, digits=5), round(week_low, digits=5),

        round(s1, digits=5), round(r1, digits=5),
        round(dist_s, digits=3), round(dist_r, digits=3),
        round(pos_in_range, digits=3),

        round(bo_up, digits=5), round(bo_dn, digits=5),
        round(stop_long, digits=5), round(stop_short, digits=5),

        confluence
    )
end

end
