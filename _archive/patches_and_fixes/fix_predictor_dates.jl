content = read("src\\predictor.jl", String)

helper = """
function build_target_dates_from_data(data::Dict, days::Int)
    dates_arr = Date[]
    try
        push!(dates_arr, Date(data["gold_oz"]["dates"][end]))
    catch
    end
    try
        push!(dates_arr, Date(data["usd_irr"]["dates"][end]))
    catch
    end
    try
        push!(dates_arr, Date(data["iran_gold"]["dates"][end]))
    catch
    end

    start_date = isempty(dates_arr) ? today() : maximum(dates_arr)
    return [Dates.format(start_date + Day(i), "yyyy-mm-dd") for i in 1:days]
end

"""

if !contains(content, "function build_target_dates_from_data")
    content = replace(content, "function predict_next_week(data::Dict, analysis)" => helper * "\nfunction predict_next_week(data::Dict, analysis)")
end

content = replace(
    content,
    r"tdates\s*=\s*\[Dates\.format\(now\(\)\+Day\(i\),\s*\"yyyy-mm-dd\"\)\s*for\s*i\s*in\s*1:days\]" =>
    "tdates = build_target_dates_from_data(data, days)"
)

write("src\\predictor.jl", content)
println("predictor.jl fixed")
