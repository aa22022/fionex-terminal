content = read("templates/index.html", String)

# بررسي مشكل اصلي
has_renderUI = occursin("function renderUI", content)
has_renderUI_call = occursin("renderUI(d)", content) || occursin("renderUI(fixed)", content)
has_loadData = occursin("async function loadData", content)

println("has renderUI function: $has_renderUI")
println("has renderUI call: $has_renderUI_call")
println("has loadData: $has_loadData")

# اگر renderUI(d) فراخواني نشده، patch كن
if !has_renderUI_call && has_renderUI
    content = replace(content,
        "const d=deepFix(raw);" =>
        "const d=deepFix(raw);\n    renderUI(d);"
    )
    println("PATCHED: added renderUI(d) call")
end

# اگر renderUI وجود ندارد، خلاصه‌اي اضافه كن
if !has_renderUI
    println("ERROR: renderUI function missing entirely!")
end

write("templates/index.html", content)
println("done")
