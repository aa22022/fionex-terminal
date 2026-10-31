function suspicious_score(s::String)
    score = 0
    for ch in s
        if ch in ['Ã','Ø','Ù','Â','â','€','™','œ','ž','¢']
            score += 3
        elseif 0x0600 <= Int(ch) <= 0x06FF
            score -= 2
        end
    end
    return score
end

function fix_mojibake_line(line::String)
    # اگر اصلاً مشکوک نیست، دست نزن
    suspicious = occursin("Ã", line) || occursin("Ø", line) || occursin("Ù", line) ||
                 occursin("Â", line) || occursin("â", line)
    if !suspicious
        return line, false
    end

    # فقط اگر همه کاراکترها <= 255 باشند، می‌توانیم bytewise برگردانیم
    bytes = UInt8[]
    for ch in line
        v = Int(ch)
        if v > 255
            return line, false
        end
        push!(bytes, UInt8(v))
    end

    try
        fixed = String(bytes)
        # اگر نسخه جدید مشکوک‌تر نبود، جایگزین کن
        if suspicious_score(fixed) < suspicious_score(line)
            return fixed, true
        else
            return line, false
        end
    catch
        return line, false
    end
end

function fix_file(path::String)
    if !isfile(path)
        println("SKIP: $path")
        return
    end

    raw = read(path, String)
    lines = split(raw, '\n')
    fixed_count = 0
    out = String[]

    for line in lines
        fixed_line, changed = fix_mojibake_line(line)
        push!(out, fixed_line)
        fixed_count += changed ? 1 : 0
    end

    backup = path * ".bak_encoding"
    write(backup, raw)
    write(path, join(out, "\n"))

    println("FIXED: $path | changed lines = $fixed_count | backup = $backup")
end

files = [
    "src/main.jl",
    "src/web_server.jl",
    "src/predictor.jl",
    "src/news_sentiment.jl",
    "src/data_fetcher.jl",
    "src/macro_data.jl",
    "templates/index.html",
    "static/style.css"
]

println("=== شروع تعمیر encoding ===")
for f in files
    fix_file(f)
end
println("=== پایان تعمیر encoding ===")
