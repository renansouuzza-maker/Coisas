#!/bin/bash
# ═══════════════════════════════════════
# Punk.io - Instalador Automático
# Cola esse script inteiro no Terminal do Mac e pressiona Enter
# ═══════════════════════════════════════

DIR="/Users/reenzi/Documents/02. APPS/04. punk-io"
cd "$DIR" || exit 1

echo "⚡ Criando Punk.io..."

# ── Manifest ──
cat > manifest.json << 'MANIFEST'
{
  "name": "Punk.io",
  "short_name": "Punk.io",
  "description": "Sistema de Ideias Infinitas",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0a0a0a",
  "theme_color": "#7c3aed",
  "orientation": "any",
  "icons": [
    { "src": "icon.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" }
  ],
  "lang": "pt-BR"
}
MANIFEST

# ── Service Worker ──
cat > sw.js << 'SW'
const CACHE='punkio-v1';
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(['/','index.html','manifest.json'])));self.skipWaiting()});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==CACHE).map(x=>caches.delete(x)))));self.clients.claim()});
self.addEventListener('fetch',e=>{e.respondWith(fetch(e.request).then(r=>{const c=r.clone();caches.open(CACHE).then(cache=>cache.put(e.request,c));return r}).catch(()=>caches.match(e.request)))});
SW

# ── Icon (generate with Python) ──
python3 -c "
import struct,zlib,os
def png(w,h):
    px=[]
    for y in range(h):
        row=[0]
        for x in range(w):
            t=(x+y)/(w+h);r=int(124+(236-124)*t);g=int(58+(72-58)*t);b=int(237+(153-237)*t)
            lx,rx,ty,by,cy=w*0.3,w*0.7,h*0.2,h*0.8,h//2
            il=False
            if lx<=x<=lx+w*0.12 and ty<=y<=by:il=True
            if lx<=x<=rx-w*0.05 and ty<=y<=ty+h*0.1:il=True
            if lx<=x<=rx-w*0.05 and cy-h*0.05<=y<=cy+h*0.05:il=True
            if rx-w*0.17<=x<=rx-w*0.05 and ty<=y<=cy+h*0.05:il=True
            if il:r,g,b=255,255,255
            row+=[r,g,b,255]
        px.append(bytes(row))
    raw=b''.join(px)
    def ch(t,d):
        c=t+d;crc=zlib.crc32(c)&0xFFFFFFFF
        return struct.pack('>I',len(d))+c+struct.pack('>I',crc)
    return b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+ch(b'IDAT',zlib.compress(raw,9))+ch(b'IEND',b'')
open('icon.png','wb').write(png(512,512))
print('Icon created')
"

echo "⚡ Criando app principal..."
