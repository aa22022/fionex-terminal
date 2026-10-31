content = read("templates/index.html", String)

old_signals = "document.getElementById('sigList').innerHTML=p.signals.filter(s=>s.length>0).map(s=>'<div class=\"sig-item\">'+s+'</div>').join('');"

new_signals = "document.getElementById('sigList').innerHTML = buildCleanSignals(d).map(s => '<div class=\"sig-item\">'+s+'</div>').join('');"

if occursin(old_signals, content)
    content = replace(content, old_signals => new_signals)
    println("signals replaced OK")
else
    println("not found - searching for partial match...")
    if occursin("p.signals.filter", content)
        content = replace(content, r"document\.getElementById\('sigList'\)\.innerHTML=p\.signals[^;]+;" => new_signals)
        println("signals replaced via regex")
    else
        println("WARNING: signals line not found")
    end
end

write("templates/index.html", content)
println("done")
