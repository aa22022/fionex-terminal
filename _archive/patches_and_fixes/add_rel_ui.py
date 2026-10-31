from pathlib import Path

p = Path("templates/index.html")
txt = p.read_text(encoding="utf-8")

# Add relationship section before correlations
old_corr = '''<section>
  <div class="section-title">همبستگی ارزها با طلا</div>'''

new_corr = '''<section>
  <div class="section-title">نقشه روابط بین بازارها (Relationship Engine)</div>
  <div id="relMap"></div>
</section>

<section>
  <div class="section-title">همبستگی ارزها با طلا</div>'''

txt = txt.replace(old_corr, new_corr, 1)
print("[OK] Relationship section added")

# Add renderRelationships function
old_func = "function renderUI(d){"
new_func = '''function renderRelationships(rel) {
  const el = document.getElementById('relMap');
  if (!el || !rel || !rel.available) return;

  let html = '';

  // Summary bar
  html += `<div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:8px">`;
  html += `<div class="macro-cell" style="flex:1;min-width:120px"><div class="macro-label">روابط</div><div class="macro-value">${rel.relations.length}</div></div>`;
  html += `<div class="macro-cell" style="flex:1;min-width:120px"><div class="macro-label">پیش‌رو</div><div class="macro-value" style="color:var(--up)">${rel.leading_assets.length}</div></div>`;
  html += `<div class="macro-cell" style="flex:1;min-width:120px"><div class="macro-label">پس‌رو</div><div class="macro-value" style="color:var(--down)">${rel.lagging_assets.length}</div></div>`;
  html += `<div class="macro-cell" style="flex:2;min-width:200px"><div class="macro-label">مهم‌ترین تأثیرگذاران</div><div style="font-size:11px;margin-top:4px">${(rel.top_influencers||[]).map(a=>`<span style="background:var(--accent-bg);color:var(--accent);padding:1px 6px;border-radius:3px;font-size:9px;margin:1px;display:inline-block">${a}</span>`).join('')}</div></div>`;
  html += `</div>`;

  // Relations table
  html += `<div class="tbl-wrap"><table>
    <thead><tr>
      <th>دارایی</th>
      <th>پیرسون 20d</th>
      <th>پیرسون 60d</th>
      <th>Lead/Lag</th>
      <th>همبستگی L/L</th>
      <th>بتا 30d</th>
      <th>partial corr</th>
      <th>در آرامش</th>
      <th>در نوسان</th>
      <th>جهت</th>
      <th>قدرت</th>
      <th>تأثیر</th>
    </tr></thead>
    <tbody>`;

  for (const r of rel.relations) {
    const p20c = r.pearson_20d > 0.4 ? 'pos' : r.pearson_20d < -0.4 ? 'neg' : '';
    const p60c = r.pearson_60d > 0.4 ? 'pos' : r.pearson_60d < -0.4 ? 'neg' : '';
    const llc  = r.lead_lag_days > 0 ? 'style="color:var(--up)"' :
                 r.lead_lag_days < 0 ? 'style="color:var(--down)"' : '';
    const llLabel = r.lead_lag_days > 0 ? `+${r.lead_lag_days}d پیش‌رو` :
                    r.lead_lag_days < 0 ? `${r.lead_lag_days}d پس‌رو` : 'همزمان';
    const calm    = r.regime_corr?.calm    ? r.regime_corr.calm.toFixed(3)    : '--';
    const volatile= r.regime_corr?.volatile? r.regime_corr.volatile.toFixed(3): '--';
    const calmc   = r.regime_corr?.calm > 0.3 ? 'pos' : r.regime_corr?.calm < -0.3 ? 'neg' : '';
    const volatilec = r.regime_corr?.volatile > 0.3 ? 'pos' : r.regime_corr?.volatile < -0.3 ? 'neg' : '';

    const dirLabel = {
      'strong_positive': '↑↑ قوی',
      'mild_positive':   '↑ ملایم',
      'strong_negative': '↓↓ معکوس',
      'mild_negative':   '↓ ملایم معکوس',
      'neutral':         '─ خنثی'
    }[r.direction] || r.direction;

    const strLabel = {
      'very_strong': '⬛ بسیار قوی',
      'strong':      '■ قوی',
      'moderate':    '▪ متوسط',
      'weak':        '▫ ضعیف',
      'negligible':  '· ناچیز'
    }[r.strength] || r.strength;

    const depPct = Math.round((r.dep_score||0)*100);
    const depColor = depPct > 40 ? 'var(--accent)' : depPct > 20 ? 'var(--info)' : 'var(--muted)';

    html += `<tr>
      <td><b>${r.asset_b}</b></td>
      <td class="${p20c}">${r.pearson_20d}</td>
      <td class="${p60c}">${r.pearson_60d}</td>
      <td ${llc}>${llLabel}</td>
      <td class="${r.lead_lag_corr > 0.2 ? 'pos' : r.lead_lag_corr < -0.2 ? 'neg' : ''}">${r.lead_lag_corr}</td>
      <td>${r.beta_30d}</td>
      <td class="${r.partial_corr > 0.3 ? 'pos' : r.partial_corr < -0.3 ? 'neg' : ''}">${r.partial_corr}</td>
      <td class="${calmc}">${calm}</td>
      <td class="${volatilec}">${volatile}</td>
      <td>${dirLabel}</td>
      <td style="font-size:9px">${strLabel}</td>
      <td><div style="background:var(--border);height:14px;min-width:60px;border-radius:2px;overflow:hidden;position:relative"><div style="background:${depColor};width:${depPct}%;height:100%;opacity:0.7"></div><span style="position:absolute;right:3px;top:1px;font-size:9px;color:var(--text)">${depPct}%</span></div></td>
    </tr>`;
  }

  html += `</tbody></table></div>`;
  el.innerHTML = html;
}

function renderUI(d){'''

txt = txt.replace(old_func, new_func, 1)
print("[OK] renderRelationships function added")

# Add call inside renderUI
old_corr_call = '''  document.getElementById('corrTbl').innerHTML=d.correlations.map'''
new_corr_call = '''  if(d.relationships) renderRelationships(d.relationships);

  document.getElementById('corrTbl').innerHTML=d.correlations.map'''

txt = txt.replace(old_corr_call, new_corr_call, 1)
print("[OK] renderRelationships call added")

p.write_text(txt, encoding="utf-8")
print("HTML updated!")
