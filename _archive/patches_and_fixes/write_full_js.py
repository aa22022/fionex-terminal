from pathlib import Path

p = Path("static/app.js")

full_code = """/* ═══════════════════════════════════════════════════════════ */
/* CHART.JS DEFAULTS                                           */
/* ═══════════════════════════════════════════════════════════ */
Chart.defaults.color = '#8a95a5';
Chart.defaults.borderColor = '#1e2630';
Chart.defaults.font.family = 'Vazirmatn';
Chart.defaults.font.size = 10;

/* ═══════════════════════════════════════════════════════════ */
/* GLOBAL STATE                                                */
/* ═══════════════════════════════════════════════════════════ */
const APP = {
  data: null,
  charts: {},
  currentPage: 'overview',
  lastFetch: 0
};

/* ═══════════════════════════════════════════════════════════ */
/* MOJIBAKE FIX                                                */
/* ═══════════════════════════════════════════════════════════ */
function looksMojibake(str) {
  return typeof str === "string" && /Ã|Ø|Ù|Â|â|€|™|œ|ž|¢/.test(str);
}
function latin1BytesToUtf8(str) {
  try {
    const bytes = Uint8Array.from(Array.from(str).map(ch => ch.charCodeAt(0) & 0xFF));
    return new TextDecoder("utf-8").decode(bytes);
  } catch { return str; }
}
function fixStr(str) {
  if (!looksMojibake(str)) return str;
  let cur = str;
  for (let i = 0; i < 4; i++) {
    const next = latin1BytesToUtf8(cur);
    if (next === cur) break;
    cur = next;
    if (!looksMojibake(cur)) break;
  }
  return cur;
}
function deepFix(obj) {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === "string") return fixStr(obj);
  if (Array.isArray(obj)) return obj.map(deepFix);
  if (typeof obj === "object") {
    const out = {};
    for (const [k, v] of Object.entries(obj)) out[k] = deepFix(v);
    return out;
  }
  return obj;
}

/* ═══════════════════════════════════════════════════════════ */
/* FORMATTERS                                                  */
/* ═══════════════════════════════════════════════════════════ */
function fmt(n) {
  if (n === null || n === undefined) return '--';
  return Math.round(n).toLocaleString('fa-IR');
}
function fmtE(n, d = 2) {
  if (n === null || n === undefined) return '--';
  return Number(n).toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d });
}
function toShamsi(dateStr) {
  if (!dateStr) return dateStr;
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString('fa-IR', { year: 'numeric', month: '2-digit', day: '2-digit' });
  } catch { return dateStr; }
}
function toShamsiShort(dateStr) {
  if (!dateStr) return dateStr;
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString('fa-IR', { month: '2-digit', day: '2-digit' });
  } catch { return dateStr; }
}

/* ═══════════════════════════════════════════════════════════ */
/* NAVIGATION / ROUTER                                         */
/* ═══════════════════════════════════════════════════════════ */
function switchPage(pageName) {
  document.querySelectorAll('.topnav-link').forEach(b => {
    b.classList.toggle('active', b.dataset.page === pageName);
  });
  
  document.querySelectorAll('.page').forEach(p => {
    p.classList.toggle('active', p.id === 'page-' + pageName);
  });
  
  APP.currentPage = pageName;
  
  if (APP.data) {
    setTimeout(() => renderPage(pageName), 50);
  }
  
  if (window.location.hash !== '#' + pageName) {
    window.location.hash = '#' + pageName;
  }
}

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.topnav-link').forEach(btn => {
    btn.addEventListener('click', () => switchPage(btn.dataset.page));
  });
  
  const hash = window.location.hash.slice(1);
  const validPages = ['overview', 'gold', 'fx', 'relations', 'backtest', 'reports'];
  if (hash && validPages.includes(hash)) {
    switchPage(hash);
  }
  
  loadData();
  updateClock();
  setInterval(updateClock, 1000);
  setInterval(loadData, 300000);
});

function updateClock() {
  const now = new Date();
  const t = now.toLocaleTimeString('en-US', { hour12: false });
  document.getElementById('navTime').textContent = t;
}

/* ═══════════════════════════════════════════════════════════ */
/* DATA LOADER                                                 */
/* ═══════════════════════════════════════════════════════════ */
async function loadData() {
  try {
    document.getElementById('statusDot').className = 'status-dot warn';
    const r = await fetch('/api/data?ts=' + Date.now(), { cache: 'no-store' });
    const raw = await r.json();
    if (raw.status !== 'success') {
      document.getElementById('statusDot').className = 'status-dot err';
      return;
    }
    APP.data = deepFix(raw);
    APP.lastFetch = Date.now();
    
    document.getElementById('statusDot').className = 'status-dot';
    document.getElementById('lastUp').textContent = APP.data.last_update;
    document.getElementById('sbRegime').textContent = 'حالت بازار: ' + getRegimeLabel(APP.data);
    document.getElementById('sbSentiment').textContent = 'سنتیمنت: ' + (APP.data.sentiment?.alert_level || '--');
    
    const tradableCount = (APP.data.fx_scan?.setups || []).filter(s => ['A+', 'A', 'B'].includes(s.trade_quality)).length;
    const badge = document.getElementById('navBadgeFx');
    if (badge) {
      badge.textContent = tradableCount;
      badge.style.display = tradableCount > 0 ? 'inline-block' : 'none';
    }
    
    renderPage(APP.currentPage);
    
  } catch (e) {
    console.error(e);
    document.getElementById('statusDot').className = 'status-dot err';
  }
}

function getRegimeLabel(d) {
  const a = d.market_alert;
  if (!a || !a.level) return '--';
  if (a.level === 'HIGH') return 'پرنوسان';
  if (a.level === 'MEDIUM') return 'نوسان متوسط';
  return 'عادی';
}

async function doRefresh() {
  document.getElementById('lastUp').textContent = 'در حال بروزرسانی...';
  try {
    await fetch('/api/refresh');
    await loadData();
  } catch (e) { console.error(e); }
}

/* ═══════════════════════════════════════════════════════════ */
/* PAGE ROUTER                                                 */
/* ═══════════════════════════════════════════════════════════ */
function renderPage(pageName) {
  if (!APP.data) return;
  
  switch (pageName) {
    case 'overview':  renderOverview();   break;
    case 'gold':      renderGold();       break;
    case 'fx':        renderFX();         break;
    case 'relations': renderRelations();  break;
    case 'backtest':  renderBacktestDefault(); break;
    case 'reports':   renderReports();    break;
  }
}

/* ═══════════════════════════════════════════════════════════ */
/* PAGE 1: OVERVIEW                                            */
/* ═══════════════════════════════════════════════════════════ */
function renderOverview() {
  const d = APP.data;
  const c = d.current_prices;
  
  const kpiHtml = `
    <div class="kpi">
      <div class="kpi-label">انس جهانی</div>
      <div class="kpi-value">${fmtE(c.gold_oz_usd)}</div>
      <div class="kpi-sub"><span>USD/oz</span></div>
    </div>
    <div class="kpi">
      <div class="kpi-label">دلار آزاد</div>
      <div class="kpi-value">${fmt(c.usd_irr)}</div>
      <div class="kpi-sub"><span>تومان</span></div>
    </div>
    <div class="kpi">
      <div class="kpi-label">طلای ۱۸ عیار</div>
      <div class="kpi-value">${fmt(c.iran_gold_gram18)}</div>
      <div class="kpi-sub"><span>تومان/گرم</span></div>
    </div>
    <div class="kpi">
      <div class="kpi-label">DXY</div>
      <div class="kpi-value">${c.dxy_real ?? '--'}</div>
      <div class="kpi-sub"><span>شاخص دلار</span></div>
    </div>
    <div class="kpi">
      <div class="kpi-label">US10Y</div>
      <div class="kpi-value">${c.us10y ?? '--'}%</div>
      <div class="kpi-sub"><span>بازده اوراق</span></div>
    </div>
    <div class="kpi">
      <div class="kpi-label">VIX</div>
      <div class="kpi-value">${c.vix ?? '--'}</div>
      <div class="kpi-sub"><span>شاخص ترس</span></div>
    </div>
  `;
  document.getElementById('ovKpiGrid').innerHTML = kpiHtml;
  
  renderMarketAlerts(d.market_alert);

  const regimeSignal = (d.prediction?.signals || []).find(s => s.includes('روند')) || 'رژیم معاملاتی صعودی ملایم';
  document.getElementById('ovRegimeInfo').innerHTML = `
    <div style="font-size:11.5px;color:var(--text);line-height:1.8">
      ${regimeSignal}
    </div>
    <div style="margin-top:8px;font-size:10px;color:var(--muted)">
      سطح اطمینان مدل ترکیبی: <b style="color:var(--accent)">${d.prediction?.confidence || '--'}%</b><br>
      بایاس کلی روند انس: <b style="color:var(--up)">${d.prediction?.trend || '--'}</b>
    </div>
  `;
  
  const setups = d.fx_scan?.setups || [];
  const topSetups = setups.filter(s => ['A+', 'A', 'B'].includes(s.trade_quality)).slice(0, 5);
  if (topSetups.length > 0) {
    document.getElementById('ovTopSetups').innerHTML = topSetups.map(s => `
      <div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--border);font-size:11px">
        <span><b>${s.symbol}</b> <span class="badge badge-grade-${s.trade_quality.toLowerCase().replace('+','-plus')}">${s.trade_quality}</span></span>
        <span style="color:${s.bias === 'long' ? 'var(--up)' : 'var(--down)'}">${s.bias === 'long' ? '↑ خرید (LONG)' : '↓ فروش (SHORT)'}</span>
        <span style="font-variant-numeric:tabular-nums;color:var(--text-2)">R:R = 1:${s.risk_reward}</span>
      </div>
    `).join('');
  } else {
    document.getElementById('ovTopSetups').innerHTML = '<div class="loading" style="padding:20px">هیچ ستاپ معتبری امروز صادر نشده است</div>';
  }
  
  const s = d.sentiment;
  if (s && s.available) {
    document.getElementById('ovNewsSummary').innerHTML = `
      <div style="margin-bottom:8px;font-size:11px;display:flex;justify-content:space-between">
        <span>سنتیمنت کلی: <b style="color:${s.overall_score >= 0 ? 'var(--up)' : 'var(--down)'}">${s.overall_score}</b></span>
        <span>اخبار مانیتور شده: <b>${s.news_count} مورد</b></span>
      </div>
      ${(s.top_news || []).slice(0, 3).map(n => `
        <div style="padding:5px 0;border-bottom:1px solid var(--border);font-size:10px;text-overflow:ellipsis;overflow:hidden;white-space:nowrap">
          <span style="color:var(--muted)">[${n.source}]</span>
          <span style="color:var(--text-2)">${n.title}</span>
        </div>
      `).join('')}
    `;
  }
  
  drawMiniGold();
}

function renderMarketAlerts(a) {
  const h = document.getElementById('alertBanner');
  const m = document.getElementById('alertBannerMed');
  if (!a) { h.style.display = 'none'; m.style.display = 'none'; return; }

  if (a.level === 'HIGH') {
    h.style.display = 'block'; h.className = 'alert alert-danger';
    h.textContent = '⚠️ هشدار نوسان شدید در بازار: حرکت انس ' + a.gold_move + '% | تغییر دلار ' + a.usd_move + '%';
    m.style.display = 'none';
  } else if (a.level === 'MEDIUM') {
    m.style.display = 'block'; m.className = 'alert alert-warning';
    m.textContent = '⚡ نوسان متوسط در بازار: تغییر انس ' + a.gold_move + '% | دلار ' + a.usd_move + '%';
    h.style.display = 'none';
  } else {
    h.style.display = 'none'; m.style.display = 'none';
  }
}

function drawMiniGold() {
  const d = APP.data;
  const hist = d.gold_history;
  const p = d.prediction.gold_oz;
  
  if (APP.charts.ovGold) APP.charts.ovGold.destroy();
  
  const ctx = document.getElementById('ovChGoldMini');
  if (!ctx) return;
  
  const labels = [...hist.dates.slice(-30), ...d.prediction.target_dates];
  const real = [...hist.prices.slice(-30), ...Array(d.prediction.target_dates.length).fill(null)];
  const forecast = [...Array(29).fill(null), hist.prices[hist.prices.length - 1], ...p.daily];
  
  APP.charts.ovGold = new Chart(ctx.getContext('2d'), {
    type: 'line',
    data: {
      labels,
      datasets: [
        { label: 'قیمت واقعی', data: real, borderColor: '#5a7fb8', borderWidth: 2, tension: 0.3, pointRadius: 0, fill: false },
        { label: 'پیش‌بینی', data: forecast, borderColor: '#b8975a', borderWidth: 2, borderDash: [4,3], tension: 0.3, pointRadius: 2, fill: false }
      ]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { labels: { boxWidth: 10 }}},
      scales: {
        y: { ticks: { callback: v => v.toLocaleString() }, grid: { color: '#1e2630' }},
        x: { ticks: { callback: function(val) { return toShamsiShort(this.getLabelForValue(val)); }, maxTicksLimit: 10 }, grid: { color: '#1e2630' }}
      }
    }
  });
}

/* ═══════════════════════════════════════════════════════════ */
/* PAGE 2: GOLD & IRR                                          */
/* ═══════════════════════════════════════════════════════════ */
function renderGold() {
  const d = APP.data;
  const p = d.prediction;
  
  // Forecast Grid
  document.getElementById('goldPredGrid').innerHTML = `
    <div class="pred-cell">
      <div class="pred-title">انس جهانی (دلار)</div>
      <div class="pred-value">${fmtE(p.gold_oz.point)}</div>
      <div class="pred-trend" style="color:var(--up)">روند: ${p.trend}</div>
      <div class="pred-range">
        <span class="pred-lo">${fmtE(p.gold_oz.low)}</span><div class="pred-sep"></div><span class="pred-hi">${fmtE(p.gold_oz.high)}</span>
      </div>
    </div>
    <div class="pred-cell">
      <div class="pred-title">دلار آزاد (تومان)</div>
      <div class="pred-value">${fmt(p.usd_irr.point)}</div>
      <div class="pred-trend">اطمینان مدل: ${p.confidence}%</div>
      <div class="pred-range">
        <span class="pred-lo">${fmt(p.usd_irr.low)}</span><div class="pred-sep"></div><span class="pred-hi">${fmt(p.usd_irr.high)}</span>
      </div>
    </div>
    <div class="pred-cell">
      <div class="pred-title">طلای ۱۸ عیار</div>
      <div class="pred-value">${fmt(p.iran_gold.point)}</div>
      <div class="pred-trend">تومان / گرم</div>
      <div class="pred-range">
        <span class="pred-lo">${fmt(p.iran_gold.low)}</span><div class="pred-sep"></div><span class="pred-hi">${fmt(p.iran_gold.high)}</span>
      </div>
    </div>
    <div class="pred-cell">
      <div class="pred-title">سکه بهار آزادی</div>
      <div class="pred-value">${fmt(p.coin.point)}</div>
      <div class="pred-trend">تومان</div>
      <div class="pred-range">
        <span class="pred-lo">${fmt(p.coin.low)}</span><div class="pred-sep"></div><span class="pred-hi">${fmt(p.coin.high)}</span>
      </div>
    </div>
  `;
  
  // Signals List
  const sigList = d.prediction?.signals || [];
  document.getElementById('goldSignals').innerHTML = `
    <div class="signal-list">
      ${sigList.map(s => {
        const ss = stripSpecial(s);
        if(!ss) return '';
        return `<div class="signal-item">${ss}</div>`;
      }).join('')}
    </div>
  `;
  
  // Draw core charts
  drawForecastChart('chGold', d.gold_history, p.gold_oz, p.target_dates, '#5a7fb8', '#26a67a');
  drawForecastChart('chUSD', d.usd_history, p.usd_irr, p.target_dates, '#7c6fb8', '#c49a3c');
  drawForecastChart('chIran', d.iran_gold_history, p.iran_gold, p.target_dates, '#b85a5a', '#c49a3c');
  drawMethodsChart(p.method_weights);
}

function stripSpecial(str) {
  return str.replace(/[ \s]+/g, ' ').trim();
}

function drawForecastChart(id, hist, pred, pDates, c1, c2) {
  if (APP.charts[id]) APP.charts[id].destroy();
  
  const ctx = document.getElementById(id);
  if (!ctx) return;
  
  const labels = [...hist.dates, ...pDates];
  const lastReal = hist.prices[hist.prices.length - 1];
  const realData = [...hist.prices, ...Array(pDates.length).fill(null)];
  const forecastData = [...Array(hist.prices.length - 1).fill(null), lastReal, ...pred.daily];
  
  const upperBand = [...Array(hist.prices.length - 1).fill(null), lastReal, ...pred.daily.map((v, i) => {
    const t = (i+1) / pred.daily.length;
    return v + (pred.high - pred.low) * (0.15 + 0.85*t) / 2;
  })];
  
  const lowerBand = [...Array(hist.prices.length - 1).fill(null), lastReal, ...pred.daily.map((v, i) => {
    const t = (i+1) / pred.daily.length;
    return v - (pred.high - pred.low) * (0.15 + 0.85*t) / 2;
  })];

  APP.charts[id] = new Chart(ctx.getContext('2d'), {
    type: 'line',
    data: {
      labels,
      datasets: [
        { label: 'قیمت واقعی', data: realData, borderColor: c1, borderWidth: 2, tension: 0.25, pointRadius: 0, fill: false },
        { label: 'پیش‌بینی هالت/ترکیبی', data: forecastData, borderColor: c2, borderWidth: 2, borderDash: [6,4], tension: 0.25, pointRadius: 2, pointBackgroundColor: c2, fill: false },
        { label: 'H', data: upperBand, borderColor: 'transparent', backgroundColor: c2+'15', borderWidth: 0, fill: '+1', tension: 0.25, pointRadius: 0 },
        { label: 'L', data: lowerBand, borderColor: 'transparent', backgroundColor: 'transparent', borderWidth: 0, tension: 0.25, pointRadius: 0 }
      ]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      interaction: { intersect: false, mode: 'index' },
      plugins: {
        legend: { labels: { boxWidth: 10, filter: item => item.text !== 'H' && item.text !== 'L' }},
        tooltip: { callbacks: { label: c => { if (c.dataset.label==='H'||c.dataset.label==='L') return null; return c.dataset.label+': '+Number(c.parsed.y).toLocaleString(); }}}
      },
      scales: {
        y: { ticks: { callback: v => v.toLocaleString() }, grid: { color: '#1e2630' }},
        x: { ticks: { maxRotation: 45, maxTicksLimit: 14, callback: function(val) { return toShamsiShort(this.getLabelForValue(val)); } }, grid: { color: '#1e2630' }}
      }
    }
  });
}

function drawMethodsChart(w) {
  if (APP.charts.methods) APP.charts.methods.destroy();
  const ctx = document.getElementById('chMethods');
  if (!ctx) return;
  
  APP.charts.methods = new Chart(ctx.getContext('2d'), {
    type: 'bar',
    data: {
      labels: Object.keys(w).map(x => fixStr(x)),
      datasets: [{
        data: Object.values(w).map(v => (v*100).toFixed(1)),
        backgroundColor: ['#2563eb','#6366f1','#8b5cf6','#06b6d4','#f59e0b','#ef4444', '#10b981'],
        borderWidth: 0
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { display: false }},
      scales: {
        x: { ticks: { callback: v => v+'%' }, grid: { color: '#1e2630' }},
        y: { grid: { display: false }}
      }
    }
  });
}

/* ═══════════════════════════════════════════════════════════ */
/* PAGE 3: FX SCANNER                                          */
/* ═══════════════════════════════════════════════════════════ */
function renderFX() {
  const d = APP.data;
  const fx = d.fx_scan;
  
  if (!fx || !fx.available) {
    document.getElementById('fxSetups').innerHTML = '<div class="loading">اسکنر در دسترس نیست</div>';
    return;
  }
  
  // Strengths
  const currencyNames = {
    "EUR": "یورو", "USD": "دلار آمریکا", "GBP": "پوند انگلیس", "JPY": "ین ژاپن",
    "CHF": "فرانک سوئیس", "AUD": "دلار استرالیا", "CAD": "دلار کانادا", "NZD": "دلار نیوزیلند",
    "TRY": "لیر ترکیه", "CNY": "یوان چین", "INR": "روپیه هند", "BRL": "رئال برزیل", "RUB": "روبل روسیه"
  };
  
  document.getElementById('fxStrengths').innerHTML = fx.strengths.map(s => {
    const fillWidth = Math.max(5, Math.min(95, (s.score + 3.0) * 16.6));
    const barColor = s.score > 0.5 ? 'var(--up)' : s.score < -0.5 ? 'var(--down)' : 'var(--warn)';
    const numSign = s.score > 0 ? '+' : '';
    
    return `
      <div class="strength-bar">
        <div class="strength-header">
          <span class="strength-currency">${s.currency} <span class="strength-name">(${currencyNames[s.currency] || s.currency})</span></span>
          <span class="strength-score" style="color:${barColor}">${numSign}${s.score}</span>
        </div>
        <div class="strength-progress">
          <div class="strength-progress-fill" style="width:${fillWidth}%;background:${barColor}"></div>
        </div>
        <div class="strength-momentum">
          <span>۵ روزه: ${s.momentum_5d}%</span>
          <span>۲۰ روزه: ${s.momentum_20d}%</span>
        </div>
      </div>
    `;
  }).join('');
  
  // Setups
  const activeSetups = (fx.setups || []).filter(s => s.trade_quality !== 'No Trade');
  if (activeSetups.length === 0) {
    document.getElementById('fxSetups').innerHTML = '<div class="loading">امروز هیچ موقعیت معاملاتی معتبری صادر نشده است</div>';
  } else {
    document.getElementById('fxSetups').innerHTML = activeSetups.map(s => {
      const gradeColor = s.trade_quality === 'A+' ? '#10b981' : s.trade_quality === 'A' ? 'var(--up)' : s.trade_quality === 'B' ? 'var(--warn)' : 'var(--info)';
      const biasColor = s.bias === 'long' ? 'var(--up)' : 'var(--down)';
      const biasFa = s.bias === 'long' ? 'خرید (LONG)' : 'فروش (SHORT)';
      const typeFa = {'trend':'تعقیب روند','pullback':'پولبک به ساختار حمایتی','breakout':'شکست محدوده رنج','range':'نوسان‌گیری رنج'}[s.setup_type] || s.setup_type;
      
      return `
        <div class="setup-card">
          <div class="setup-header">
            <span class="setup-symbol">${s.symbol} <span style="font-size:9.5px;color:var(--muted)">(${currencyNames[s.base] || s.base}/${currencyNames[s.quote] || s.quote})</span></span>
            <span class="badge badge-grade-${s.trade_quality.toLowerCase().replace('+','-plus')}">کلاس ${s.trade_quality}</span>
          </div>
          <div class="setup-body">
            <div class="setup-row"><span class="setup-label">سیگنال ترید:</span><b style="color:${biasColor}">${biasFa}</b></div>
            <div class="setup-row"><span class="setup-label">نوع استراتژی:</span><b>${typeFa}</b></div>
            <div class="setup-row"><span class="setup-label">همگرایی چندتایم‌فریمی:</span><b style="color:var(--accent)">${Math.round(s.mtf_confluence * 100)}%</b></div>
            <div class="setup-row"><span class="setup-label">محدوده ورود پیشنهادی:</span><b style="font-variant-numeric:tabular-nums">${s.entry_low} - ${s.entry_high}</b></div>
            <div class="setup-row"><span class="setup-label">حد سود اول (TP1):</span><b style="color:var(--up)">${s.target1}</b></div>
            <div class="setup-row"><span class="setup-label">حد سود دوم (TP2):</span><b style="color:var(--accent)">${s.target2}</b></div>
            <div class="setup-row"><span class="setup-label">حد ضرر (Stop Loss):</span><b style="color:var(--down)">${s.stop_loss}</b></div>
            <div class="setup-row" style="border-top:1px solid var(--border);padding-top:4px;margin-top:4px"><span class="setup-label">ریسک به ریوارد (R:R):</span><b>1 : ${s.risk_reward}</b></div>
          </div>
          <div class="setup-reasons">
            <div style="font-weight:600;margin-bottom:4px;color:var(--text)">محرک‌های تایید پوزیشن (Triggers):</div>
            ${(s.reasons_for || []).map(r => `<div class="setup-reason-item good">✓ ${r}</div>`).join('')}
            ${(s.reasons_against || []).length > 0 ? `
              <div style="font-weight:600;margin:6px 0 4px;color:var(--text)">ریسک‌ها و فیلترها:</div>
              ${(s.reasons_against || []).map(r => `<div class="setup-reason-item bad">⚠ ${r}</div>`).join('')}
            ` : ''}
          </div>
        </div>
      `;
    }).join('');
  }
  
  document.getElementById('fxReport').textContent = fx.report;
}

/* ═══════════════════════════════════════════════════════════ */
/* PAGE 4: RELATIONSHIPS                                       */
/* ═══════════════════════════════════════════════════════════ */
function renderRelations() {
  const d = APP.data;
  const c = d.current_prices;
  const rel = d.relationships;
  
  // Macro KPI
  document.getElementById('macroKpi').innerHTML = `
    <div class="kpi">
      <div class="kpi-label">DXY (شاخص دلار)</div>
      <div class="kpi-value">${c.dxy_real ?? '--'}</div>
    </div>
    <div class="kpi">
      <div class="kpi-label">US10Y (اوراق قرضه)</div>
      <div class="kpi-value">${c.us10y ?? '--'}%</div>
    </div>
    <div class="kpi">
      <div class="kpi-label">VIX (شاخص نوسان)</div>
      <div class="kpi-value">${c.vix ?? '--'}</div>
    </div>
    <div class="kpi">
      <div class="kpi-label">رویدادهای فارکس پیش رو</div>
      <div class="kpi-value">${d.events?.length || 0} رویداد</div>
    </div>
  `;
  
  // Relationship Map
  if (rel && rel.available) {
    let rHtml = `
      <div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:8px">
        <div class="kpi" style="flex:1"><div class="kpi-label">Leading Assets (پیش‌رو)</div><div style="font-size:11px;margin-top:4px">${rel.leading_assets.map(a=>`<span class="badge badge-up" style="margin:1px">${a}</span>`).join('')}</div></div>
        <div class="kpi" style="flex:1"><div class="kpi-label">Lagging Assets (پس‌رو)</div><div style="font-size:11px;margin-top:4px">${rel.lagging_assets.map(a=>`<span class="badge badge-down" style="margin:1px">${a}</span>`).join('')}</div></div>
      </div>
      <div class="tbl-wrap"><table>
        <thead><tr>
          <th>دارایی متقابل</th><th>پیرسون 20d</th><th>پیرسون 60d</th><th>Lead / Lag</th><th>همبستگی تأخیری</th><th>بتا 30d</th><th>مستقل (Partial)</th><th>جهت</th><th>تأثیر کل</th>
        </tr></thead><tbody>
    `;
    for (const r of rel.relations) {
      const pc = r.pearson_20d > 0.4 ? 'pos' : r.pearson_20d < -0.4 ? 'neg' : '';
      const l_style = r.lead_lag_days > 0 ? 'class="pos"' : r.lead_lag_days < 0 ? 'class="neg"' : '';
      const l_txt = r.lead_lag_days > 0 ? `+${r.lead_lag_days} روز پیش‌رو` : r.lead_lag_days < 0 ? `${r.lead_lag_days} روز پس‌رو` : 'همزمان';
      const depPct = Math.round(r.dep_score * 100);
      const depColor = depPct > 40 ? 'var(--accent)' : depPct > 20 ? 'var(--info)' : 'var(--muted)';
      
      rHtml += `
        <tr>
          <td><b>${r.asset_b}</b></td>
          <td class="${pc}">${r.pearson_20d}</td>
          <td>${r.pearson_60d}</td>
          <td ${l_style}>${l_txt}</td>
          <td>${r.lead_lag_corr}</td>
          <td>${r.beta_30d}</td>
          <td class="${r.partial_corr > 0.3 ? 'pos' : r.partial_corr < -0.3 ? 'neg' : ''}">${r.partial_corr}</td>
          <td>${r.direction === 'strong_positive' ? 'مستقیم صعودی' : r.direction === 'strong_negative' ? 'معکوس نزولی' : 'خنثی'}</td>
          <td>
            <div style="background:var(--border);height:14px;border-radius:2px;overflow:hidden;position:relative">
              <div style="background:${depColor};width:${depPct}%;height:100%;opacity:0.75"></div>
              <span style="position:absolute;right:4px;top:0;font-size:9px;color:var(--text)">${depPct}%</span>
            </div>
          </td>
        </tr>
      `;
    }
    rHtml += '</tbody></table></div>';
    document.getElementById('relMap').innerHTML = rHtml;
  }
  
  // Correlations standard table
  document.getElementById('corrTbl').innerHTML = d.correlations.map((c, i) => `
    <tr>
      <td>${i+1}</td><td><b>${c.symbol}</b></td><td>${c.name_fa}</td>
      <td class="${c.pearson>0?'pos':'neg'}">${c.pearson}</td>
      <td class="${c.spearman>0?'pos':'neg'}">${c.spearman}</td>
      <td>${c.beta}</td>
      <td>${(c.r_squared*100).toFixed(1)}%</td>
      <td class="${c.granger_f>3?'pos':''}">${c.granger_f}</td>
      <td>${c.cointegration}</td>
      <td>
        <div style="background:var(--border);height:12px;border-radius:2px;overflow:hidden;position:relative">
          <div style="background:var(--info);width:${Math.round(c.impact_score*100)}%;height:100%;opacity:0.75"></div>
          <span style="position:absolute;right:4px;top:-2px;font-size:8.5px">${(c.impact_score*100).toFixed(1)}%</span>
        </div>
      </td>
      <td>${c.direction}</td>
    </tr>
  `).join('');
}

/* ═══════════════════════════════════════════════════════════ */
/* PAGE 5: BACKTEST & VALIDATION                               */
/* ═══════════════════════════════════════════════════════════ */
function renderBacktestDefault() {
  loadBacktest(240);
  
  const d = APP.data;
  const wf = d.walk_forward;
  if (wf) {
    const items = [
      {key:'gold_h1', label:'انس ۱ روزه'}, {key:'gold_h3', label:'انس ۳ روزه'}, {key:'gold_h7', label:'انس ۷ روزه'},
      {key:'usd_h1',  label:'دلار ۱ روزه'}, {key:'usd_h3',  label:'دلار ۳ روزه'},
      {key:'iran_h1', label:'طلا۱۸ ۱ روزه'}, {key:'iran_h3', label:'طلا۱۸ ۳ روزه'}
    ];
    let html = '<div class="grid grid-auto">';
    for (const item of items) {
      const wfd = wf[item.key];
      if (!wfd) continue;
      const mapeColor = wfd.mape < 1.5 ? 'var(--up)' : wfd.mape < 2.5 ? 'var(--warn)' : 'var(--down)';
      const dirColor = wfd.direction >= 55 ? 'var(--up)' : 'var(--down)';
      html += `
        <div class="kpi" style="padding:10px 12px">
          <div class="kpi-label">${item.label} (${wfd.count} نمونه)</div>
          <div style="font-size:10px;color:var(--text-2);margin-top:4px">
            <div>MAPE میانگین: <b style="color:${mapeColor}">${wfd.mape}%</b></div>
            <div>صحت جهت: <b style="color:${dirColor}">${wfd.direction}%</b></div>
            <div>میانه خطا: <b>${wfd.median_error}%</b></div>
            <div>بهترین خطا: <span style="color:var(--up)">${wfd.best_error}%</span></div>
            <div>بدترین خطا: <span style="color:var(--down)">${wfd.worst_error}%</span></div>
          </div>
        </div>
      `;
    }
    html += '</div>';
    document.getElementById('wfStats').innerHTML = html;
  }
}

function drawBacktest(id, data, c1, c2, pred, pDates) {
  const canvas = document.getElementById(id);
  if (!canvas) return;
  if (APP.charts[id]) APP.charts[id].destroy();

  const labels = data.map(r => r.date);
  
  APP.charts[id] = new Chart(canvas.getContext('2d'), {
    type: 'line',
    data: {
      labels,
      datasets: [
        { label: 'قیمت واقعی', data: data.map(r => r.actual), borderColor: c1, borderWidth: 2, tension: 0.25, pointRadius: 1, fill: false },
        { label: 'پیش‌بینی مدل', data: data.map(r => r.predicted), borderColor: c2, borderWidth: 1.5, borderDash: [4,3], tension: 0.25, pointRadius: 1, fill: false }
      ]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      interaction: { intersect: false, mode: 'index' },
      plugins: {
        legend: { labels: { boxWidth: 10 } },
        tooltip: {
          callbacks: {
            label: c => {
              const e = data[c.dataIndex].error;
              return c.dataset.label + ': ' + Number(c.parsed.y).toLocaleString() + ' (خطا: ' + e + '%)';
            }
          }
        }
      },
      scales: {
        y: { ticks: { callback: v => v.toLocaleString() }, grid: { color: '#1e2630' } },
        x: { ticks: { maxRotation: 45, maxTicksLimit: 14, callback: function(val) { return toShamsiShort(this.getLabelForValue(val)); } }, grid: { color: '#1e2630' } }
      }
    }
  });
}

async function loadBacktest(days) {
  document.querySelectorAll('#btRangeBtns .btn').forEach(b => b.classList.remove('active'));
  const activeBtn = document.querySelector(`#btRangeBtns .btn[data-days="${days}"]`);
  if (activeBtn) activeBtn.classList.add('active');
  
  document.getElementById('btStats').innerHTML = '<div class="loading">در حال محاسبه بک‌تست...</div>';
  try {
    const r = await fetch('/api/backtest?days=' + days + '&ts=' + Date.now(), { cache: 'no-store' });
    const bt = await r.json();
    if (bt.status !== 'success') return;
    
    document.getElementById('btStats').innerHTML = `
      <div class="kpi-grid" style="grid-template-columns:repeat(6,1fr)">
        <div class="kpi"><div class="kpi-label">دوره</div><div class="kpi-value">${bt.test_days} روز</div></div>
        <div class="kpi"><div class="kpi-label">MAPE انس</div><div class="kpi-value">${bt.gold_mape}%</div></div>
        <div class="kpi"><div class="kpi-label">MAPE دلار</div><div class="kpi-value">${bt.usd_mape}%</div></div>
        <div class="kpi"><div class="kpi-label">MAPE طلا۱۸</div><div class="kpi-value">${bt.iran_mape}%</div></div>
        <div class="kpi"><div class="kpi-label">جهت انس</div><div class="kpi-value">${bt.gold_direction}%</div></div>
        <div class="kpi"><div class="kpi-label">جهت دلار</div><div class="kpi-value">${bt.usd_direction}%</div></div>
      </div>
    `;
    
    // Draw charts
    if (bt.gold && bt.gold.length > 0) drawBacktest('chBtGold', bt.gold, '#5a7fb8', '#26a67a');
    if (bt.usd && bt.usd.length > 0) drawBacktest('chBtUSD', bt.usd, '#7c6fb8', '#c49a3c');
    if (bt.iran && bt.iran.length > 0) drawBacktest('chBtIran', bt.iran, '#b85a5a', '#c49a3c');
    
  } catch (e) { console.error(e); }
}

/* ═══════════════════════════════════════════════════════════ */
/* PAGE 6: REPORTS                                             */
/* ═══════════════════════════════════════════════════════════ */
function renderReports() {
  const d = APP.data;
  if (!d) return;
  const el = document.getElementById('systemSummary');
  if (!el) return;
  el.innerHTML = `
    <div>• تاریخچه داده‌های انس و ارز: <b>${d.gold_history?.prices?.length || 0} روز معاملاتی</b></div>
    <div>• تعداد جفت‌ارزهای فعال در اسکنر: <b>${d.fx_scan?.setups?.length || 0} جفت‌ارز</b></div>
    <div>• ستاپ‌های ترید باکیفیت امروز (A+/A/B): <b>${(d.fx_scan?.setups || []).filter(s => ['A+','A','B'].includes(s.trade_quality)).length} مورد</b></div>
    <div>• روابط و همبستگی‌های محاسبه شده بین‌بازاری: <b>${d.relationships?.relations?.length || 0} جفت</b></div>
    <div>• ضریب اطمینان مدل پیش‌بینی طلا: <b>${d.prediction?.confidence || '--'}%</b></div>
    <div>• وضعیت فعلی رژیم بازار: <b>${d.prediction?.trend || '--'}</b></div>
  `;
}
"""

p.write_text(full_code, encoding="utf-8")
print("[OK] app.js completely and robustly rewrote with all functions.")
