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
        stripped = strip(line)
        if startswith(stripped, "println(")
            indent = line[1:findfirst(!=(' '), line)-1]
            push!(out, indent * "# [muted log] " * stripped)
            changed += 1
        else
            push!(out, line)
        end
    end

    write(path, join(out, "\n"))
    println("MUTED: $path | logs = $changed")
end

mute_printlns("src/predictor.jl")
mute_printlns("src/news_sentiment.jl")
