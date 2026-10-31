module Storage

using SQLite, DBInterface, Dates

export init_db, save_actual_snapshot!, save_prediction_run!, get_historical_predictions
export init_prediction_tracking!, save_prediction_snapshot!, evaluate_pending_predictions!
export get_prediction_accuracy, get_prediction_history
export get_accuracy_summary, get_multi_horizon_accuracy, get_prediction_trails

const DB_PATH = joinpath(@__DIR__, "..", "data", "forecast.db")

# ══════════════════════════════════════════════════════════════
# قفل گلوبال SQLite - سریالایز تمام نوشتن‌ها
# ══════════════════════════════════════════════════════════════
const DB_LOCK = ReentrantLock()

# ─── اتصال جدید با WAL + busy_timeout ───
function _open_db()
    db = SQLite.DB(DB_PATH)
    try
        DBInterface.execute(db, "PRAGMA journal_mode = WAL")
        DBInterface.execute(db, "PRAGMA synchronous = NORMAL")
        DBInterface.execute(db, "PRAGMA busy_timeout = 15000")
        DBInterface.execute(db, "PRAGMA temp_store = MEMORY")
        DBInterface.execute(db, "PRAGMA cache_size = -2000")
    catch
    end
    return db
end

# ─── اجرای یک تابع با قفل + اتصال امن ───
function with_db(f::Function)
    lock(DB_LOCK) do
        db = _open_db()
        try
            return f(db)
        finally
            try
                SQLite.close(db)
            catch
            end
        end
    end
end

# ══════════════════════════════════════════════════════════════
# init_db
# ══════════════════════════════════════════════════════════════
function init_db()
    mkpath(dirname(DB_PATH))
    with_db() do db
        DBInterface.execute(db, """
            CREATE TABLE IF NOT EXISTS snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT UNIQUE,
                gold_oz REAL,
                usd_irr REAL,
                iran_gold REAL
            )
        """)

        DBInterface.execute(db, """
            CREATE TABLE IF NOT EXISTS predictions_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                prediction_date TEXT,
                target_date TEXT,
                asset TEXT,
                predicted_value REAL,
                predicted_low REAL,
                predicted_high REAL,
                actual_value REAL,
                UNIQUE(prediction_date, target_date, asset) ON CONFLICT REPLACE
            )
        """)

        DBInterface.execute(db, """
            CREATE TABLE IF NOT EXISTS prediction_tracking (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                symbol TEXT NOT NULL,
                base_price REAL NOT NULL,
                predicted_24h REAL NOT NULL,
                target_time TEXT NOT NULL,
                actual_24h REAL,
                error_pct REAL,
                evaluated_at TEXT
            )
        """)

        DBInterface.execute(db, "CREATE INDEX IF NOT EXISTS idx_pred_target ON prediction_tracking(target_time)")
        DBInterface.execute(db, "CREATE INDEX IF NOT EXISTS idx_pred_symbol ON prediction_tracking(symbol)")
        DBInterface.execute(db, "CREATE INDEX IF NOT EXISTS idx_snapshots_date ON snapshots(created_at)")
    end
    return true
end

# ══════════════════════════════════════════════════════════════
# save_actual_snapshot!
# ══════════════════════════════════════════════════════════════
function save_actual_snapshot!(data::Dict, analysis::Any)
    today_str = string(today())
    try
        gold = Float64(data["gold_oz"]["prices"][end])
        usd  = Float64(data["usd_irr"]["prices"][end])
        iran = Float64(data["iran_gold"]["prices"][end])

        with_db() do db
            DBInterface.execute(db, """
                INSERT INTO snapshots (created_at, gold_oz, usd_irr, iran_gold)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(created_at) DO UPDATE SET
                    gold_oz=excluded.gold_oz,
                    usd_irr=excluded.usd_irr,
                    iran_gold=excluded.iran_gold
            """, (today_str, gold, usd, iran))

            DBInterface.execute(db,
                "UPDATE predictions_history SET actual_value = ? WHERE target_date = ? AND asset = 'gold_oz'",
                (gold, today_str))

            DBInterface.execute(db,
                "UPDATE predictions_history SET actual_value = ? WHERE target_date = ? AND asset = 'usd_irr'",
                (usd, today_str))

            DBInterface.execute(db,
                "UPDATE predictions_history SET actual_value = ? WHERE target_date = ? AND asset = 'iran_gold'",
                (iran, today_str))
        end
    catch e
        @warn "خطا در save_actual_snapshot!" exception=e
    end
end

# ══════════════════════════════════════════════════════════════
# save_prediction_run!
# ══════════════════════════════════════════════════════════════
function save_prediction_run!(p::Any)
    today_str = string(today())
    try
        assets = ["gold_oz", "usd_irr", "iran_gold"]
        points = [p.gold_oz_daily, p.usd_irr_daily, p.iran_gold_daily]
        lows = [p.gold_oz_low, p.usd_irr_low, p.iran_gold_low]
        highs = [p.gold_oz_high, p.usd_irr_high, p.iran_gold_high]

        with_db() do db
            for (asset_idx, asset) in enumerate(assets)
                daily_vals = points[asset_idx]
                low_val = lows[asset_idx]
                high_val = highs[asset_idx]

                for i in 1:length(daily_vals)
                    t_date = string(today() + Day(i))
                    val = Float64(daily_vals[i])
                    progress = i / length(daily_vals)
                    curve = progress ^ 0.85
                    width = (high_val - low_val) * curve
                    band_low = val - width / 2
                    band_high = val + width / 2

                    DBInterface.execute(db, """
                        INSERT INTO predictions_history (prediction_date, target_date, asset, predicted_value, predicted_low, predicted_high)
                        VALUES (?, ?, ?, ?, ?, ?)
                        ON CONFLICT(prediction_date, target_date, asset) DO UPDATE SET
                            predicted_value=excluded.predicted_value,
                            predicted_low=excluded.predicted_low,
                            predicted_high=excluded.predicted_high
                    """, (today_str, t_date, asset, val, band_low, band_high))
                end
            end
        end
    catch e
        @warn "خطا در save_prediction_run!" exception=e
    end
end

# ══════════════════════════════════════════════════════════════
# get_historical_predictions
# ══════════════════════════════════════════════════════════════
function get_historical_predictions(asset::String, limit_days::Int=60)::Vector{Dict}
    res = Dict[]
    !isfile(DB_PATH) && return res
    try
        with_db() do db
            query = """
                SELECT prediction_date, target_date, predicted_value, actual_value
                FROM predictions_history
                WHERE asset = ? AND target_date >= ?
                ORDER BY target_date ASC
            """
            start_date = string(today() - Day(limit_days))
            df = DBInterface.execute(db, query, (asset, start_date))
            for row in df
                push!(res, Dict(
                    "prediction_date" => string(row.prediction_date),
                    "target_date"     => string(row.target_date),
                    "predicted"       => Float64(row.predicted_value),
                    "actual"          => row.actual_value === nothing ? nothing : Float64(row.actual_value)
                ))
            end
        end
    catch e
        @warn "خطا در get_historical_predictions" exception=e
    end
    return res
end

# ══════════════════════════════════════════════════════════════
# Prediction Tracking
# ══════════════════════════════════════════════════════════════
function init_prediction_tracking!()
    try
        init_db()
        return true
    catch e
        @warn "خطا در init_prediction_tracking!" exception=e
        return false
    end
end

function save_prediction_snapshot!(symbol::String, base_price::Float64, predicted_24h::Float64, target_time::DateTime)
    base_price <= 0.0 && return false
    predicted_24h <= 0.0 && return false
    try
        with_db() do db
            DBInterface.execute(db,
                "INSERT INTO prediction_tracking (created_at, symbol, base_price, predicted_24h, target_time) VALUES (?, ?, ?, ?, ?)",
                (string(now()), symbol, base_price, predicted_24h, string(target_time)))
        end
        return true
    catch e
        @warn "خطا در save_prediction_snapshot!" exception=e
        return false
    end
end

function evaluate_pending_predictions!(current_prices::Dict{String, Float64})
    try
        return with_db() do db
            now_str = string(now())
            rows = DBInterface.execute(db,
                "SELECT id, symbol, predicted_24h, target_time FROM prediction_tracking WHERE actual_24h IS NULL AND target_time < ?",
                (now_str,))

            count = 0
            for r in rows
                sym = string(r.symbol)
                pred = Float64(r.predicted_24h)
                id = Int(r.id)

                actual = get(current_prices, sym, 0.0)
                actual <= 0.0 && continue

                err_pct = abs((actual - pred) / actual) * 100.0

                DBInterface.execute(db,
                    "UPDATE prediction_tracking SET actual_24h = ?, error_pct = ?, evaluated_at = ? WHERE id = ?",
                    (actual, err_pct, now_str, id))
                count += 1
            end
            return count
        end
    catch e
        @warn "خطا در evaluate_pending_predictions!" exception=e
        return 0
    end
end

function get_prediction_accuracy(days::Int=30)
    result = Dict{String, Any}(
        "available" => false,
        "period_days" => days,
        "symbols" => Dict{String, Any}(),
        "overall" => Dict{String, Any}()
    )
    try
        with_db() do db
            cutoff = string(now() - Day(days))
            symbols = ["gold_oz", "usd_irr", "iran_gold", "coin"]
            total_count = 0
            total_error = 0.0

            for sym in symbols
                rows = DBInterface.execute(db,
                    "SELECT error_pct FROM prediction_tracking WHERE symbol = ? AND error_pct IS NOT NULL AND created_at > ?",
                    (sym, cutoff))

                errors = Float64[]
                for r in rows
                    e = tryparse(Float64, string(r.error_pct))
                    e !== nothing && push!(errors, e)
                end

                if !isempty(errors)
                    mean_err = sum(errors) / length(errors)
                    accuracy = max(0.0, 100.0 - mean_err)
                    good = count(e -> e < 1.0, errors)
                    dir_acc = (good / length(errors)) * 100.0

                    result["symbols"][sym] = Dict(
                        "count" => length(errors),
                        "mean_error_pct" => round(mean_err, digits=3),
                        "accuracy_pct" => round(accuracy, digits=1),
                        "directional_accuracy" => round(dir_acc, digits=1),
                        "min_error" => round(minimum(errors), digits=3),
                        "max_error" => round(maximum(errors), digits=3)
                    )

                    total_count += length(errors)
                    total_error += mean_err * length(errors)
                end
            end

            if total_count > 0
                overall_err = total_error / total_count
                result["available"] = true
                result["overall"] = Dict(
                    "total_predictions" => total_count,
                    "mean_error_pct" => round(overall_err, digits=3),
                    "accuracy_pct" => round(max(0.0, 100.0 - overall_err), digits=1)
                )
            end
        end
    catch e
        @warn "خطا در get_prediction_accuracy" exception=e
    end
    return result
end

function get_prediction_history(symbol::String, days::Int=30)
    rows_out = []
    try
        with_db() do db
            cutoff = string(now() - Day(days))
            rows = DBInterface.execute(db,
                "SELECT created_at, base_price, predicted_24h, actual_24h, error_pct FROM prediction_tracking WHERE symbol = ? AND actual_24h IS NOT NULL AND created_at > ? ORDER BY created_at DESC LIMIT 30",
                (symbol, cutoff))

            for r in rows
                # چک missing
                base = _safe_float(r.base_price)
                pred = _safe_float(r.predicted_24h)
                act = _safe_float(r.actual_24h)
                err = _safe_float(r.error_pct)

                (base === nothing || pred === nothing || act === nothing) && continue

                date_str = ""
                try
                    ds = string(r.created_at)
                    date_str = length(ds) >= 10 ? ds[1:10] : ds
                catch
                    date_str = ""
                end

                push!(rows_out, Dict(
                    "date" => date_str,
                    "base_price" => base,
                    "predicted" => pred,
                    "actual" => act,
                    "error_pct" => err === nothing ? 0.0 : err
                ))
            end
        end
    catch e
        @warn "خطا در get_prediction_history" exception=e
    end
    return rows_out
end

# ══════════════════════════════════════════════════════════════
# توابع قدیمی (placeholder)
# ══════════════════════════════════════════════════════════════
function get_accuracy_summary(days::Int=30)
    return Dict("count" => 0)
end

function get_multi_horizon_accuracy(days::Int=60)
    return Dict()
end

function get_prediction_trails(days::Int=90; horizon_day::Int=1, per_day::Bool=true)
    return Dict()
end


function _safe_float(v)
    v === nothing && return nothing
    ismissing(v) && return nothing
    try
        return Float64(v)
    catch
        return nothing
    end
end

function _safe_str(v)
    v === nothing && return ""
    ismissing(v) && return ""
    try
        return string(v)
    catch
        return ""
    end
end

function get_all_prediction_history(asset::String, days::Int=90)
    rows_out = []
    !isfile(DB_PATH) && return rows_out
    try
        with_db() do db
            cutoff = string(today() - Day(days))
            rows = DBInterface.execute(db,
                "SELECT prediction_date, target_date, predicted_value, predicted_low, predicted_high, actual_value FROM predictions_history WHERE asset = ? AND target_date >= ? ORDER BY target_date ASC",
                (asset, cutoff))
            for r in rows
                # بررسی مقادیر missing
                pred_val = _safe_float(r.predicted_value)
                pred_val === nothing && continue  # ردیف بدون predicted_value را رد کن

                push!(rows_out, Dict(
                    "pred_date" => _safe_str(r.prediction_date),
                    "target_date" => _safe_str(r.target_date),
                    "predicted" => pred_val,
                    "pred_low" => _safe_float(r.predicted_low),
                    "pred_high" => _safe_float(r.predicted_high),
                    "actual" => _safe_float(r.actual_value)
                ))
            end
        end
    catch e
        @warn "خطا در get_all_prediction_history" exception=e
    end
    return rows_out
end

end