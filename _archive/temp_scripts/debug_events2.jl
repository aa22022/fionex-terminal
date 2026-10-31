include("src/macro_data.jl")
using .MacroData
using Dates

println("امروز: ", today())

events = fetch_upcoming_events(14)

println("تعداد رویدادهای 14 روز آینده: ", length(events))
println()

for ev in events
    println(ev["date"], " | ", ev["title"], " | ", ev["impact"])
end
