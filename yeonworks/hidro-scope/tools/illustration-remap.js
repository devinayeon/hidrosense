const fs=require('fs');const T=process.argv[2],S=process.argv[3];
const files=fs.readdirSync(T).filter(f=>/figma_get_file_at_version-1794789/.test(f)).map(f=>T+'/'+f);
const hx=c=>[c.r,c.g,c.b].map(x=>Math.round(x*255).toString(16).padStart(2,'0')).join('');
const hsl=h=>{const r=parseInt(h.slice(0,2),16)/255,g=parseInt(h.slice(2,4),16)/255,b=parseInt(h.slice(4,6),16)/255;const mx=Math.max(r,g,b),mn=Math.min(r,g,b),l=(mx+mn)/2,d=mx-mn;let H=0,s=0;if(d>0){s=d/(1-Math.abs(2*l-1));if(mx===r)H=((g-b)/d)%6;else if(mx===g)H=(b-r)/d+2;else H=(r-g)/d+4;H=(H*60+360)%360;}return [H,s,l];};
const SUN={'d9ed88':'FFC94D','e7f29a':'FFD978','d1e67c':'F5A623'};
function role(h){
 if(SUN[h])return ['sun',SUN[h]];
 const [H,s,l]=hsl(h);
 if(l>=0.985)return ['white',h];
 if((H<35||H>330)&&s>0.2)return ['warm-keep',h];            // pinks, noses, cardboard
 if(l<0.3)return ['ink',l<0.16?'111A33':'1B2A4A'];
 // rockwool olive
 if(H>=60&&H<85&&s<0.45&&l>=0.3&&l<0.62)return ['sand',l<0.4?'B08F55':l<0.5?'C9A96B':'DCC48F'];
 if(H>=60&&H<85&&s<0.45&&l>=0.62&&l<0.8)return ['sand',l<0.7?'E6D3A3':'EFE3C0'];
 // pale warm / pale yellow-green: cream (cat body, paper, shadows)
 if(l>=0.82&&((H>=35&&H<100&&s<0.75)||(H>=35&&H<70)))return ['cream',l>=0.95?'FFFDF8':l>=0.9?'F7F3EA':'ECE6D8'];
 // pale cool: ice
 if(l>=0.72&&H>=100&&H<=210&&s<0.6)return ['ice',l>=0.92?'EEF4FF':l>=0.85?'DCE8FF':l>=0.78?'C6D9FF':'AEC8FF'];
 // teal / blue-green objects: blue family
 if(H>=158&&H<=210)return ['blue',l<0.4?'0B4FD1':l<0.5?'1565FF':l<0.58?'3F7CFF':l<0.66?'6E9BFF':'9DBCFF'];
 // leaves and greens
 if(H>=85&&H<158&&s>=0.15)return ['leaf',l>=0.8?'D7F7A8':l>=0.7?'B8EE6A':l>=0.6?'7CCB3E':l>=0.5?'5BB236':'3B8F2E'];
 if(H>=60&&H<85&&s>=0.45)return ['leaf-hi',l>=0.82?'E8FBC4':l>=0.72?'C8F57A':'A3F533'];
 if(H>=35&&H<60&&s>=0.45)return ['yellow',l>=0.8?'FFE08A':'F5A623'];
 if(H>210&&H<330)return ['keep',h];
 return ['keep',h];}
const out={};const stats={};const roleByHex={};
for(const f of files){const j=JSON.parse(fs.readFileSync(f,'utf8'));for(const [rid,v] of Object.entries(j.nodes)){
 (out[rid]=out[rid]||{});(function w(x){const e=[];for(const k of ['fills','strokes']){const arr=x[k]||[];e.push(arr.map(p=>{if(p.type!=='SOLID')return '';const h=hx(p.color);const [r,n]=role(h);stats[r]=(stats[r]||0)+1;roleByHex[h]=r+'>'+n;return n;}).join(','));}
  if(e[0]||e[1])out[rid][x.id]=e.join('|');(x.children||[]).forEach(w);})(v.document);}}
fs.writeFileSync(S+'/remap.json',JSON.stringify(out));
console.log('nodes',Object.keys(out).length,stats);
const byRole={};for(const [h,r] of Object.entries(roleByHex)){const k=r.split('>')[0];(byRole[k]=byRole[k]||[]).push('#'+h);}
for(const [k,v] of Object.entries(byRole))console.log(k,v.length,v.slice(0,14).join(' '));
