content = read("templates/index.html", String)

render_fn = raw"""
function renderUI(d){
  document.getElementById('statusDot').className='status-dot';
  document.getElementById('lastUp').textContent=d.last_update;

  const c=d.current_prices;
  document.getElementById('cpGold').textContent=fmtE(c.gold_oz_usd);
  document.getElementById('cpMA20').textContent=fmtE(c.gold_oz_ma20);
  document.getElementById('cpMA50').textContent=fmtE(c.gold_oz_ma50);
  document.getElementById('cpIran').textContent=fmt(c.iran_gold_gram18);
  document.getElementById('cpUSD').textContent=fmt(c.usd_irr);
  document.getElementById('cpRSI').textContent=c.gold_oz_rsi?Number(c.gold_oz_rsi).toFixed(1):'--';
  document.getElementById('cpVol').textContent=c.gold_oz_volatility?Number(c.gold_oz_volatility).toFixed(1)+'%':'--';
  document.getElementById('cpFG').textContent=c.fear_greed?Number(c.fear_greed).toFixed(1):'--';

  const rsiEl=document.getElementById('cpRSI');
  rsiEl.className='ind-val '+(c.gold_oz_rsi>70?'red':c.gold_oz_rsi<30?'green':'yellow');

  document.getElementById('mcDXY').textContent=c.dxy_real??'--';
  document.getElementById('mcUS10Y').textContent=c.us10y?(c.us10y+'%'):'--';
  document.getElementById('mcVIX').textContent=c.vix??'--';
  document.getElementById('mcEvents').textContent=d.events?(d.events.length+' رویداد'):'--';

  const p=d.prediction;
  document.getElementById('prGold').textContent=fmtE(p.gold_oz.point);
  document.getElementById('prGoldLo').textContent=fmtE(p.gold_oz.low);
  document.getElementById('prGoldHi').textContent=fmtE(p.gold_oz.high);
  document.getElementById('prConf').textContent=p.confidence+'%';
  document.getElementById('prIran').textContent=fmt(p.iran_gold.point);
  document.getElementById('prIranLo').textContent=fmt(p.iran_gold.low);
  document.getElementById('prIranHi').textContent=fmt(p.iran_gold.high);
  document.getElementById('prCoin').textContent=fmt(p.coin.point);
  document.getElementById('prCoinLo').textContent=fmt(p.coin.low);
  document.getElementById('prCoinHi').textContent=fmt(p.coin.high);
  document.getElementById('prUSD').textContent=fmt(p.usd_irr.point);
  document.getElementById('prUSDLo').textContent=fmt(p.usd_irr.low);
  document.getElementById('prUSDHi').textContent=fmt(p.usd_irr.high);

  const d1g = (p.gold_oz.daily && c.gold_oz_usd) ? ((p.gold_oz.daily[0]-c.gold_oz_usd)/c.gold_oz_usd*100).toFixed(2) : '--';
  document.getElementById('prTrend').textContent=trendLabel(parseFloat(d1g))+' | تغییر روز اول: '+d1g+'%';

  document.getElementById('sbRegime').textContent=marketStateLabel(d.market_alert);

  renderMarketAlert(d.market_alert);
  renderSentiment(d.sentiment);

  document.getElementById('sigList').innerHTML=buildSignals(d).map(s=>'<div class="sig-item">'+s+'</div>').join('');

  document.getElementById('corrTbl').innerHTML=d.correlations.map((c,i)=>`
    <tr>
      <td>${i+1}</td><td><b>${c.symbol}</b></td><td>${c.name_fa}</td>
      <td class="${c.pearson>0?'pos':'neg'}">${c.pearson}</td>
      <td class="${c.spearman>0?'pos':'neg'}">${c.spearman}</td>
      <td>${c.beta}</td>
      <td>${(c.r_squared*100).toFixed(1)}%</td>
      <td class="${c.granger_f>3?'sig':''}">${c.granger_f}</td>
      <td>${c.cointegration}</td>
      <td><div class="impact-bar"><div class="impact-fill" style="width:${Math.round(c.impact_score*100)}%"></div><span>${(c.impact_score*100).toFixed(1)}%</span></div></td>
      <td>${c.direction}</td>
    </tr>
  `).join('');

  drawForecast('chGold',d.gold_history,p.gold_oz,p.target_dates,'#2563eb','#22c55e');
  drawForecast('chUSD',d.usd_history,p.usd_irr,p.target_dates,'#6366f1','#f59e0b');
  drawForecast('chIran',d.iran_gold_history,p.iran_gold,p.target_dates,'#dc2626','#f97316');
  drawMethods(p.method_weights);

  const bt=d.backtest;
  if(bt && bt.total_days>0){
    document.getElementById('btStats').innerHTML=`
      <div class="bt-stats-grid">
        <div class="bt-stat"><span class="bt-label">دوره</span><span class="bt-val">${bt.total_days} روز</span></div>
        <div class="bt-stat"><span class="bt-label">خطای انس</span><span class="bt-val">${bt.gold_mape}%</span></div>
        <div class="bt-stat"><span class="bt-label">خطای دلار</span><span class="bt-val">${bt.usd_mape}%</span></div>
        <div class="bt-stat"><span class="bt-label">خطای طلا18</span><span class="bt-val">${bt.iran_mape}%</span></div>
        <div class="bt-stat"><span class="bt-label">جهت انس</span><span class="bt-val">${bt.direction_accuracy??'--'}%</span></div>
        <div class="bt-stat"><span class="bt-label">جهت دلار</span><span class="bt-val">${bt.usd_direction_accuracy??'--'}%</span></div>
      </div>
    `;
    if(bt.gold&&bt.gold.length>0) drawBacktest('chBtGold',bt.gold,'#2563eb','#22c55e');
    if(bt.usd&&bt.usd.length>0) drawBacktest('chBtUSD',bt.usd,'#6366f1','#f59e0b');
    if(bt.iran&&bt.iran.length>0) drawBacktest('chBtIran',bt.iran,'#dc2626','#f97316');
  }
}
"""

if !occursin("function renderUI", content)
    content = replace(content, "async function doRefresh" => render_fn * "\nasync function doRefresh")
    println("renderUI added")
else
    println("renderUI already exists")
end

write("templates/index.html", content)
println("done - $(length(content)) chars")
