from pathlib import Path

p = Path("src/web_server.jl")
txt = p.read_text(encoding="utf-8")

if '/static/app.js' not in txt:
    old = '''    elseif path == "/static/chart.min.js"
        return HTTP.Response(
            200,
            ["Content-Type" => "application/javascript; charset=utf-8",
             "Cache-Control" => "public, max-age=86400"],
            body = read(joinpath(@__DIR__, "..", "static", "chart.min.js"))
        )'''
    
    new = '''    elseif path == "/static/chart.min.js"
        return HTTP.Response(
            200,
            ["Content-Type" => "application/javascript; charset=utf-8",
             "Cache-Control" => "public, max-age=86400"],
            body = read(joinpath(@__DIR__, "..", "static", "chart.min.js"))
        )
    elseif path == "/static/app.js"
        return HTTP.Response(
            200,
            ["Content-Type" => "application/javascript; charset=utf-8",
             "Cache-Control" => "no-store"],
            body = read(joinpath(@__DIR__, "..", "static", "app.js"))
        )'''
    
    txt = txt.replace(old, new, 1)
    p.write_text(txt, encoding="utf-8")
    print("[OK] app.js route added")
else:
    print("[SKIP] route already exists")
