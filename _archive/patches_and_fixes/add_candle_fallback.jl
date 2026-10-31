content = read("templates/index.html", String)

fallback_fn = raw"""
function drawForecastLineFallback(id,hist,pred,pDates,c1,c2){
  const ctx=document.getElementById(id).getContext('2d');
  if(id==='chGold'&&cG){cG.destroy();cG=null;}
  if(id==='chUSD'&&cU){cU.destroy();cU=null;}
  if(id==='chIran'&&cI){cI.destroy();cI=null;}

  const lastReal=hist.prices[hist.prices.length-1];
  const labels=[...hist.dates,...pDates];
  const realData=[...hist.prices,...Array(pDates.length).fill(null)];
  const forecastData=[...Array(hist.dates.length-1).fill(null),lastReal,...pred.daily];

  const chart=new Chart(ctx,{
    type:'line',
    data:{
      labels,
      datasets:[
        {label:'قیمت واقعی',data:realData,borderColor:c1,backgroundColor:'transparent',borderWidth:1.8,tension:.3,pointRadius:0},
        {label:'پیش‌بینی',data:forecastData,borderColor:c2,backgroundColor:c2+'18',borderWidth:2.2,borderDash:[5,4],fill:true,tension:.3,pointRadius:2}
      ]
    },
    options:{
      responsive:true,
      interaction:{intersect:false,mode:'index'},
      plugins:{legend:{labels:{boxWidth:10}}},
      scales:{
        y:{ticks:{callback:v=>v.toLocaleString()},grid:{color:'#1e2028'}},
        x:{ticks:{maxRotation:45,maxTicksLimit:12},grid:{color:'#1e2028'}}
      }
    }
  });

  if(id==='chGold')cG=chart; else if(id==='chUSD')cU=chart; else cI=chart;
}
"""

if !occursin("function drawForecastLineFallback", content)
    content = replace(content, "function drawForecast(id,hist,pred,pDates,c1,c2){" => fallback_fn * "\nfunction drawForecast(id,hist,pred,pDates,c1,c2){")
end

content = replace(
    content,
    "const chart=new Chart(ctx,{",
    """if(!(Chart.registry && Chart.registry.controllers && (Chart.registry.controllers.get && Chart.registry.controllers.get('candlestick')))){
    return drawForecastLineFallback(id,hist,pred,pDates,c1,c2);
  }

  const chart=new Chart(ctx,{"""
)

write("templates/index.html", content)
println("Fallback added")
