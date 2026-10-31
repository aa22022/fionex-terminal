module MarketRegistry

export FXPair, MAJOR_PAIRS, MINOR_PAIRS, CRYPTO_PAIRS, ALL_FX_PAIRS,
       CURRENCY_NAMES, BASE_PAIRS_MAP

struct FXPair
    symbol::String
    base::String
    quote_::String
    category::String
    typical_spread::Float64
    avg_daily_range::Float64
end

const CURRENCY_NAMES = Dict(
    "EUR" => "یورو",
    "USD" => "دلار آمریکا",
    "GBP" => "پوند انگلیس",
    "JPY" => "ین ژاپن",
    "CHF" => "فرانک سوئیس",
    "AUD" => "دلار استرالیا",
    "CAD" => "دلار کانادا",
    "NZD" => "دلار نیوزیلند",
    "NOK" => "کرون نروژ",
    "SEK" => "کرون سوئد",
    "DKK" => "کرون دانمارک",
    "SGD" => "دلار سنگاپور",
    "HKD" => "دلار هنگ‌کنگ",
    "ZAR" => "رند آفریقای جنوبی",
    "MXN" => "پزو مکزیک",
    "TRY" => "لیر ترکیه",
    "CNY" => "یوان چین",
    "INR" => "روپیه هند",
    "BRL" => "رئال برزیل",
    "BTC" => "بیت‌کوین",
    "ETH" => "اتریوم",
    "SOL" => "سولانا",
    "USDT" => "تتر"
)

const MAJOR_PAIRS = [
    FXPair("EURUSD","EUR","USD","major",0.0001,0.65),
    FXPair("GBPUSD","GBP","USD","major",0.0002,0.75),
    FXPair("USDJPY","USD","JPY","major",0.01,0.55),
    FXPair("USDCHF","USD","CHF","major",0.0002,0.55),
    FXPair("AUDUSD","AUD","USD","major",0.0002,0.65),
    FXPair("USDCAD","USD","CAD","major",0.0002,0.55),
    FXPair("NZDUSD","NZD","USD","major",0.0003,0.60)
]

const MINOR_PAIRS = [
    FXPair("EURGBP","EUR","GBP","minor",0.0002,0.40),
    FXPair("EURJPY","EUR","JPY","minor",0.02,0.70),
    FXPair("GBPJPY","GBP","JPY","minor",0.03,0.95),
    FXPair("CHFJPY","CHF","JPY","minor",0.02,0.55),
    FXPair("AUDJPY","AUD","JPY","minor",0.02,0.70),
    FXPair("CADJPY","CAD","JPY","minor",0.02,0.65),
    FXPair("EURAUD","EUR","AUD","minor",0.0003,0.75),
    FXPair("EURCHF","EUR","CHF","minor",0.0002,0.40),
    FXPair("GBPCHF","GBP","CHF","minor",0.0003,0.70),
    FXPair("AUDCAD","AUD","CAD","minor",0.0003,0.55),
    FXPair("AUDNZD","AUD","NZD","minor",0.0003,0.55),
    FXPair("EURCAD","EUR","CAD","minor",0.0003,0.65),
    FXPair("GBPAUD","GBP","AUD","minor",0.0004,0.85),
    FXPair("GBPCAD","GBP","CAD","minor",0.0004,0.80),
    FXPair("NZDJPY","NZD","JPY","minor",0.02,0.70)
]

const CRYPTO_PAIRS = [
    FXPair("BTCUSDT","BTC","USDT","crypto",0.1,5.5),
    FXPair("ETHUSDT","ETH","USDT","crypto",0.01,6.5),
    FXPair("SOLUSDT","SOL","USDT","crypto",0.01,8.0)
]

const ALL_FX_PAIRS = vcat(MAJOR_PAIRS, MINOR_PAIRS, CRYPTO_PAIRS)

const BASE_PAIRS_MAP = Dict(
    "EUR" => [("EURUSD",1),("EURGBP",1),("EURJPY",1),("EURAUD",1),("EURCHF",1),("EURCAD",1)],
    "USD" => [("EURUSD",-1),("GBPUSD",-1),("USDJPY",1),("USDCHF",1),("AUDUSD",-1),("USDCAD",1),("NZDUSD",-1)],
    "GBP" => [("GBPUSD",1),("EURGBP",-1),("GBPJPY",1),("GBPCHF",1),("GBPAUD",1),("GBPCAD",1)],
    "JPY" => [("USDJPY",-1),("EURJPY",-1),("GBPJPY",-1),("AUDJPY",-1),("CHFJPY",-1),("CADJPY",-1),("NZDJPY",-1)],
    "CHF" => [("USDCHF",-1),("EURCHF",-1),("GBPCHF",-1),("CHFJPY",1)],
    "AUD" => [("AUDUSD",1),("EURAUD",-1),("AUDJPY",1),("AUDCAD",1),("AUDNZD",1),("GBPAUD",-1)],
    "CAD" => [("USDCAD",-1),("EURCAD",-1),("CADJPY",1),("AUDCAD",-1),("GBPCAD",-1)],
    "NZD" => [("NZDUSD",1),("NZDJPY",1),("AUDNZD",-1)]
)

end
