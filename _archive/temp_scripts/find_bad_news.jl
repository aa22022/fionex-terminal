content = read("src/news_sentiment.jl", String)
lines = split(content, "\n")
for (i, line) in enumerate(lines)
    if !startswith(strip(line), "#") && any(c -> Int(c) > 127, line)
        println("Line $i: $(strip(line))")
    end
end
