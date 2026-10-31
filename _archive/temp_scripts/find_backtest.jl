content = read("src/predictor.jl", String)

# پيدا كردن و نمايش خطوط backtest
for (i, line) in enumerate(split(content, "\n"))
    if contains(line, "backtest_model")
        println("Line $i: $(strip(line))")
    end
end
