content = read("src/predictor.jl", String)

repls = Dict(
    "println(\"    Backtest 90 روزه...\")" => "println(\"    Backtest 20d...\")",
    "println(\"    MAPE20: AR=$(round(mape_ar*100,digits=2))% HW=$(round(mape_hw*100,digits=2))% MC=$(round(mape_mc*100,digits=2))%\")" => "println(\"    MAPE20: AR=$(round(mape_ar*100,digits=2))% | HW=$(round(mape_hw*100,digits=2))% | MC=$(round(mape_mc*100,digits=2))%\")"
)

for (k,v) in repls
    content = replace(content, k => v)
end

# چون بعضی رشته‌ها قبلاً خراب شده‌اند، مستقیم مهم‌ترین لاگ‌ها را با regex عوض می‌کنیم
content = replace(content, r"println\(\".*شروع.*\"\)" => "println(\"    === Forecast engine started ===\")")
content = replace(content, r"println\(\".*حالت بازار.*\"\)" => "println(\"    Market regime detected\")")
content = replace(content, r"println\(\".*تنظیم کلان.*\"\)" => "println(\"    Macro adjustment computed\")")
content = replace(content, r"println\(\".*اجرای 6 مدل.*\"\)" => "println(\"    Running 6 models...\")")
content = replace(content, r"println\(\".*وزن نهایی.*\"\)" => "println(\"    Final ensemble weights calculated\")")
content = replace(content, r"println\(\".*دلار: VAR \+ GARCH.*\"\)" => "println(\"    USD model: VAR + GARCH\")")
content = replace(content, r"println\(\".*ضریب بازار.*\"\)" => "println(\"    Market factor estimated\")")
content = replace(content, r"println\(\".*نتیجه نهایی.*\"\)" => "println(\"    === Final forecast ===\")")
content = replace(content, r"println\(\".*انس: .*\"\)" => "println(\"    Gold forecast computed\")")
content = replace(content, r"println\(\".*دلار: .*\"\)" => "println(\"    USD forecast computed\")")
content = replace(content, r"println\(\".*طلا18: .*\"\)" => "println(\"    Iran gold forecast computed\")")
content = replace(content, r"println\(\".*حالت: .*\"\)" => "println(\"    Forecast completed\")")

write("src/predictor.jl", content)
println("predictor.jl log strings normalized")
