# فيكس تمام فايل‌هاي src كه println خراب دارند

for fname in ["src/predictor.jl", "src/web_server.jl", "src/news_sentiment.jl"]
    if !isfile(fname)
        continue
    end
    
    content = read(fname, String)
    lines = split(content, '\n')
    new_lines = String[]
    changed = 0
    
    for line in lines
        # بررسي كن آيا اين خط println با كاراكتر خراب دارد
        stripped = strip(line)
        has_mojibake = any(c -> UInt32(c) > 127, stripped) && startswith(stripped, "println(")
        
        if has_mojibake
            # indent را نگه دار
            indent = ""
            for c in line
                if c == ' ' || c == '\t'
                    indent *= string(c)
                else
                    break
                end
            end
            push!(new_lines, indent * "# [log cleaned]")
            changed += 1
        else
            push!(new_lines, line)
        end
    end
    
    if changed > 0
        write(fname, join(new_lines, '\n'))
        println("$fname: $changed lines cleaned")
    else
        println("$fname: no mojibake found")
    end
end

# همچنين web_server.jl هدر
content = read("src/web_server.jl", String)

# جايگزيني println هاي فارسي كه بالاي فايل هستند (عناوين سرور)
for bad_pattern in [
    r"println\(\"\\n\" \* \"=\"\^55\)",
    r"println\(\"  [^\"]*\"\)  # header"
]
end

# اضافه كردن لاگ‌هاي تميز ASCII
# پيدا كن start_server و لاگ‌هاي اوليه آن
if !occursin("Gold Forecast System", content)
    content = replace(content, 
        "function start_server(port::Int=8080)" =>
        """function start_server(port::Int=8080)""")
end

write("src/web_server.jl", content)
println("web_server.jl: header check done")
