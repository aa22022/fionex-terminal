from pathlib import Path

p = Path("src/web_server.jl")
txt = p.read_text(encoding="utf-8")

if 'include("relationship_engine.jl")' not in txt:
    txt = txt.replace(
        'include("news_sentiment.jl")',
        'include("news_sentiment.jl")\ninclude("relationship_engine.jl")',
        1
    )
    print("[OK] include added")
else:
    print("[SKIP] include already exists")

if 'using .RelationshipEngine' not in txt:
    txt = txt.replace(
        'using .NewsSentiment',
        'using .NewsSentiment\nusing .RelationshipEngine',
        1
    )
    print("[OK] using added")
else:
    print("[SKIP] using already exists")

old_block = '    println("  [9/10] forecast...")'
new_block = '''    println("  [8b/10] relationship analysis...")
    relationship_map = try
        others = Dict{String,Vector{Float64}}()
        others["usd"] = STATE.data["usd_irr"]["prices"]
        for c in STATE.data["currencies"]
            length(c.prices) >= 20 && (others[c.symbol] = c.prices)
        end
        macrod = get(STATE.data, "macro", Dict())
        if haskey(macrod, "dxy") && haskey(macrod["dxy"], "prices")
            others["DXY"] = macrod["dxy"]["prices"]
        end
        if haskey(macrod, "vix") && haskey(macrod["vix"], "prices")
            others["VIX"] = macrod["vix"]["prices"]
        end
        control = get(others, "usd", nothing)
        rel = compute_relationships(
            "gold",
            STATE.data["gold_oz"]["prices"],
            others;
            control_series = control
        )
        println("       relationships=$(length(rel.relations)) | leading=$(length(rel.leading_assets)) | lagging=$(length(rel.lagging_assets))")
        rel
    catch e
        println("       relationship error: $e")
        nothing
    end

    println("  [9/10] forecast...")'''

if old_block in txt:
    txt = txt.replace(old_block, new_block, 1)
    print("[OK] relationship block added")
else:
    print("[WARN] [9/10] block not found")

if '"relationships"' not in txt:
    txt = txt.replace(
        '        "sentiment"         => serialize_sentiment(STATE.sentiment),',
        '        "sentiment"         => serialize_sentiment(STATE.sentiment),\n        "relationships"     => serialize_relationships(relationship_map),',
        1
    )
    print("[OK] relationships in API response")
else:
    print("[SKIP] relationships already in API response")

p.write_text(txt, encoding="utf-8")

p2 = Path("src/web_server.jl")
txt2 = p2.read_text(encoding="utf-8")

if 'function serialize_relationships' not in txt2:
    txt2 = txt2.replace(
        'function build_market_alert',
        '''function serialize_relationships(rm)
    rm === nothing && return Dict("available" => false)
    relations = []
    for r in rm.relations[1:min(15, length(rm.relations))]
        rc = Dict{String,Any}()
        for (k,v) in r.regime_corr
            rc[k] = v
        end
        push!(relations, Dict(
            "asset_b"       => r.asset_b,
            "pearson_20d"   => r.pearson_20d,
            "pearson_60d"   => r.pearson_60d,
            "lead_lag_days" => r.lead_lag_days,
            "lead_lag_corr" => r.lead_lag_corr,
            "beta_30d"      => r.beta_30d,
            "partial_corr"  => r.partial_corr,
            "direction"     => r.direction,
            "strength"      => r.strength,
            "regime_corr"   => rc,
            "dep_score"     => get(rm.dependency_scores, r.asset_b, 0.0)
        ))
    end
    sorted_deps = sort(collect(rm.dependency_scores), by=x->-x[2])
    top5 = [k for (k,v) in sorted_deps[1:min(5,length(sorted_deps))]]
    return Dict(
        "available"      => true,
        "computed_at"    => rm.computed_at,
        "relations"      => relations,
        "leading_assets" => rm.leading_assets,
        "lagging_assets" => rm.lagging_assets,
        "top_influencers"=> top5
    )
end

function build_market_alert''',
        1
    )
    p2.write_text(txt2, encoding="utf-8")
    print("[OK] serialize_relationships added")
else:
    print("[SKIP] serialize_relationships already exists")

print("Done!")
