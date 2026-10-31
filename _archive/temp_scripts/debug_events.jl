using JSON3, Dates

path = joinpath(pwd(), "config", "events.json")
println("مسير: ", path)
println("فايل وجود دارد: ", isfile(path))

raw = read(path, String)
raw = replace(raw, "\ufeff" => "")
raw = strip(raw)

println("50 كاراكتر اول: ", raw[1:min(50, end)])

arr = JSON3.read(raw)
println("تعداد كل رويدادها: ", length(arr))

cnt = 0
for ev in arr
    ds = string(ev[:date])
    dt = Date(ds)
    ok = dt >= today() && dt <= today() + Day(14)
    println("  ", ds, " | امروز=", today(), " | داخل 14 روز؟ ", ok)
    if ok
        cnt += 1
    end
end

println("تعداد رويدادهاي معتبر 14 روز آينده: ", cnt)
