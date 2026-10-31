module NewsSentiment

using Downloads, Dates, Statistics

export fetch_news_sentiment, NewsSentimentResult

struct NewsItem
    title::String
    source::String
    score::Float64
    keywords::Vector{String}
end

struct NewsSentimentResult
    overall_score::Float64
    gold_score::Float64
    usd_score::Float64
    iran_score::Float64
    news_items::Vector{NewsItem}
    alert_level::String
    summary::String
    last_updated::DateTime
end

const GOLD_BULLISH = [
    "gold rises", "gold gains", "gold surges", "gold rally", "gold climbs",
    "gold hits high", "gold record", "safe haven", "inflation fears",
    "rate cut", "rate cuts", "fed pivot", "dollar weakens", "dollar falls",
    "geopolitical", "war", "crisis", "uncertainty", "recession",
    "gold demand", "central bank buying", "etf inflows", "bullion",
    "xau rises", "precious metals gain", "flight to safety",
    "gold up", "gold advances", "gold extends", "gold rebounds",
    "fed dovish", "yields fall", "yields drop", "weaker dollar",
    "افزایش طلا", "رشد طلا", "صعود طلا", "طلا گران"
]

const GOLD_BEARISH = [
    "gold falls", "gold drops", "gold declines", "gold retreats", "gold slides",
    "gold hits low", "rate hike", "rate rises", "fed hawkish", "dollar strengthens",
    "dollar rises", "dollar gains", "risk appetite", "stock market rally",
    "gold outflows", "gold selling", "profit taking", "gold pressure",
    "xau falls", "precious metals decline", "gold weakness",
    "gold down", "gold slips", "gold edges lower", "gold eases",
    "yields rise", "yields climb", "stronger dollar", "dollar rally",
    "کاهش طلا", "ریزش طلا", "نزول طلا", "افت طلا"
]

const USD_BULLISH = [
    "dollar rises", "dollar gains", "dollar strengthens", "usd rally",
    "fed hawkish", "rate hike", "strong dollar", "dollar index rises",
    "nfp beat", "jobs report strong", "inflation high", "fed tightening",
    "dollar up", "greenback gains", "usd advances"
]

const USD_BEARISH = [
    "dollar falls", "dollar drops", "dollar weakens", "usd decline",
    "fed dovish", "rate cut", "weak dollar", "dollar index falls",
    "nfp miss", "jobs report weak", "fed easing", "dollar pressure",
    "dollar down", "greenback falls", "usd retreats"
]

const IRAN_KEYWORDS = [
    "iran sanctions", "iran nuclear", "iran deal", "jcpoa",
    "iran tensions", "middle east crisis", "persian gulf",
    "تحریم", "برجام", "مذاکرات هسته‌ای", "بحران خاورمیانه"
]

const HIGH_IMPACT = [
    "fomc", "federal reserve", "powell", "rate decision",
    "cpi", "inflation data", "nfp", "jobs report", "gdp",
    "retail sales", "ppi"
]

function fetch_rss(url::String)
    path, io = mktemp()
    close(io)
    try
        Downloads.download(url, path, headers=Dict("User-Agent" => "Mozilla/5.0"))
        return read(path, String)
    catch
        return ""
    finally
        isfile(path) && rm(path, force=true)
    end
end

function extract_titles(xml::String)
    titles = String[]
    
    for m in eachmatch(r"<title><!\[CDATA\[(.+?)\]\]></title>"si, xml)
        t = strip(m.captures[1])
        length(t) > 15 && push!(titles, t)
    end

    if isempty(titles)
        for m in eachmatch(r"<title>([^<]{15,300})</title>"si, xml)
            t = strip(m.captures[1])
            if !contains(t, "<?xml") && !contains(t, "RSS Feed") &&
               !contains(t, "MarketWatch.com -") && !contains(t, "FXStreet")
                push!(titles, t)
            end
        end
    end

    return unique(titles)
end

function score_text(text::String)
    tl = lowercase(text)
    gold_s = 0.0
    usd_s  = 0.0
    iran_s = 0.0
    found  = String[]

    for kw in GOLD_BULLISH
        if contains(tl, kw)
            w = length(split(kw)) >= 3 ? 2.0 : 1.0
            gold_s += w
            push!(found, kw)
        end
    end
    for kw in GOLD_BEARISH
        if contains(tl, kw)
            w = length(split(kw)) >= 3 ? 2.0 : 1.0
            gold_s -= w
            push!(found, "-" * kw)
        end
    end
    for kw in USD_BULLISH
        contains(tl, kw) && (usd_s += 1.0; push!(found, "USD+" * kw))
    end
    for kw in USD_BEARISH
        contains(tl, kw) && (usd_s -= 1.0; push!(found, "USD-" * kw))
    end
    for kw in IRAN_KEYWORDS
        contains(tl, lowercase(kw)) && (iran_s += 1.0)
    end

    hi_boost = 1.0
    for ev in HIGH_IMPACT
        if contains(tl, ev)
            hi_boost = 1.6
            push!(found, "HIGH:" * ev)
            break
        end
    end

    total = (gold_s * 0.6 + usd_s * (-0.3) + iran_s * 0.1) * hi_boost
    return total, gold_s, usd_s, iran_s, unique(found)
end

const RSS_SOURCES = [
    ("FXStreet",      "https://www.fxstreet.com/rss/news", 2.0),
    ("Investing.com", "https://www.investing.com/rss/news_95.rss", 1.8),
    ("MarketWatch",   "https://feeds.content.dowjones.io/public/rss/mw_realtimeheadlines", 1.5)
]

function fetch_news_sentiment(hours_back::Int=24)
    all_items = NewsItem[]
    gold_scores_all  = Float64[]
    usd_scores_all   = Float64[]
    iran_scores_all  = Float64[]

    for (name, url, weight) in RSS_SOURCES
        xml = fetch_rss(url)
        isempty(xml) && continue

        titles = extract_titles(xml)
        count = 0

        for title in titles[1:min(25, end)]
            length(title) < 12 && continue

            total, gs, us, is_, kws = score_text(title)

            push!(gold_scores_all, gs * weight)
            push!(usd_scores_all,  us * weight)
            push!(iran_scores_all, is_ * weight)

            if abs(total) > 0.3 || !isempty(kws)
                push!(all_items, NewsItem(title, name, round(total * weight, digits=2), kws))
                count += 1
            end
        end
    end

    if isempty(all_items) && isempty(gold_scores_all)
        return NewsSentimentResult(0.0, 0.0, 0.0, 0.0, NewsItem[], "LOW", "No news available", now())
    end

    sort!(all_items, by = x -> abs(x.score), rev=true)

    gm = isempty(gold_scores_all) ? 0.0 : mean(gold_scores_all)
    um = isempty(usd_scores_all)  ? 0.0 : mean(usd_scores_all)
    im = isempty(iran_scores_all) ? 0.0 : mean(iran_scores_all)

    overall = clamp(gm * 25.0, -100.0, 100.0)
    gold_n  = clamp(gm * 25.0, -100.0, 100.0)
    usd_n   = clamp(um * 25.0, -100.0, 100.0)
    iran_n  = clamp(im * 20.0, -100.0, 100.0)

    alert = abs(overall) > 55.0 ? "HIGH" : (abs(overall) > 25.0 ? "MEDIUM" : "LOW")
    direction = overall > 20.0 ? "Gold Bullish" : (overall < -20.0 ? "Gold Bearish" : "Neutral")
    
    top_title = isempty(all_items) ? "" : " | " * all_items[1].title[1:min(50, end)]
    summary   = "Sentiment $direction$top_title"

    return NewsSentimentResult(
        round(overall, digits=1), round(gold_n, digits=1),
        round(usd_n, digits=1),   round(iran_n, digits=1),
        all_items[1:min(15, end)],
        alert, summary, now()
    )
end

end