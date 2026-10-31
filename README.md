# 🏦 Fionex Terminal v5.0

<div align="center">

![Julia](https://img.shields.io/badge/Julia-1.9+-9558B2?style=for-the-badge&logo=julia&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-blue?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)

**Bloomberg-style Persian Trading Terminal**

**ترمینال معاملاتی حرفه‌ای به سبک بلومبرگ**

[English](#-english) • [فارسی](#-فارسی)

</div>

---

## 🇬🇧 English

### 📊 Overview

**Fionex** is a professional-grade, Bloomberg-inspired trading terminal built entirely in **Julia**, designed for the Iranian market with focus on:

- 🪙 **Gold** (XAU/USD, 18k Iranian Gold)
- 💵 **USD/IRR** (Toman)
- 🏅 **Iranian Gold Coins** (Bahar Azadi, Nim, Rob, Gerami)
- ₿ **Cryptocurrencies** (BTC, ETH, SOL, PAXG)
- 💱 **Forex Pairs** (EUR/USD, GBP/JPY, USD/JPY, and more)

### ✨ Features

#### 🎯 Multi-Timeframe Analysis
- **Swing Trading:** H1 / H4 / D1 (60-second refresh)
- **Day Trading:** M5 / M15 / M30 (1-minute refresh, tighter ATR)

#### 📐 8 Institutional Quant Formulas
- Point of Control (POC) & Volume Profile
- Elliott Wave Detection
- Fibonacci Retracement / Extension
- Wyckoff Phase Analysis
- Order Blocks (OB)
- Fair Value Gaps (FVG)
- Break of Structure (BOS)
- Sharpe / Sortino / Hurst Exponent

#### 🖥️ 4 Terminal Tabs (Bloomberg-style)
- **F1 — Overview:** Live tickers, bubble indicator, pressure gauge, economic calendar
- **F2 — Analytics:** Line charts with EMA/SR, correlation heatmap, rolling correlation
- **F3 — Scanner:** Arbitrage radar, factor analysis, 25+ trade setups (SWING + DAYTRADE)
- **F4 — Backtest:** Prediction vs actual chart, error distribution, model grade, Monte Carlo

### 🛠️ Tech Stack

| Component  | Technology                      |
|------------|---------------------------------|
| Backend    | Julia 1.9+ (HTTP.jl, SQLite.jl) |
| Frontend   | Vanilla JS + Chart.js (local)   |
| Database   | SQLite                          |
| Data Feed  | Nobitex, TGJU, Stooq, Yahoo, open.er-api.com |

### 🚀 Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/aa22022/fionex-terminal.git
cd fionex-terminal

# 2. Install Julia packages
julia -e "using Pkg; Pkg.instantiate()"

# 3. Run the server
julia src/web_server.jl

# 4. Open browser
# http://localhost:8080