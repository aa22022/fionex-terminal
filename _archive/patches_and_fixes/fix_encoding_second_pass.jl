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

function repair_once(s::String)
    bytes = UInt8[]
    for ch in s
        v = Int(ch)
        if v > 255
            return s, false
        end
        push!(bytes, UInt8(v))
    end
    try
        return String(bytes), true
    catch
        return s, false
    end
end

function repair_twice_if_needed(line::String)
    line1, ok1 = repair_once(line)
    if !ok1
        return line, false
    end

    line2, ok2 = repair_once(line1)

    best = line
    if suspicious_score(line1) < suspicious_score(best)
        best = line1
    end
    if ok2 && suspicious_score(line2) < suspicious_score(best)
        best = line2
    end

    return best, best != line
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
        suspicious = occursin("Ã", line) || occursin("Ø", line) || occursin("Ù", line) ||
                     occursin("Â", line) || occursin("â", line)
        if suspicious
            fixed, changed = repair_twice_if_needed(line)
            push!(out, fixed)
            fixed_count += changed ? 1 : 0
        else
            push!(out, line)
        end
    end

    write(path, join(out, "\n"))
    println("SECOND PASS: $path | changed lines = $fixed_count")
end

files = [
    "src/main.jl",
    "src/web_server.jl",
    "src/predictor.jl",
    "src/news_sentiment.jl",
    "templates/index.html",
    "static/style.css"
]

println("=== مرحله دوم تعمیر encoding ===")
for f in files
    fix_file(f)
end
println("=== پایان مرحله دوم ===")
