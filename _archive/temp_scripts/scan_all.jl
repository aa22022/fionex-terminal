for fname in ["src/web_server.jl", "src/data_fetcher.jl", "src/macro_data.jl", "src/math_engine.jl", "src/predictor.jl", "src/backtest_engine.jl", "src/news_sentiment.jl", "src/storage.jl", "templates/index.html", "static/style.css"]
    if !isfile(fname)
        println("MISSING: $fname")
        continue
    end
    content = read(fname, String)
    bad = 0
    for (i, line) in enumerate(split(content, "\n"))
        if occursin("Ã", line) || occursin("Â", line)
            bad += 1
            if bad <= 2
                println("BAD $fname:$i → $(line[1:min(80,end)])")
            end
        end
    end
    if bad == 0
        println("OK: $fname")
    else
        println("TOTAL BAD in $fname: $bad lines")
    end
end
