function suspicious_score(s::AbstractString)
    text = String(s)
    score = 0
    for ch in text
        if ch in ['Ã','Ø','Ù','Â','â','€','™','œ','ž','¢']
            score += 3
        elseif 0x0600 <= Int(ch) <= 0x06FF
            score -= 1
        end
    end
    return score
end

function repair_once(s::AbstractString)
    text = String(s)
    bytes = UInt8[]
    for ch in text
        v = Int(ch)
        if v > 255
            return text, false
        end
        push!(bytes, UInt8(v))
    end
    try
        return String(bytes), true
    catch
        return text, false
    end
end

function best_repair(line::AbstractString; maxpass::Int=3)
    original = String(line)
    best = original
    best_score = suspicious_score(original)

    for _ in 1:maxpass
        fixed, ok = repair_once(best)
        if !ok
            break
        end
        sc = suspicious_score(fixed)
        if sc < best_score
            best = fixed
            best_score = sc
        else
            break
        end
    end

    return best, best != original
end

function fix_file(path::String)
    if !isfile(path)
        println("SKIP: $path")
        return
    end

    raw = read(path, String)
    lines = split(raw, '\n')
    out = String[]
    changed = 0

    for line in lines
        line_str = String(line)

        suspicious = occursin("Ã", line_str) ||
                     occursin("Ø", line_str) ||
                     occursin("Ù", line_str) ||
                     occursin("Â", line_str) ||
                     occursin("â", line_str)

        if suspicious
            fixed, was_changed = best_repair(line_str; maxpass=3)
            push!(out, fixed)
            changed += was_changed ? 1 : 0
        else
            push!(out, line_str)
        end
    end

    backup = path * ".bak_encoding"
    if !isfile(backup)
        write(backup, raw)
    end

    write(path, join(out, "\n"))
    println("FIXED: $path | changed lines = $changed | backup = $backup")
end

files = [
    "src/main.jl",
    "src/web_server.jl",
    "src/predictor.jl",
    "src/news_sentiment.jl",
    "src/data_fetcher.jl",
    "src/macro_data.jl",
    "src/backtest_engine.jl",
    "templates/index.html",
    "static/style.css"
]

println("=== شروع تعمیر نهایی encoding ===")
for f in files
    fix_file(f)
end
println("=== پایان تعمیر ===")
