function safe_prefix(s::AbstractString, n::Int=80)
    return join(Iterators.take(s, n))
end

for fname in ["src/web_server.jl", "src/data_fetcher.jl", "src/macro_data.jl", "src/math_engine.jl", "src/predictor.jl", "src/backtest_engine.jl", "src/news_sentiment.jl", "src/storage.jl", "templates/index.html", "static/style.css"]
    if !isfile(fname)
        println("MISSING: $fname")
        continue
    end
    content = read(fname, String)
    bad = 0
    for (i, line) in enumerate(split(content, "\n"))
        if occursin("Ã", line) || occursin("Ø", line) || occursin("Ù", line) || occursin("Â", line) || occursin("â", line)
            bad += 1
            if bad <= 3
                println("BAD $fname:$i -> " * safe_prefix(line, 80))
            end
        end
    end
    if bad == 0
        println("OK: $fname")
    else
        println("TOTAL BAD in $fname: $bad")
    end
end
