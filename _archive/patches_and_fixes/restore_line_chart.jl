content = read("templates/index.html", String)

new_draw = raw"""
function drawForecast(id,hist,pred,pDates,c1,c2){
  const canvas = document.getElementById(id);
  if(!canvas) return;
  const ctx = canvas.getContext('2d');

  if(id==='chGold'&&cG){cG.destroy();cG=null;}
  if(id==='chUSD'&&cU){cU.destroy();cU=null;}
  if(id==='chIran'&&cI){cI.destroy();cI=null;}

  const labels = [...hist.dates, ...pDates];
  const lastReal = hist.prices[hist.prices.length-1];

  const realData = [...hist.prices, ...Array(pDates.length).fill(null)];
  const forecastData = [...Array(hist.prices.length-1).fill(null), lastReal, ...pred.daily];

  const upperBand = [...Array(hist.prices.length-1).fill(null), lastReal, ...pred.daily.map((v,i)=>{
    const t = (i+1)/Math.max(pred.daily.length,1);
    return v + (pred.high - pred.low) * (0.15 + 0.85*t) / 2;
  })];

  const lowerBand = [...Array(hist.prices.length-1).fill(null), lastReal, ...pred.daily.map((v,i)=>{
    const t = (i+1)/Math.max(pred.daily.length,1);
    return v - (pred.high - pred.low) * (0.15 + 0.85*t) / 2;
  })];

  const chart = new Chart(ctx,{
    type:'line',
    data:{
      labels: labels,
      datasets:[
        {
          label:'قیمت واقعی',
          data: realData,
          borderColor: c1,
          backgroundColor: 'transparent',
          borderWidth: 2,
          tension: 0.25,
          pointRadius: 0,
          order: 2
        },
        {
          label:'پیش‌بینی',
          data: forecastData,
          borderColor: c2,
          backgroundColor: 'transparent',
          borderWidth: 2,
          borderDash: [6,4],
          tension: 0.25,
          pointRadius: 2,
          pointBackgroundColor: c2,
          order: 1
        },
        {
          label:'سقف بازه',
          data: upperBand,
          borderColor: 'transparent',
          backgroundColor: c2 + '22',
          borderWidth: 0,
          fill: '+1',
          tension: 0.25,
          pointRadius: 0,
          order: 3
        },
        {
          label:'کف بازه',
          data: lowerBand,
          borderColor: 'transparent',
          backgroundColor: 'transparent',
          borderWidth: 0,
          tension: 0.25,
          pointRadius: 0,
          order: 3
        }
      ]
    },
    options:{
      responsive:true,
      maintainAspectRatio:false,
      interaction:{intersect:false,mode:'index'},
      plugins:{
        legend:{
          labels:{
            boxWidth:10,
            filter:item => item.text!=='سقف بازه' && item.text!=='کف بازه'
          }
        },
        tooltip:{
          callbacks:{
            label:(ctx)=>{
              if(ctx.dataset.label==='سقف بازه' || ctx.dataset.label==='کف بازه') return null;
              const v = ctx.parsed.y;
              return ctx.dataset.label + ': ' + Number(v).toLocaleString();
            }
          }
        }
      },
      scales:{
        y:{
          ticks:{callback:v=>v.toLocaleString()},
          grid:{color:'#1e2028'}
        },
        x:{
          ticks:{maxRotation:45,maxTicksLimit:12},
          grid:{color:'#1e2028'}
        }
      }
    }
  });

  if(id==='chGold') cG=chart;
  else if(id==='chUSD') cU=chart;
  else cI=chart;
}
"""

content = replace(content,
    r"function drawForecast\(id,hist,pred,pDates,c1,c2\)\{[\s\S]*?function drawBacktest" =>
    new_draw * "\n\nfunction drawBacktest"
)

write("templates/index.html", content)
println("drawForecast reverted to stable line chart")
