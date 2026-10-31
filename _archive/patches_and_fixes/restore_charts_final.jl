content = read("templates/index.html", String)

content = replace(content,
    """<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.3/dist/chart.umd.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/luxon@3/build/global/luxon.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-luxon@1.3.1"></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-chart-financial@0.2.1/dist/chartjs-chart-financial.min.js"></script>""" =>
    """<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>"""
)

new_draw = raw"""
function drawForecast(id,hist,pred,pDates,c1,c2){
  const canvas=document.getElementById(id);
  if(!canvas)return;
  const ctx=canvas.getContext('2d');

  if(id==='chGold'&&cG){cG.destroy();cG=null;}
  if(id==='chUSD'&&cU){cU.destroy();cU=null;}
  if(id==='chIran'&&cI){cI.destroy();cI=null;}

  const labels=[...hist.dates,...pDates];
  const lastReal=hist.prices[hist.prices.length-1];
  const realData=[...hist.prices,...Array(pDates.length).fill(null)];
  const forecastData=[...Array(hist.prices.length-1).fill(null),lastReal,...pred.daily];

  const upperBand=[...Array(hist.prices.length-1).fill(null),lastReal,...pred.daily.map((v,i)=>{
    const t=(i+1)/Math.max(pred.daily.length,1);
    return v+(pred.high-pred.low)*(0.15+0.85*t)/2;
  })];
  const lowerBand=[...Array(hist.prices.length-1).fill(null),lastReal,...pred.daily.map((v,i)=>{
    const t=(i+1)/Math.max(pred.daily.length,1);
    return v-(pred.high-pred.low)*(0.15+0.85*t)/2;
  })];

  const chart=new Chart(ctx,{
    type:'line',
    data:{labels,datasets:[
      {label:'قیمت واقعی',data:realData,borderColor:c1,backgroundColor:'transparent',borderWidth:2,tension:.25,pointRadius:0,order:2},
      {label:'پیش‌بینی',data:forecastData,borderColor:c2,backgroundColor:'transparent',borderWidth:2,borderDash:[6,4],tension:.25,pointRadius:2,pointBackgroundColor:c2,order:1},
      {label:'H',data:upperBand,borderColor:'transparent',backgroundColor:c2+'20',borderWidth:0,fill:'+1',tension:.25,pointRadius:0,order:3},
      {label:'L',data:lowerBand,borderColor:'transparent',backgroundColor:'transparent',borderWidth:0,tension:.25,pointRadius:0,order:3}
    ]},
    options:{
      responsive:true,
      maintainAspectRatio:false,
      interaction:{intersect:false,mode:'index'},
      plugins:{
        legend:{labels:{boxWidth:10,filter:item=>item.text!=='H'&&item.text!=='L'}},
        tooltip:{callbacks:{label:c=>{if(c.dataset.label==='H'||c.dataset.label==='L')return null;return c.dataset.label+': '+Number(c.parsed.y).toLocaleString();}}}
      },
      scales:{
        y:{ticks:{callback:v=>v.toLocaleString()},grid:{color:'#1e2028'}},
        x:{ticks:{maxRotation:45,maxTicksLimit:12},grid:{color:'#1e2028'}}
      }
    }
  });

  if(id==='chGold')cG=chart;else if(id==='chUSD')cU=chart;else cI=chart;
}
"""

content = replace(content,
    r"(?:function drawForecastLineFallback[\s\S]*?)?function drawForecast\(id,hist,pred,pDates,c1,c2\)\{[\s\S]*?(?=function drawBacktest)" =>
    new_draw * "\n\n"
)

write("templates/index.html", content)
println("charts restored - $(length(content)) chars")
