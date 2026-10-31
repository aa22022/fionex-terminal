content = read("templates/index.html", String)

inject = """
function looksMojibake(str){
  return typeof str === "string" && /\xc3|\xd8|\xd9|\xc2|\xe2|\xe2\x80|[\x99\x9c\x9e\xa2]/.test(str);
}
function latin1BytesToUtf8(str){
  try{
    const bytes=Uint8Array.from(Array.from(str).map(ch=>ch.charCodeAt(0)&0xFF));
    return new TextDecoder("utf-8").decode(bytes);
  }catch(e){return str;}
}
function fixMojibakeString(str){
  if(!looksMojibake(str))return str;
  let cur=str;
  for(let i=0;i<4;i++){
    const next=latin1BytesToUtf8(cur);
    if(next===cur)break;
    cur=next;
    if(!looksMojibake(cur))break;
  }
  return cur;
}
function deepFixStrings(obj){
  if(obj===null||obj===undefined)return obj;
  if(typeof obj==="string")return fixMojibakeString(obj);
  if(Array.isArray(obj))return obj.map(deepFixStrings);
  if(typeof obj==="object"){
    const out={};
    for(const [k,v] of Object.entries(obj))out[k]=deepFixStrings(v);
    return out;
  }
  return obj;
}
"""

old_load = """async function loadData(){
try{const r=await fetch('/api/data');const d=await r.json();if(d.status!=='success')return;renderUI(d)}
catch(e){console.error(e);document.getElementById('statusDot').className='status-dot err'}
}"""

new_load = """async function loadData(){
try{
  const r=await fetch('/api/data');
  const raw=await r.json();
  if(raw.status!=='success')return;
  const d=deepFixStrings(raw);
  renderUI(d);
}catch(e){
  console.error(e);
  document.getElementById('statusDot').className='status-dot err';
}
}"""

if !occursin("function deepFixStrings", content)
    content = replace(content, "Chart.defaults.color" => inject * "\nChart.defaults.color")
    println("deepFixStrings injected")
else
    println("deepFixStrings already present")
end

if occursin(old_load, content)
    content = replace(content, old_load => new_load)
    println("loadData patched")
else
    println("loadData pattern not found - trying regex...")
    content = replace(content, r"async function loadData\(\)\{[^}]+\}" => new_load)
    println("loadData regex replaced")
end

write("templates/index.html", content)
println("DONE - templates/index.html updated")
