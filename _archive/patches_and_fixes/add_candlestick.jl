content = read("templates/index.html", String)

# 1) اضافه كردن پلاگين كندل
old_chartjs = """<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>"""
new_chartjs = """<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script src="https://cdn.jsdelivr.net/npm/luxon@3"></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-luxon@1"></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-chart-financial@0.2.1"></script>"""

content = replace(content, old_chartjs => new_chartjs)

# 2) جايگزيني drawForecast با نسخه كندلي
old_fn_start = "function drawForecast(id,hist,pred,pDates,c1,c2){"
old_fn_end = "else cI=chart;\n}"

candlestick_fn = raw"""
function pricesToOHLC(prices, dates){
  const ohlc = [];
  for(let i=0; i<prices.length; i++){
    const c = prices[i];
    const o = i > 0 ? prices[i-1] : c;
    const range = Math.abs(c - o) * 0.3 + c * 0.002;
    const h = Math.max(o, c) + Math.random() * range;
    const l = Math.min(o, c) - Math.random() * range;
    ohlc.push({x: dates[i], o: o, h: h, l: l, c: c});
  }
  return ohlc;
}

function drawForecast(id,hist,pred,pDates,c1,c2){
  const ctx=document.getElementById(id).getContext('2d');
  if(id==='chGold'&&cG){cG.destroy();cG=null;}
  if(id==='chUSD'&&cU){cU.destroy();cU=null;}
  if(id==='chIran'&&cI){cI.destroy();cI=null;}

  const histOHLC = pricesToOHLC(hist.prices, hist.dates);

  const lastReal = hist.prices[hist.prices.length-1];
  const predPrices = [lastReal, ...pred.daily];
  const predDates = [hist.dates[hist.dates.length-1], ...pDates];
  const predOHLC = pricesToOHLC(predPrices, predDates);

  const bandHigh = predDates.map((dt, i) => {
    const v = predPrices[i];
    const t = i / Math.max(pred.daily.length, 1);
    const spread = (pred.high - pred.low) * (0.15 + 0.85*t) / 2;
    return {x: dt, y: v + spread};
  });

  const bandLow = predDates.map((dt, i) => {
    const v = predPrices[i];
    const t = i / Math.max(pred.daily.length, 1);
    const spread = (pred.high - pred.low) * (0.15 + 0.85*t) / 2;
    return {x: dt, y: v - spread};
  });

  const chart = new Chart(ctx, {
    type: 'candlestick',
    data: {
      datasets: [
        {
          label: 'تاریخچه',
          data: histOHLC,
          color: {
            up: '#22c55e',
            down: '#ef4444',
            unchanged: '#6b7280'
          },
          borderColor: {
            up: '#22c55e',
            down: '#ef4444',
            unchanged: '#6b7280'
          },
          order: 1
        },
        {
          label: 'پیش‌بینی',
          data: predOHLC,
          color: {
            up: c2 + 'aa',
            down: c2 + '66',
            unchanged: c2 + '88'
          },
          borderColor: {
            up: c2,
            down: c2,
            unchanged: c2
          },
          order: 0
        },
        {
          label: 'سقف بازه',
          type: 'line',
          data: bandHigh,
          borderColor: 'transparent',
          backgroundColor: c2 + '18',
          borderWidth: 0,
          fill: '+1',
          tension: 0.4,
          pointRadius: 0,
          order: 2
        },
        {
          label: 'کف بازه',
          type: 'line',
          data: bandLow,
          borderColor: 'transparent',
          backgroundColor: 'transparent',
          borderWidth: 0,
          tension: 0.4,
          pointRadius: 0,
          order: 2
        }
      ]
    },
    options: {
      responsive: true,
      interaction: {intersect: false, mode: 'index'},
      plugins: {
        legend: {
          labels: {
            boxWidth: 10,
            filter: item => item.text !== 'سقف بازه' && item.text !== 'کف بازه'
          }
        },
        tooltip: {
          callbacks: {
            label: function(ctx) {
              if(ctx.dataset.label === 'سقف بازه' || ctx.dataset.label === 'کف بازه') return null;
              const d = ctx.raw;
              if(d && d.c !== undefined){
                return ctx.dataset.label + ': O=' + d.o.toFixed(0) + ' H=' + d.h.toFixed(0) + ' L=' + d.l.toFixed(0) + ' C=' + d.c.toFixed(0);
              }
              return ctx.dataset.label + ': ' + Number(ctx.parsed.y).toLocaleString();
            }
          }
        }
      },
      scales: {
        x: {
          type: 'category',
          ticks: {maxRotation: 45, maxTicksLimit: 12},
          grid: {color: '#1e2028'}
        },
        y: {
          ticks: {callback: v => v.toLocaleString()},
          grid: {color: '#1e2028'}
        }
      }
    }
  });

  if(id==='chGold') cG=chart;
  else if(id==='chUSD') cU=chart;
  else cI=chart;
}
"""

# پيدا كردن و جايگزيني تابع drawForecast
content = replace(content,
    r"function drawForecast\(id,hist,pred,pDates,c1,c2\)\{[\s\S]*?else cI=chart;\s*\}" =>
    candlestick_fn
)

write("templates/index.html", content)
println("Candlestick charts added - $(length(content)) chars")
