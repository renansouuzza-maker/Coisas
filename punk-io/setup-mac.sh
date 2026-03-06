#!/bin/bash
# ══════════════════════════════════════════════════
# PUNK.IO - SETUP COMPLETO
#
# COMO USAR:
# 1. Abra o Terminal no Mac
# 2. Cole: bash <(curl -sL URL) OU copie/cole este script todo
# 3. Depois rode: cd "/Users/reenzi/Documents/02. APPS/04. punk-io" && python3 server.py
# ══════════════════════════════════════════════════

set -e

DIR="/Users/reenzi/Documents/02. APPS/04. punk-io"
mkdir -p "$DIR"
cd "$DIR"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║         ⚡ PUNK.IO SETUP ⚡              ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── manifest.json ──
echo '{"name":"Punk.io","short_name":"Punk.io","description":"Sistema de Ideias Infinitas","start_url":"/","display":"standalone","background_color":"#0a0a0a","theme_color":"#7c3aed","orientation":"any","icons":[{"src":"icon.png","sizes":"512x512","type":"image/png","purpose":"any maskable"}],"lang":"pt-BR"}' > manifest.json
echo "✓ manifest.json"

# ── sw.js ──
cat > sw.js << 'SWEOF'
const CACHE='punkio-v1';
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(['/','index.html','manifest.json'])));self.skipWaiting()});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==CACHE).map(x=>caches.delete(x)))));self.clients.claim()});
self.addEventListener('fetch',e=>{e.respondWith(fetch(e.request).then(r=>{const c=r.clone();caches.open(CACHE).then(cache=>cache.put(e.request,c));return r}).catch(()=>caches.match(e.request)))});
SWEOF
echo "✓ sw.js"

# ── icon.png ──
python3 << 'PYEOF'
import struct,zlib
def png(w,h):
    px=[]
    for y in range(h):
        row=[0]
        for x in range(w):
            t=(x+y)/(w+h);r=int(124+(236-124)*t);g=int(58+(72-58)*t);b=int(237+(153-237)*t)
            lx,rx,ty,by,cy=w*0.3,w*0.7,h*0.2,h*0.8,h//2
            il=(lx<=x<=lx+w*0.12 and ty<=y<=by) or (lx<=x<=rx-w*0.05 and ty<=y<=ty+h*0.1) or (lx<=x<=rx-w*0.05 and cy-h*0.05<=y<=cy+h*0.05) or (rx-w*0.17<=x<=rx-w*0.05 and ty<=y<=cy+h*0.05)
            if il:r,g,b=255,255,255
            row+=[r,g,b,255]
        px.append(bytes(row))
    raw=b''.join(px)
    def ch(t,d):
        c=t+d;crc=zlib.crc32(c)&0xFFFFFFFF
        return struct.pack('>I',len(d))+c+struct.pack('>I',crc)
    return b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+ch(b'IDAT',zlib.compress(raw,9))+ch(b'IEND',b'')
open('icon.png','wb').write(png(512,512))
PYEOF
echo "✓ icon.png"

# ── server.py ──
cat > server.py << 'SRVEOF'
#!/usr/bin/env python3
import http.server, socket, sys, os
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8443
def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try: s.connect(('8.8.8.8', 80)); return s.getsockname()[0]
    except: return '127.0.0.1'
    finally: s.close()
os.chdir(os.path.dirname(os.path.abspath(__file__)))
ip = get_ip()
print(f"""
╔══════════════════════════════════════════════════╗
║              ⚡ PUNK.IO SERVER ⚡                ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  Local:   http://localhost:{PORT}                 ║
║  Rede:    http://{ip}:{PORT:<25s}║
║                                                  ║
║  📱 No iPhone/iPad (mesmo Wi-Fi):                ║
║  1. Safari → http://{ip}:{PORT:<21s}  ║
║  2. Compartilhar (↑) → Tela de Início            ║
║                                                  ║
║  Ctrl+C para parar                               ║
╚══════════════════════════════════════════════════╝
""")
http.server.HTTPServer(('0.0.0.0',PORT),http.server.SimpleHTTPRequestHandler).serve_forever()
SRVEOF
echo "✓ server.py"

# ── index.html (O APP COMPLETO) ──
cat > index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Punk.io">
<meta name="theme-color" content="#7c3aed">
<link rel="manifest" href="manifest.json">
<link rel="apple-touch-icon" href="icon.png">
<title>Punk.io</title>
<style>
*{margin:0;padding:0;box-sizing:border-box;-webkit-tap-highlight-color:transparent}
:root{--bg:#0a0a0a;--bg2:#141414;--bg3:#1e1e1e;--bg4:#2a2a2a;--text:#f5f5f5;--text2:#a0a0a0;--text3:#666;--purple:#7c3aed;--pink:#ec4899;--orange:#f59e0b;--green:#22c55e;--blue:#3b82f6;--red:#ef4444;--grad:linear-gradient(135deg,#7c3aed,#ec4899);--st:env(safe-area-inset-top);--sb:env(safe-area-inset-bottom)}
body{font-family:-apple-system,BlinkMacSystemFont,'SF Pro Display',system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100dvh;overflow-x:hidden;padding-top:var(--st)}
.hd{position:sticky;top:0;z-index:100;background:rgba(10,10,10,.85);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);border-bottom:1px solid rgba(255,255,255,.06);padding:12px 16px}
.hd-t{display:flex;align-items:center;justify-content:space-between}
.logo{display:flex;align-items:center;gap:8px}
.logo i{width:36px;height:36px;border-radius:10px;background:var(--grad);display:flex;align-items:center;justify-content:center;font-size:18px;font-weight:900;color:#fff;font-style:normal}
.logo b{font-size:22px;font-weight:900;background:var(--grad);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.hd-a{display:flex;gap:8px}
.hbtn{width:36px;height:36px;border-radius:50%;border:none;background:var(--bg3);color:var(--text2);font-size:16px;cursor:pointer;display:flex;align-items:center;justify-content:center}
.hbtn:active{transform:scale(.92)}
.live{display:flex;align-items:center;gap:6px;margin-top:10px;font-size:11px;color:var(--text3)}
.ldot{width:7px;height:7px;border-radius:50%;background:var(--green);box-shadow:0 0 8px rgba(34,197,94,.5);animation:pulse 2s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.4}}
.sb{display:none;margin-top:10px}.sb.on{display:flex}
.sb input{flex:1;padding:10px 14px;border-radius:10px;border:1px solid var(--bg4);background:var(--bg2);color:var(--text);font-size:14px;outline:none}
.sb input:focus{border-color:var(--purple)}
.fb{display:flex;gap:8px;padding:12px 16px;overflow-x:auto;scrollbar-width:none;-ms-overflow-style:none}.fb::-webkit-scrollbar{display:none}
.fc{padding:7px 14px;border-radius:20px;border:none;background:var(--bg3);color:var(--text2);font-size:12px;font-weight:600;white-space:nowrap;cursor:pointer;transition:all .2s;display:flex;align-items:center;gap:5px}
.fc.on{background:var(--purple);color:#fff}.fc:active{transform:scale(.95)}
.sh{display:flex;align-items:center;justify-content:space-between;padding:16px 16px 8px;font-size:15px;font-weight:700}
.sh span{display:flex;align-items:center;gap:6px}.sh a{color:var(--purple);font-size:12px;font-weight:600;text-decoration:none}
.ps{display:flex;gap:12px;padding:0 16px 8px;overflow-x:auto;scrollbar-width:none}.ps::-webkit-scrollbar{display:none}
.pc{min-width:110px;padding:14px 10px;border-radius:16px;background:var(--bg2);text-align:center;flex-shrink:0;cursor:pointer;border:1px solid rgba(255,255,255,.04)}
.pc:active{transform:scale(.96)}
.pa{width:60px;height:60px;border-radius:50%;margin:0 auto 8px;overflow:hidden;border:2.5px solid var(--purple)}
.pa img{width:100%;height:100%;object-fit:cover}
.pn{font-size:11px;font-weight:700;margin-bottom:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ph{font-size:10px;color:var(--text3);margin-bottom:6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.pf{font-size:10px;color:var(--purple);font-weight:600}
.pni{font-size:9px;font-weight:600;margin-top:6px;padding:3px 8px;border-radius:10px;background:rgba(124,58,237,.15);color:var(--purple);display:inline-block}
.vf{color:var(--blue);font-size:10px}
.fd{padding:0 16px 100px;display:flex;flex-direction:column;gap:16px}
.cd{border-radius:16px;overflow:hidden;background:var(--bg2);border:1px solid rgba(255,255,255,.04);cursor:pointer;transition:transform .2s}
.cd:active{transform:scale(.985)}
.ct{position:relative;aspect-ratio:16/9;background:var(--bg3);overflow:hidden}
.ct img{width:100%;height:100%;object-fit:cover}
.cto{position:absolute;inset:0;background:linear-gradient(0deg,rgba(0,0,0,.5) 0%,transparent 50%)}
.cb{position:absolute;top:10px;left:10px;padding:4px 10px;border-radius:20px;font-size:10px;font-weight:700;background:rgba(0,0,0,.6);backdrop-filter:blur(10px);color:#fff;display:flex;align-items:center;gap:4px}
.cs{position:absolute;top:10px;right:10px;padding:4px 10px;border-radius:20px;font-size:11px;font-weight:800;background:rgba(0,0,0,.6);backdrop-filter:blur(10px);display:flex;align-items:center;gap:3px}
.cbd{padding:14px}
.ctt{font-size:15px;font-weight:700;line-height:1.3;margin-bottom:6px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.csu{font-size:13px;color:var(--text2);line-height:1.4;margin-bottom:10px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.cau{display:flex;align-items:center;gap:8px;margin-bottom:10px}
.cau img{width:24px;height:24px;border-radius:50%;background:var(--bg4)}
.can{font-size:12px;font-weight:600}
.cht{font-size:10px;font-weight:700;padding:3px 8px;border-radius:10px;background:rgba(124,58,237,.15);color:var(--purple);margin-left:auto}
.cm{display:flex;gap:14px;margin-bottom:10px}.cmi{font-size:11px;color:var(--text3);display:flex;align-items:center;gap:3px}
.cta2{display:flex;gap:6px;flex-wrap:wrap}.ctg{font-size:10px;padding:3px 8px;border-radius:10px;background:var(--bg3);color:var(--text3)}
.mo{display:none;position:fixed;inset:0;z-index:200;background:rgba(0,0,0,.6);backdrop-filter:blur(4px)}.mo.on{display:block}
.ml{position:fixed;bottom:0;left:0;right:0;z-index:201;max-height:92dvh;background:var(--bg);border-radius:20px 20px 0 0;overflow-y:auto;transform:translateY(100%);transition:transform .35s cubic-bezier(.32,.72,0,1);padding-bottom:calc(20px + var(--sb))}.ml.on{transform:translateY(0)}
.mh{width:36px;height:4px;border-radius:2px;background:var(--bg4);margin:10px auto 0}
.mhr{position:relative;aspect-ratio:16/9}.mhr img{width:100%;height:100%;object-fit:cover}
.mhro{position:absolute;inset:0;background:linear-gradient(0deg,var(--bg) 0%,transparent 60%)}
.mhi{position:absolute;bottom:0;left:0;right:0;padding:16px}
.mhb{display:flex;gap:6px;margin-bottom:8px;flex-wrap:wrap}
.mhbi{padding:4px 10px;border-radius:14px;font-size:10px;font-weight:700;background:rgba(255,255,255,.15);backdrop-filter:blur(10px);color:#fff}
.mhtt{font-size:22px;font-weight:900;line-height:1.2}
.mc{padding:0 16px}
.mau{display:flex;align-items:center;gap:12px;padding:16px;background:var(--bg2);border-radius:14px;margin:16px 0;border:1px solid rgba(255,255,255,.04)}
.mau>img{width:48px;height:48px;border-radius:50%;border:2px solid var(--purple)}
.mai{flex:1}.man{font-size:14px;font-weight:700;display:flex;align-items:center;gap:4px}
.mas{font-size:12px;color:var(--text3);margin-top:2px}
.mae{text-align:right}.mae small{font-size:10px;color:var(--text3);display:block}.mae strong{font-size:15px;color:var(--green)}
.mg{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:16px 0}
.mb{text-align:center;padding:14px 8px;border-radius:12px;background:var(--bg2);border:1px solid rgba(255,255,255,.04)}
.mb .ic{font-size:20px;margin-bottom:4px}.mb .vl{font-size:17px;font-weight:800}.mb .lb{font-size:10px;color:var(--text3);margin-top:2px}
.tabs{display:flex;background:var(--bg3);border-radius:12px;padding:3px;margin:16px 0}
.tab{flex:1;padding:10px 6px;border:none;border-radius:10px;cursor:pointer;background:none;color:var(--text3);font-size:11px;font-weight:600;text-align:center;transition:all .2s}
.tab.on{background:var(--purple);color:#fff}.tab:active{transform:scale(.96)}
.tc{display:none;padding:16px;background:var(--bg2);border-radius:14px;line-height:1.6;font-size:14px}.tc.on{display:block}
.tc h3{font-size:14px;margin-bottom:10px;display:flex;align-items:center;gap:6px}.tc p{color:var(--text2)}
.hs{padding:12px;border-radius:10px;margin-bottom:10px}.hs .hl{font-size:10px;font-weight:800;text-transform:uppercase;margin-bottom:4px;letter-spacing:.5px}.hs p{font-size:13px}
.hs1{background:rgba(239,68,68,.08)}.hs1 .hl{color:var(--red)}
.hs2{background:rgba(245,158,11,.08)}.hs2 .hl{color:var(--orange)}
.hs3{background:rgba(34,197,94,.08)}.hs3 .hl{color:var(--green)}
.hs4{background:rgba(124,58,237,.08)}.hs4 .hl{color:var(--purple)}
.clb{display:flex;align-items:center;justify-content:center;gap:10px;width:100%;padding:16px;border:none;border-radius:14px;cursor:pointer;background:var(--grad);color:#fff;font-size:16px;font-weight:800;margin:20px 0;box-shadow:0 4px 20px rgba(124,58,237,.4)}.clb:active{transform:scale(.97)}
.cls{padding:20px 16px}.cls h2{text-align:center;font-size:20px;margin-bottom:4px}.cls .st{text-align:center;font-size:13px;color:var(--text3);margin-bottom:20px}
.clf{margin-bottom:16px}.clf label{font-size:11px;font-weight:700;color:var(--text3);text-transform:uppercase;letter-spacing:.3px;display:block;margin-bottom:6px}
.clf input,.clf textarea{width:100%;padding:12px;border-radius:10px;border:1px solid var(--bg4);background:var(--bg3);color:var(--text);font-size:14px;font-family:inherit;outline:none;resize:vertical}
.clf input:focus,.clf textarea:focus{border-color:var(--purple)}
.htc{display:flex;gap:6px;flex-wrap:wrap}
.htci{padding:6px 12px;border-radius:16px;border:none;cursor:pointer;background:var(--bg3);color:var(--text2);font-size:11px;font-weight:600;transition:all .2s}.htci.on{background:var(--purple);color:#fff}
.gnb{width:100%;padding:14px;border:none;border-radius:12px;cursor:pointer;background:var(--grad);color:#fff;font-size:15px;font-weight:700;margin:10px 0 16px}.gnb:active{transform:scale(.97)}
.clr{display:none;padding:16px;border-radius:12px;background:rgba(34,197,94,.08);border:1px solid rgba(34,197,94,.2);white-space:pre-wrap;font-size:13px;line-height:1.6;margin-bottom:12px}.clr.on{display:block}
.cla{display:flex;gap:10px}.cla button{flex:1;padding:12px;border:none;border-radius:10px;cursor:pointer;font-size:13px;font-weight:600;background:var(--bg3);color:var(--text)}.cla button:active{transform:scale(.96)}
.tb{position:fixed;bottom:0;left:0;right:0;z-index:150;display:flex;justify-content:space-around;background:rgba(10,10,10,.9);backdrop-filter:blur(20px);border-top:1px solid rgba(255,255,255,.06);padding:8px 0 calc(8px + var(--sb))}
.ti{display:flex;flex-direction:column;align-items:center;gap:2px;padding:6px 16px;border:none;background:none;color:var(--text3);font-size:10px;font-weight:600;cursor:pointer;transition:color .2s}.ti.on{color:var(--purple)}.ti .ic{font-size:22px}
.sc{display:none}.sc.on{display:block}
.ds{padding:0 16px;margin-bottom:20px}
.hp{display:flex;gap:12px;padding:14px;background:var(--bg2);border-radius:12px;margin-bottom:10px;cursor:pointer;border:1px solid rgba(255,255,255,.04)}.hp:active{transform:scale(.98)}
.hpb{width:3px;border-radius:2px;background:var(--grad);flex-shrink:0}
.hpt{display:flex;align-items:center;gap:6px;margin-bottom:6px}
.hpty{font-size:10px;font-weight:700;padding:2px 8px;border-radius:8px;background:rgba(124,58,237,.15);color:var(--purple)}
.hpx{font-size:13px;font-weight:600;line-height:1.3;margin-bottom:4px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.hpa{font-size:11px;color:var(--text3)}
.ig{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.ic2{padding:14px;background:var(--bg2);border-radius:12px;cursor:pointer;min-height:130px;display:flex;flex-direction:column;border:1px solid rgba(255,255,255,.04)}.ic2:active{transform:scale(.97)}
.ic2i{font-size:22px;margin-bottom:8px}.ic2t{font-size:12px;font-weight:700;line-height:1.3;margin-bottom:6px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.ic2d{font-size:11px;color:var(--text3);flex:1;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.ic2v{font-size:10px;color:var(--purple);font-weight:700;margin-top:8px}
.stb{text-align:center;padding:30px 0 20px}
.stb .stic{font-size:50px;margin-bottom:8px;background:var(--grad);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.stb h2{font-size:24px;font-weight:900}.stb p{font-size:12px;color:var(--text3)}
.sts{padding:0 16px;margin-bottom:20px}
.sts h3{font-size:13px;color:var(--text3);font-weight:700;text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px;padding:0 4px}
.stg{background:var(--bg2);border-radius:14px;overflow:hidden;border:1px solid rgba(255,255,255,.04)}
.str{display:flex;align-items:center;justify-content:space-between;padding:14px 16px;border-bottom:1px solid rgba(255,255,255,.04)}.str:last-child{border-bottom:none}
.str label{font-size:14px;display:flex;align-items:center;gap:8px}
.tgl{width:48px;height:28px;border-radius:14px;border:none;background:var(--bg4);position:relative;cursor:pointer;transition:background .2s}
.tgl.on{background:var(--purple)}.tgl::after{content:'';position:absolute;top:3px;left:3px;width:22px;height:22px;border-radius:50%;background:#fff;transition:transform .2s}.tgl.on::after{transform:translateX(20px)}
.ld{text-align:center;padding:60px 0}
.sp{width:32px;height:32px;border:3px solid var(--bg4);border-top-color:var(--purple);border-radius:50%;animation:spin .8s linear infinite;margin:0 auto 12px}
@keyframes spin{to{transform:rotate(360deg)}}.lt{font-size:12px;color:var(--text3)}
.em{text-align:center;padding:80px 30px}.em .ic{font-size:50px;margin-bottom:16px;opacity:.3}.em h3{font-size:18px;margin-bottom:8px}.em p{font-size:13px;color:var(--text3)}
.ib{display:none;margin:12px 16px;padding:14px;border-radius:14px;background:var(--grad);text-align:center}.ib.show{display:block}
.ib h4{font-size:14px;font-weight:700;color:#fff;margin-bottom:4px}.ib p{font-size:11px;color:rgba(255,255,255,.8)}
@media(min-width:768px){.fd{max-width:600px;margin:0 auto}.ml{max-width:600px;left:50%;transform:translate(-50%,100%)}.ml.on{transform:translate(-50%,0)}}
</style>
</head>
<body>
<header class="hd">
<div class="hd-t">
<div class="logo"><i>P</i><b>Punk.io</b></div>
<div class="hd-a"><button class="hbtn" onclick="tglS()">🔍</button><button class="hbtn" onclick="refresh()">🔄</button></div>
</div>
<div class="sb" id="sb"><input type="search" placeholder="Buscar conteúdos, creators, tags..." oninput="search(this.value)"></div>
<div class="live"><div class="ldot"></div><span>Atualizando em tempo real</span><span style="margin-left:auto" id="upd">Atualizado: Agora</span></div>
</header>
<div class="sc on" id="s0">
<div class="fb" id="fb"></div>
<div class="ib" id="ib"><h4>📲 Instalar Punk.io</h4><p>Compartilhar (↑) → Adicionar à Tela de Início</p></div>
<div class="sh"><span>👑 Perfis em Alta</span></div>
<div class="ps" id="ps"></div>
<div class="sh"><span>🔥 Viralizando Agora</span><span style="font-size:12px;color:var(--text3);font-weight:400" id="cnt"></span></div>
<div class="fd" id="fd"></div>
<div class="ld" id="ldg"><div class="sp"></div><div class="lt">Escaneando a internet...</div></div>
</div>
<div class="sc" id="s1">
<div class="sh"><span>⚡ Top Hooks do Dia</span></div>
<div class="ds" id="th"></div>
<div class="sh"><span>💡 Ideias para Clonar</span></div>
<div class="ds"><div class="ig" id="idg"></div></div>
</div>
<div class="sc" id="s2">
<div class="em" id="se"><div class="ic">🔖</div><h3>Nenhum conteúdo salvo</h3><p>Salve conteúdos virais para acessar depois e clonar com Hook Punch</p></div>
<div class="fd" id="sf" style="padding-top:16px"></div>
</div>
<div class="sc" id="s3">
<div class="stb"><div class="stic">⚡</div><h2>Punk.io</h2><p>Sistema de Ideias Infinitas</p><p style="margin-top:4px;font-size:11px">v1.0.0</p></div>
<div class="sts"><h3>Notificações</h3><div class="stg"><div class="str"><label>🔔 Alertas de conteúdo viral</label><button class="tgl on" onclick="this.classList.toggle('on')"></button></div><div class="str"><label>🔄 Atualização automática</label><button class="tgl on" onclick="this.classList.toggle('on')"></button></div></div></div>
<div class="sts"><h3>Plataformas</h3><div class="stg" id="pst"></div></div>
</div>
<div class="mo" id="ov" onclick="clsM()"></div>
<div class="ml" id="md"><div class="mh"></div><div id="mdb"></div></div>
<nav class="tb">
<button class="ti on" onclick="sTab(0)"><span class="ic">🔥</span>Viral</button>
<button class="ti" onclick="sTab(1)"><span class="ic">✨</span>Descobrir</button>
<button class="ti" onclick="sTab(2)"><span class="ic">🔖</span>Salvos</button>
<button class="ti" onclick="sTab(3)"><span class="ic">⚙️</span>Config</button>
</nav>
<script>
const PL=[{id:'all',n:'Todos',i:'✨'},{id:'tiktok',n:'TikTok',i:'🎵'},{id:'instagram',n:'Instagram',i:'📸'}];
const HT=['Curiosidade','Controvérsia','Storytelling','Desafio','Tutorial','Choque','Pergunta','Promessa'];
let D=[],F=[],S=[],CP='all';
function R(a,b){return Math.floor(Math.random()*(b-a+1))+a}
function N(n){return n>=1e6?(n/1e6).toFixed(1)+'M':n>=1e3?(n/1e3).toFixed(1)+'K':n}
function I(p){return{tiktok:'🎵',instagram:'📸'}[p]||'🌐'}
function gen(){
const C=[
{u:'@virginia',n:'Virginia Fonseca',a:'https://i.pravatar.cc/150?u=virginia1',p:'instagram',f:50000000,e:4.8,v:true,ni:'Maternidade'},
{u:'@maaborges',n:'Mari Maria',a:'https://i.pravatar.cc/150?u=marimaria2',p:'instagram',f:20000000,e:6.2,v:true,ni:'Maquiagem'},
{u:'@biaborges',n:'Bianca Andrade',a:'https://i.pravatar.cc/150?u=bocaa3',p:'instagram',f:18000000,e:7.1,v:true,ni:'Beleza'},
{u:'@francinyehlke',n:'Franciny Ehlke',a:'https://i.pravatar.cc/150?u=fran4',p:'instagram',f:6200000,e:5.9,v:true,ni:'Maquiagem'},
{u:'@brufraga',n:'Bruna Tavares',a:'https://i.pravatar.cc/150?u=bruna5',p:'instagram',f:4500000,e:8.3,v:true,ni:'Maquiagem'},
{u:'@rayzanicacio',n:'Rayza Nicácio',a:'https://i.pravatar.cc/150?u=rayza6',p:'instagram',f:1500000,e:9.7,v:true,ni:'Cabelo'},
{u:'@paborges',n:'Pabllo Vittar',a:'https://i.pravatar.cc/150?u=pabllo7',p:'instagram',f:15000000,e:11.2,v:true,ni:'LGBTQ+ Beauty'},
{u:'@gloriagroove',n:'Gloria Groove',a:'https://i.pravatar.cc/150?u=gloria8',p:'tiktok',f:12000000,e:13.8,v:true,ni:'LGBTQ+ Beauty'},
{u:'@jaborges',n:'Jade Picon',a:'https://i.pravatar.cc/150?u=jade9',p:'instagram',f:22000000,e:5.4,v:true,ni:'Skincare'},
{u:'@samarafelippo',n:'Samara Felippo',a:'https://i.pravatar.cc/150?u=samara10',p:'instagram',f:2300000,e:10.1,v:true,ni:'Maternidade'},
{u:'@nfranca',n:'Natália França',a:'https://i.pravatar.cc/150?u=natalia11',p:'tiktok',f:8500000,e:14.5,v:true,ni:'Cabelo'},
{u:'@ricodemar',n:'Rica de Marré',a:'https://i.pravatar.cc/150?u=rica12',p:'tiktok',f:5800000,e:16.3,v:true,ni:'LGBTQ+ Maquiagem'},
{u:'@letticiaa',n:'Letticia Munniz',a:'https://i.pravatar.cc/150?u=letticia13',p:'tiktok',f:9200000,e:12.7,v:true,ni:'Cabelo'},
{u:'@taizalves',n:'Taís Araujo',a:'https://i.pravatar.cc/150?u=tais14',p:'instagram',f:14000000,e:4.2,v:true,ni:'Beleza & Maternidade'}
];
const IT=[
{t:'Essa base de R$30 é MELHOR que a de R$300',s:'Maquiadora compara base drugstore com high-end em teste de 12h. Resultado surpreende.',id2:'Split-face: metade do rosto com cada. Timer 12h, check a cada 3h. Revelar resultado com close-up.',tr:'Gente, eu sei que vocês não vão acreditar. Essa base custa 30 reais. Essa outra, 300. Vou usar uma em cada lado do rosto e vamos ver em 12 horas qual sobrevive...',p:'tiktok',tp:'Video',ht:'Choque',tg:['maquiagem','base','drugstore','comparativo']},
{t:'Skincare coreana: rotina que mudou minha pele em 30 dias',s:'Antes e depois real de 30 dias com rotina coreana de 7 passos. Produtos acessíveis no Brasil.',id2:'Day 1→Day 30 sem filtro. Lista de produtos acessíveis. CTA pra salvar rotina completa.',tr:'Minha pele sempre foi minha maior insegurança. Acne, oleosidade, manchas. Então eu testei por 30 dias a famosa rotina coreana de skincare. E o resultado me fez chorar...',p:'instagram',tp:'Reel',ht:'Storytelling',tg:['skincare','rotina coreana','pele','antes e depois']},
{t:'Transição capilar: guia DEFINITIVO para cacheadas',s:'Método completo de transição sem big chop. Cronograma de 6 meses com produtos acessíveis.',id2:'Timeline visual mês 1 ao 6. Rotina específica por mês. Fotos reais de seguidoras.',tr:'Se você quer voltar pro cabelo natural mas tem MEDO do big chop, esse vídeo é pra você. O método que já ajudou mais de 10 mil mulheres a fazer a transição SEM cortar...',p:'tiktok',tp:'Video',ht:'Promessa',tg:['cabelo cacheado','transição capilar','cachos','natural']},
{t:'Maquiagem de R$50 vs R$500: qual dura mais?',s:'Kit barato vs premium em teste de 8h no calor de 35 graus. Resultado surpreende.',id2:'Split-face com timer. Check a cada 2h. Público vota antes de ver preço.',tr:'Eu gastei 50 reais nesse kit completo de maquiagem. E 500 nesse outro. Vou usar um em cada lado do rosto e sair pro calor de 35 graus. Qual vai sobreviver?',p:'instagram',tp:'Reel',ht:'Curiosidade',tg:['maquiagem','teste','barato vs caro','durabilidade']},
{t:'A verdade sobre a maternidade que ninguém posta',s:'Mãe real mostra noites sem dormir, culpa materna, corpo pós-parto. Depoimento cru que viralizou.',id2:'Sem filtro, sem maquiagem, filmado às 3h. Formato confessional. Gera identificação massiva.',tr:'São 3 da manhã e eu estou chorando no banheiro enquanto meu bebê dorme. Ninguém te prepara pra isso. Nenhum post bonito te conta que você vai se sentir a pior mãe do mundo...',p:'tiktok',tp:'Video',ht:'Storytelling',tg:['maternidade','maternidade real','pós-parto','mãe']},
{t:'Cabelo LISO para CACHEADO em 10 minutos sem química',s:'Transformação usando dedoliss e leave-in. Resultado impressionante em cabelo virgem.',id2:'Transformação em tempo real: liso→cachos sem babyliss, sem química. Técnica manual + produto certo.',tr:'Vocês me pediram esse tutorial há MESES. Olha meu cabelo agora: liso. Em 10 minutos, sem química, sem babyliss, ele vai estar ASSIM. Bora?',p:'tiktok',tp:'Video',ht:'Tutorial',tg:['cabelo','cachos','tutorial','transformação']},
{t:'Produtos de bebê: cilada vs vale CADA centavo',s:'Mãe de 3 lista produtos inúteis e os essenciais. Guia prático com preços.',id2:'Tier list: S-tier essencial, A-tier vale, F-tier cilada. Cada produto com preço e alternativa.',tr:'Já gastei mais de 30 mil em produtos de bebê entre meus 3 filhos. METADE foi dinheiro jogado fora. Vou te salvar dessa...',p:'instagram',tp:'Carousel',ht:'Controvérsia',tg:['maternidade','enxoval','bebê','produtos']},
{t:'Make LGBTQ+ pride: cut crease arco-íris perfeito',s:'Drag queen ensina cut crease com cores do arco-íris. Produtos acessíveis de farmácia.',id2:'Tutorial drag makeup acessível. Transformação time-lapse + tutorial detalhado.',tr:'Pega sua paleta porque hoje eu vou te ensinar o cut crease arco-íris que levou 5 milhões de views. E sim, dá pra fazer com produto de farmácia, meu amor...',p:'tiktok',tp:'Video',ht:'Tutorial',tg:['LGBTQ+','maquiagem','drag','pride','cut crease']},
{t:'7 ácidos que transformam sua pele (e 3 que DESTROEM)',s:'Dermatologista explica ácidos para cada tipo de pele e combinações perigosas.',id2:'Visual de receita proibida: ácidos como ingredientes, combinações seguras e perigosas.',tr:'Glicólico, salicílico, retinóico... todo mundo quer usar ácido na pele mas NINGUÉM sabe combinar. E tem 3 combinações DESTRUINDO a pele de vocês agora...',p:'instagram',tp:'Reel',ht:'Curiosidade',tg:['skincare','ácidos','dermatologia','pele']},
{t:'Amamentação: o que eu queria saber ANTES do bebê',s:'Consultora e mãe compartilha 10 verdades que toda gestante deveria saber.',id2:'10 verdades em carrossel: cada slide uma verdade + mito desfeito. Tom acolhedor.',tr:'Eu chorei TODOS os dias nas primeiras 2 semanas de amamentação. Ninguém me contou essas 10 coisas. Se você está grávida, SALVA esse vídeo...',p:'instagram',tp:'Carousel',ht:'Promessa',tg:['maternidade','amamentação','gestante','bebê']}
];
return IT.map((x,i)=>{const c=C[i%C.length];const vw=R(1e5,1e7),lk=R(1e4,5e5),cm=R(1e3,5e4),sh=R(5e3,2e5),sv=R(2e3,1e5);
return{id:'v'+i+'-'+Date.now(),t:x.t,s:x.s,idea:x.id2,tr:x.tr,p:x.p,tp:x.tp,ht:x.ht,tg:x.tg,au:c,
thumb:'https://picsum.photos/seed/pk'+i+R(0,999)+'/800/450',
m:{vw,lk,cm,sh,sv,vel:(Math.random()*23+2).toFixed(1)},
sc:R(70,99),
hp:{hook:x.tr.substring(0,120),punch:'E isso muda tudo sobre como você cria conteúdo.',cta:x.ht==='Pergunta'?'Comenta sua opinião':'Salva pra aplicar depois',trigger:x.ht,
tpl:'[HOOK]: '+x.tr.substring(0,80)+'...\n[DESENVOLVIMENTO]: Adapte para seu nicho\n[CTA]: '+(x.ht==='Pergunta'?'Comenta':'Salva')}
}})
}
function rFilt(){$('fb').innerHTML=PL.map(p=>`<button class="fc ${p.id===CP?'on':''}" onclick="filt('${p.id}')">${p.i} ${p.n}</button>`).join('')}
function rProf(){const s=new Set;const p=D.map(c=>c.au).filter(a=>{if(s.has(a.u))return false;s.add(a.u);return true});
$('ps').innerHTML=p.map(x=>`<div class="pc"><div class="pa"><img src="${x.a}" onerror="this.style.display='none'"></div><div class="pn">${x.n} ${x.v?'<span class="vf">✓</span>':''}</div><div class="ph">${x.u}</div><div class="pf">👥 ${N(x.f)}</div><div class="pni">${x.ni}</div></div>`).join('')}
function rFeed(items){$('cnt').textContent=items.length+' conteúdos';
$('fd').innerHTML=items.map(c=>`<div class="cd" onclick="opn('${c.id}')"><div class="ct"><img src="${c.thumb}" loading="lazy" onerror="this.parentElement.style.background='linear-gradient(135deg,#7c3aed,#ec4899)'"><div class="cto"></div><div class="cb">${I(c.p)} ${c.p}</div><div class="cs">🔥 <strong>${c.sc}</strong></div></div><div class="cbd"><div class="ctt">${c.t}</div><div class="csu">${c.s}</div><div class="cau"><img src="${c.au.a}" onerror="this.style.background='var(--bg4)'"><span class="can">${c.au.n} ${c.au.v?'<span class="vf">✓</span>':''}</span><span class="cht">${c.hp.trigger}</span></div><div class="cm"><span class="cmi">👁 ${N(c.m.vw)}</span><span class="cmi">❤️ ${N(c.m.lk)}</span><span class="cmi">💬 ${N(c.m.cm)}</span><span class="cmi">↗️ ${N(c.m.sh)}</span><span class="cmi" style="margin-left:auto">⚡${c.m.vel}/h</span></div><div class="cta2">${c.tg.map(t=>`<span class="ctg">#${t}</span>`).join('')}</div></div></div>`).join('')}
function rDisc(){$('th').innerHTML=D.slice(0,5).map(c=>`<div class="hp" onclick="opn('${c.id}')"><div class="hpb"></div><div style="flex:1;min-width:0"><div class="hpt"><span class="hpty">${c.hp.trigger}</span><span style="font-size:10px;color:var(--text3)">${I(c.p)}</span><span style="margin-left:auto;font-size:10px">🔥 ${c.sc}</span></div><div class="hpx">${c.hp.hook}</div><div class="hpa">por ${c.au.n}</div></div></div>`).join('');
$('idg').innerHTML=D.slice(4).map(c=>`<div class="ic2" onclick="opn('${c.id}')"><div class="ic2i">${I(c.p)}</div><div class="ic2t">${c.t}</div><div class="ic2d">${c.idea}</div><div class="ic2v">${N(c.m.vw)} views</div></div>`).join('')}
function rSet(){$('pst').innerHTML=PL.filter(p=>p.id!=='all').map(p=>`<div class="str"><label>${p.i} ${p.n}</label><button class="tgl on" onclick="this.classList.toggle('on')"></button></div>`).join('')}
function rSav(){const e=$('se'),f=$('sf');if(!S.length){e.style.display='block';f.innerHTML=''}else{e.style.display='none';
f.innerHTML=S.map(c=>`<div class="cd" onclick="opn('${c.id}')"><div class="ct"><img src="${c.thumb}" loading="lazy"><div class="cto"></div><div class="cb">${I(c.p)} ${c.p}</div></div><div class="cbd"><div class="ctt">${c.t}</div><div class="cau"><img src="${c.au.a}"><span class="can">${c.au.n}</span><span class="cht">${c.hp.trigger}</span></div></div></div>`).join('')}}
function opn(id){const c=D.find(x=>x.id===id);if(!c)return;const sv=S.some(x=>x.id===id);
$('mdb').innerHTML=`<div class="mhr"><img src="${c.thumb}" onerror="this.parentElement.style.background='linear-gradient(135deg,#7c3aed,#ec4899)'"><div class="mhro"></div><div class="mhi"><div class="mhb"><span class="mhbi">${I(c.p)} ${c.p}</span><span class="mhbi">${c.tp}</span><span class="mhbi" style="margin-left:auto;color:#f59e0b;font-weight:800">🔥 ${c.sc}</span></div><div class="mhtt">${c.t}</div></div></div>
<div class="mc"><div style="display:flex;gap:8px;margin:12px 0"><button onclick="save('${c.id}')" style="flex:1;padding:10px;border:none;border-radius:10px;background:${sv?'rgba(124,58,237,.2)':'var(--bg3)'};color:${sv?'var(--purple)':'var(--text)'};font-size:13px;font-weight:600;cursor:pointer">${sv?'✅ Salvo':'🔖 Salvar'}</button></div>
<div class="mau"><img src="${c.au.a}" onerror="this.style.background='var(--bg4)'"><div class="mai"><div class="man">${c.au.n} ${c.au.v?'<span class="vf">✓</span>':''}</div><div class="mas">${c.au.u} · ${N(c.au.f)} seguidores</div></div><div class="mae"><small>Engajamento</small><strong>${c.au.e}%</strong></div></div>
<div class="mg"><div class="mb"><div class="ic">👁</div><div class="vl">${N(c.m.vw)}</div><div class="lb">Views</div></div><div class="mb"><div class="ic">❤️</div><div class="vl">${N(c.m.lk)}</div><div class="lb">Likes</div></div><div class="mb"><div class="ic">💬</div><div class="vl">${N(c.m.cm)}</div><div class="lb">Comentários</div></div><div class="mb"><div class="ic">↗️</div><div class="vl">${N(c.m.sh)}</div><div class="lb">Shares</div></div><div class="mb"><div class="ic">🔖</div><div class="vl">${N(c.m.sv)}</div><div class="lb">Saves</div></div><div class="mb"><div class="ic">⚡</div><div class="vl">${c.m.vel}/h</div><div class="lb">Velocidade</div></div></div>
<div class="tabs"><button class="tab on" onclick="dTab(0,this)">📄 Resumo</button><button class="tab" onclick="dTab(1,this)">💡 Ideia</button><button class="tab" onclick="dTab(2,this)">🎤 Transcrição</button><button class="tab" onclick="dTab(3,this)">⚡ Hook</button></div>
<div class="tc on" data-t="0"><h3>📄 Resumo</h3><p>${c.s}</p></div>
<div class="tc" data-t="1"><h3>💡 Ideia Central</h3><p>${c.idea}</p></div>
<div class="tc" data-t="2"><h3>🎤 Transcrição</h3><p style="font-style:italic">${c.tr}</p><button onclick="cpTxt('${c.tr.replace(/'/g,"\\'")}')" style="margin-top:12px;padding:8px 16px;border:none;border-radius:8px;background:var(--bg3);color:var(--text);font-size:12px;cursor:pointer">📋 Copiar</button></div>
<div class="tc" data-t="3"><h3>⚡ Hook Punch</h3><div class="hs hs1"><div class="hl">Hook</div><p>${c.hp.hook}</p></div><div class="hs hs2"><div class="hl">Punch Line</div><p>${c.hp.punch}</p></div><div class="hs hs3"><div class="hl">CTA</div><p>${c.hp.cta}</p></div><div class="hs hs4"><div class="hl">Gatilho</div><p>${c.hp.trigger}</p></div></div>
<button class="clb" onclick="opnCl('${c.id}')">📋 Clonar com Hook Punch</button></div>`;
$('ov').classList.add('on');$('md').classList.add('on');document.body.style.overflow='hidden'}
function clsM(){$('ov').classList.remove('on');$('md').classList.remove('on');document.body.style.overflow=''}
function dTab(i,b){const m=$('mdb');m.querySelectorAll('.tab').forEach(t=>t.classList.remove('on'));m.querySelectorAll('.tc').forEach(t=>t.classList.remove('on'));b.classList.add('on');const tc=m.querySelectorAll('.tc');if(tc[i])tc[i].classList.add('on')}
function opnCl(id){const c=D.find(x=>x.id===id);if(!c)return;
$('mdb').innerHTML=`<div class="cls"><div style="text-align:center;font-size:40px;margin-bottom:8px">📋</div><h2>Clonar com Hook Punch</h2><p class="st">Adapte esse conteúdo viral para o seu nicho</p>
<div class="clf"><label>Hook Original</label><div style="padding:12px;border-radius:10px;background:var(--bg3);font-size:13px;color:var(--text2)">${c.hp.hook}</div></div>
<div class="clf"><label>Tipo de Hook</label><div class="htc" id="htc">${HT.map(h=>`<button class="htci ${h===c.hp.trigger?'on':''}" onclick="this.parentElement.querySelectorAll('.htci').forEach(b=>b.classList.remove('on'));this.classList.add('on')">${h}</button>`).join('')}</div></div>
<div class="clf"><label>Seu Nicho</label><input type="text" id="cni" placeholder="Ex: fitness, finanças, tech..."></div>
<div class="clf"><label>Personalizar Hook (opcional)</label><textarea id="cch" rows="3" placeholder="Reescreva o hook..."></textarea></div>
<button class="gnb" onclick="genCl('${c.id}')">✨ Gerar Clone</button>
<div class="clr" id="clr"></div>
<div class="cla" id="cla" style="display:none"><button onclick="cpCl()">📋 Copiar</button><button onclick="shCl()">↗️ Compartilhar</button></div>
<button style="width:100%;padding:12px;border:1px solid var(--bg4);border-radius:10px;background:none;color:var(--text2);font-size:13px;cursor:pointer;margin-top:12px" onclick="opn('${c.id}')">← Voltar</button></div>`}
function genCl(id){const c=D.find(x=>x.id===id);if(!c)return;
const ni=$('cni').value||'seu nicho';const ch=$('cch').value;const ht=document.querySelector('#htc .on')?.textContent||c.hp.trigger;const hk=ch||c.hp.hook;
const r=`🎯 HOOK (${ht}):\n[${ni.toUpperCase()}] ${hk}\n\n📝 ROTEIRO:\n${c.hp.tpl.replace('Adapte para seu nicho','Aplique para '+ni)}\n\n💡 IDEIA ADAPTADA:\n${c.idea}\n\n⚡ PUNCH LINE:\n${c.hp.punch}\n\n📣 CTA:\n${c.hp.cta}\n\n#${ni.replace(/\s+/g,'')} #viral #punkio`;
$('clr').textContent=r;$('clr').classList.add('on');$('cla').style.display='flex'}
function cpCl(){const t=$('clr').textContent;navigator.clipboard.writeText(t).then(()=>{const b=document.querySelector('.cla button');b.textContent='✅ Copiado!';setTimeout(()=>b.textContent='📋 Copiar',2e3)})}
function shCl(){const t=$('clr').textContent;navigator.share?navigator.share({title:'Punk.io Clone',text:t}):cpCl()}
function save(id){const i=S.findIndex(s=>s.id===id);if(i>=0)S.splice(i,1);else{const c=D.find(x=>x.id===id);if(c)S.push(c)}localStorage.setItem('punkio_saved',JSON.stringify(S.map(s=>s.id)));rSav();opn(id)}
function sTab(i){document.querySelectorAll('.sc').forEach(s=>s.classList.remove('on'));document.querySelectorAll('.ti').forEach(t=>t.classList.remove('on'));$('s'+i).classList.add('on');document.querySelectorAll('.ti')[i]?.classList.add('on');window.scrollTo(0,0)}
function filt(id){CP=id;rFilt();F=id==='all'?D:D.filter(c=>c.p===id);rFeed(F)}
function tglS(){$('sb').classList.toggle('on');if($('sb').classList.contains('on'))$('sb').querySelector('input').focus()}
function search(q){if(!q){filt(CP);return}q=q.toLowerCase();rFeed(D.filter(c=>c.t.toLowerCase().includes(q)||c.s.toLowerCase().includes(q)||c.tg.some(t=>t.toLowerCase().includes(q))||c.au.n.toLowerCase().includes(q)))}
function cpTxt(t){navigator.clipboard.writeText(t)}
function $(id){return document.getElementById(id)}
async function refresh(){$('ldg').style.display='block';$('fd').innerHTML='';await new Promise(r=>setTimeout(r,500));D=gen();F=D;const si=JSON.parse(localStorage.getItem('punkio_saved')||'[]');S=D.filter(c=>si.includes(c.id));rFilt();rProf();rFeed(D);rDisc();rSav();rSet();$('ldg').style.display='none';$('upd').textContent='Atualizado: Agora'}
async function init(){if('serviceWorker' in navigator)navigator.serviceWorker.register('sw.js').catch(()=>{});
const ios=/iPad|iPhone|iPod/.test(navigator.userAgent);const sa=window.matchMedia('(display-mode:standalone)').matches||window.navigator.standalone;
if(ios&&!sa)$('ib').classList.add('show');
await refresh();setInterval(()=>{D=gen();F=CP==='all'?D:D.filter(c=>c.p===CP);rFeed(F);rProf();rDisc();$('upd').textContent='Atualizado: Agora'},60000)}
$('md').addEventListener('touchstart',function(e){this._y=e.touches[0].clientY},{passive:true});
$('md').addEventListener('touchmove',function(e){if(e.touches[0].clientY-this._y>100)clsM()},{passive:true});
init();
</script>
</body>
</html>
HTMLEOF

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅ PUNK.IO INSTALADO COM SUCESSO!       ║"
echo "╠══════════════════════════════════════════╣"
echo "║                                          ║"
echo "║  Para iniciar, rode:                     ║"
echo "║  python3 server.py                       ║"
echo "║                                          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

ls -la "$DIR"
