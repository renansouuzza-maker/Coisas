#!/usr/bin/env python3
"""
Punk.io PWA Server
Run this to serve the app locally, then access from your iPhone/iPad on the same Wi-Fi.
"""
import http.server
import ssl
import os
import socket
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8443

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

handler = http.server.SimpleHTTPServer if hasattr(http.server, 'SimpleHTTPServer') else http.server.SimpleHTTPRequestHandler

local_ip = get_local_ip()

print(f"""
╔══════════════════════════════════════════════════╗
║              ⚡ PUNK.IO PWA SERVER ⚡             ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  Servidor rodando em:                            ║
║                                                  ║
║  Local:   http://localhost:{PORT}                 ║
║  Rede:    http://{local_ip}:{PORT}          ║
║                                                  ║
║  📱 Para instalar no iPhone/iPad:                ║
║                                                  ║
║  1. Conecte no mesmo Wi-Fi do computador         ║
║  2. Abra Safari no iPhone/iPad                   ║
║  3. Acesse: http://{local_ip}:{PORT}        ║
║  4. Toque no botão "Compartilhar" (↑)            ║
║  5. Toque "Adicionar à Tela de Início"           ║
║  6. Pronto! O app aparece como ícone nativo      ║
║                                                  ║
║  Ctrl+C para parar                               ║
╚══════════════════════════════════════════════════╝
""")

httpd = http.server.HTTPServer(('0.0.0.0', PORT), http.server.SimpleHTTPRequestHandler)
try:
    httpd.serve_forever()
except KeyboardInterrupt:
    print('\nServidor encerrado.')
    httpd.server_close()
