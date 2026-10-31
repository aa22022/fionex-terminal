content = read("src/predictor.jl", String)

# جایگزینی مستقیم چند لاگ مهم
content = replace(content, "println(\"    Backtest 20 روزه...\")" => "println(\"    Backtest 20d...\")")
content = replace(content, "println(\"    MAPE20: AR=$(round(mape_ar*100,digits=2))% | HW=$(round(mape_hw*100,digits=2))% | MC=$(round(mape_mc*100,digits=2))%\")" =>
                          "println(\"    MAPE20: AR=\" * string(round(mape_ar*100,digits=2)) * \"% | HW=\" * string(round(mape_hw*100,digits=2)) * \"% | MC=\" * string(round(mape_mc*100,digits=2)) * \"%\")")

# چون بعضی رشته‌ها خراب‌اند، بر اساس الگوی println کلیدی جایگزین می‌کنیم
lines = split(content, '\n')
newlines = String[]

for line in lines
    s = strip(line)

    if occursin("شروع", s) || occursin("Forecast", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    === Forecast started ===\")"))
    elseif occursin("تنظیم کلان", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    Macro adjustment computed\")"))
    elseif occursin("اجرای 6 مدل", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    Running 6 models...\")"))
    elseif occursin("وزن نهایی", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    Final ensemble weights calculated\")"))
    elseif occursin("دلار: VAR + GARCH", s) || occursin("USD model", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    USD model: VAR + GARCH\")"))
    elseif occursin("ضریب بازار", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    Market factor estimated\")"))
    elseif occursin("نتیجه نهایی", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    === Final forecast ===\")"))
    elseif occursin("انس:", s) && occursin("println", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    Gold forecast computed\")"))
    elseif occursin("طلا18:", s) && occursin("println", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    Iran gold forecast computed\")"))
    elseif occursin("حالت:", s) && occursin("println", s)
        push!(newlines, replace(line, r"println\(.*\)" => "println(\"    Forecast completed\")"))
    else
        push!(newlines, line)
    end
end

write("src/predictor.jl", join(newlines, "\n"))
println("predictor.jl console logs cleaned")
