function mute_printlns(path::String)
    if !isfile(path)
        println("SKIP: $path")
        return
    end

    raw = read(path, String)
    lines = split(raw, "\n")
    out = String[]
    changed = 0

    for line in lines
        s = strip(line)
        if startswith(s, "println(")
            # indentation
            indent = ""
            for ch in line
                if ch == ' ' || ch == '\t'
                    indent *= string(ch)
                else
                    break
                end
            end
            push!(out, indent * "# [muted log] " * s)
            changed += 1
        else
            push!(out, line)
        end
    end

    write(path, join(out, "\n"))
    println("MUTED: $path | logs=$changed")
end

mute_printlns("src/news_sentiment.jl")
mute_printlns("src/backtest_engine.jl")
