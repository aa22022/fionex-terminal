# اين فايل predictor.jl رو آپدیت مي‌كنه - مدل 7 و WF اضافه مي‌كنه

content = read("src/predictor.jl", String)

# اضافه كردن import در بالاي فايل
old_module = "module Predictor\n\nusing Statistics, LinearAlgebra, Dates, Random"
new_module = "module Predictor\n\nusing Statistics, LinearAlgebra, Dates, Random\n\ninclude(\"ensemble_ml.jl\")\nusing .EnsembleML"

content = replace(content, old_module => new_module)

write("src/predictor.jl", content)
println("predictor.jl آپديت شد - EnsembleML اضافه شد")
