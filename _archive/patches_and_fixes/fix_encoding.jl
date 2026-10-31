# Read file
content = read("src/predictor.jl", String)

# Fix method_weights keys (lines 717-722)
content = replace(content, r'"[^"]*?"=>round\(w\[1\],digits=3\)' => '"ARIMA(5,1,0)"=>round(w[1],digits=3)')
content = replace(content, r'"[^"]*?"=>round\(w\[2\],digits=3\)' => '"Holt-Winters"=>round(w[2],digits=3)')
content = replace(content, r'"[^"]*?"=>round\(w\[3\],digits=3\)' => '"Ridge Reg"=>round(w[3],digits=3)')
content = replace(content, r'"[^"]*?"=>round\(w\[4\],digits=3\)' => '"MonteCarlo+GARCH"=>round(w[4],digits=3)')
content = replace(content, r'"[^"]*?"=>round\(w\[5\],digits=3\)' => '"TechnicalAnalysis"=>round(w[5],digits=3)')
content = replace(content, r'"[^"]*?"=>round\(w\[6\],digits=3\)' => '"CurrencyImpact"=>round(w[6],digits=3)')

# Fix trend values (line 774-775)
content = replace(content, r'chg>3 \? "[^"]*?"' => 'chg>3 ? "صعود قوی"')
content = replace(content, r'chg>1 \? "[^"]*?"' => 'chg>1 ? "صعود"')
content = replace(content, r'chg>0\.3 \? "[^"]*?" [^:]*?:' => 'chg>0.3 ? "صعود ملایم" :')
content = replace(content, r'chg>-0\.3 \? "[^"]*?"' => 'chg>-0.3 ? "خنثی"')
content = replace(content, r'chg>-1 \? "[^"]*?"' => 'chg>-1 ? "نزول ملایم"')
content = replace(content, r'chg>-3 \? "[^"]*?"' => 'chg>-3 ? "نزول"')

write("src/predictor.jl", content)
println("Done!")
