#!/usr/bin/env python3
"""
Punk.io PWA Server
Serves the PWA + proxies Instagram profile pictures to avoid CORS issues.
"""
import http.server
import json
import os
import re
import socket
import sys
import urllib.request
import urllib.error
from urllib.parse import urlparse, parse_qs

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8443

# Cache profile pics in memory to avoid hammering Instagram
_pic_cache = {}

IG_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
}


def fetch_ig_profile_pic(username):
    """Fetch Instagram profile picture URL by scraping the public profile page."""
    username = username.lstrip('@').strip().lower()

    if username in _pic_cache:
        return _pic_cache[username]

    url = f'https://www.instagram.com/{username}/'
    req = urllib.request.Request(url, headers=IG_HEADERS)

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode('utf-8', errors='replace')

        # Try og:image meta tag (most reliable)
        match = re.search(r'<meta\s+property="og:image"\s+content="([^"]+)"', html)
        if not match:
            match = re.search(r'<meta\s+content="([^"]+)"\s+property="og:image"', html)
        if match:
            pic_url = match.group(1).replace('&amp;', '&')
            _pic_cache[username] = pic_url
            return pic_url

        # Try profile_pic_url in JSON data
        match = re.search(r'"profile_pic_url_hd"\s*:\s*"([^"]+)"', html)
        if not match:
            match = re.search(r'"profile_pic_url"\s*:\s*"([^"]+)"', html)
        if match:
            pic_url = match.group(1).replace('\\u0026', '&')
            _pic_cache[username] = pic_url
            return pic_url

    except Exception as e:
        print(f'  [IG] Error fetching @{username}: {e}')

    return None


def proxy_image(image_url):
    """Fetch an image and return its bytes + content type."""
    req = urllib.request.Request(image_url, headers=IG_HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            content_type = resp.headers.get('Content-Type', 'image/jpeg')
            data = resp.read()
            return data, content_type
    except Exception as e:
        print(f'  [PROXY] Error: {e}')
        return None, None


class PunkIOHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler that serves static files + API endpoints."""

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        # API: Get profile picture URL for an Instagram username
        if path.startswith('/api/ig/pic/'):
            username = path.split('/api/ig/pic/')[-1].strip('/')
            self.handle_ig_pic(username)
            return

        # API: Proxy an image URL (to bypass CORS)
        if path == '/api/proxy-image':
            params = parse_qs(parsed.query)
            url = params.get('url', [None])[0]
            if url:
                self.handle_proxy_image(url)
            else:
                self.send_error(400, 'Missing url parameter')
            return

        # API: Batch fetch profile pics
        if path == '/api/ig/batch':
            params = parse_qs(parsed.query)
            usernames = params.get('users', [''])[0].split(',')
            self.handle_ig_batch(usernames)
            return

        # Default: serve static files
        super().do_GET()

    def handle_ig_pic(self, username):
        pic_url = fetch_ig_profile_pic(username)
        if pic_url:
            # Proxy the actual image to avoid CORS
            data, content_type = proxy_image(pic_url)
            if data:
                self.send_response(200)
                self.send_header('Content-Type', content_type)
                self.send_header('Cache-Control', 'public, max-age=3600')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(data)
                return

        # Fallback: return a generated avatar
        self.send_response(302)
        self.send_header('Location', f'https://ui-avatars.com/api/?name={username}&background=7c3aed&color=fff&size=150')
        self.end_headers()

    def handle_proxy_image(self, url):
        data, content_type = proxy_image(url)
        if data:
            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.send_header('Cache-Control', 'public, max-age=3600')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_error(502, 'Failed to fetch image')

    def handle_ig_batch(self, usernames):
        results = {}
        for u in usernames:
            u = u.strip()
            if u:
                pic_url = fetch_ig_profile_pic(u)
                # Return local proxy URL so frontend doesn't hit CORS
                results[u] = f'/api/ig/pic/{u}' if pic_url else f'https://ui-avatars.com/api/?name={u}&background=7c3aed&color=fff&size=150'

        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(results).encode())

    def log_message(self, format, *args):
        if '/api/' in str(args[0]):
            print(f'  [API] {args[0]}')
        # Suppress normal file serving logs for cleanliness


def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        return s.getsockname()[0]
    except Exception:
        return '127.0.0.1'
    finally:
        s.close()


os.chdir(os.path.dirname(os.path.abspath(__file__)))
local_ip = get_local_ip()

print(f"""
╔══════════════════════════════════════════════════╗
║              ⚡ PUNK.IO PWA SERVER ⚡             ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  Servidor rodando em:                            ║
║                                                  ║
║  Local:   http://localhost:{PORT}                 ║
║  Rede:    http://{local_ip}:{PORT}
║                                                  ║
║  📱 Para instalar no iPhone/iPad:                ║
║                                                  ║
║  1. Conecte no mesmo Wi-Fi do computador         ║
║  2. Abra Safari no iPhone/iPad                   ║
║  3. Acesse: http://{local_ip}:{PORT}
║  4. Toque no botão "Compartilhar" (seta pra cima)║
║  5. Toque "Adicionar à Tela de Início"           ║
║  6. Pronto! O app aparece como ícone nativo      ║
║                                                  ║
║  📸 Fotos de perfil do Instagram: ATIVADO        ║
║  Ctrl+C para parar                               ║
╚══════════════════════════════════════════════════╝
""")

httpd = http.server.HTTPServer(('0.0.0.0', PORT), PunkIOHandler)
try:
    httpd.serve_forever()
except KeyboardInterrupt:
    print('\nServidor encerrado.')
    httpd.server_close()
