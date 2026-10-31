content = read("src/predictor.jl", String)
lines = split(content, "\n")
out = String[]

for line in lines
    s = String(line)
    
    # حذف هر println که ساختار مشکوک دارد
    if occursin("println", s)
        # اگر بعد از println کاراکتر >= 0x80 و <= 0xFF باشد
        in_string = false
        has_high_latin = false
        
        for (i, ch) in enumerate(s)
            code = Int(ch)
            if ch == '"'
                in_string = !in_string
            end
            if in_string && 0x80 <= code <= 0xFF
                has_high_latin = true
                break
            end
        end
        
        if has_high_latin
            push!(out, "    # [console log - persian text removed]")
            continue
        end
    end
    
    push!(out, s)
end

write("src/predictor.jl", join(out, "\n"))
println("done. lines processed: ", length(lines))
