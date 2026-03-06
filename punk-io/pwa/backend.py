#!/usr/bin/env python3
"""
Punk.io Backend — Server + Gemini AI + Profile Scraping + Metrics
Roda junto com o frontend PWA no mesmo servidor.
"""

import json, os, re, time, hashlib, socket, sys, traceback
import urllib.request, urllib.parse, urllib.error, ssl
from http.server import HTTPServer, SimpleHTTPRequestHandler

# ═══════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════

GEMINI_API_KEY = "AIzaSyAfDzvmFd6fKgj8xtT5pzY5WRF2muGm7bE"
GEMINI_MODEL = "gemini-2.0-flash-lite"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8443

# Cache simples
_cache = {}
_cache_ttl = {}
CACHE_DURATION = 300

# Cache for Instagram profile pictures
_ig_pic_cache = {}

IG_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
}

# Perfis adicionados pelo usuário (persiste em arquivo)
PROFILES_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "profiles.json")

ssl_ctx = ssl.create_default_context()

def load_profiles():
    try:
        with open(PROFILES_FILE, "r") as f:
            return json.load(f)
    except:
        return []

def save_profiles(profiles):
    with open(PROFILES_FILE, "w") as f:
        json.dump(profiles, f, ensure_ascii=False, indent=2)

# ═══════════════════════════════════════
# GEMINI AI
# ═══════════════════════════════════════

def gemini(prompt, max_tokens=2048):
    url = f"{GEMINI_URL}?key={GEMINI_API_KEY}"
    payload = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.4, "maxOutputTokens": max_tokens}
    }).encode()
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, context=ssl_ctx, timeout=30) as resp:
            data = json.loads(resp.read())
            return data["candidates"][0]["content"]["parts"][0]["text"]
    except Exception as e:
        print(f"[Gemini] Erro: {e}")
        return None

def gemini_json(prompt, max_tokens=2048):
    result = gemini(prompt, max_tokens)
    if not result:
        return None
    result = result.strip()
    if result.startswith("```"):
        result = re.sub(r'^```\w*\n?', '', result)
        result = re.sub(r'\n?```$', '', result)
    try:
        return json.loads(result)
    except:
        print(f"[Gemini] JSON parse failed: {result[:200]}")
        return None

def ai_analyze_content(title, platform, niche="beleza"):
    return gemini_json(f"""Analise este conteúdo viral de {platform} do Brasil (nicho: {niche}).

Título: {title}

Retorne JSON puro sem markdown:
{{
  "summary": "resumo completo em 3-4 frases",
  "idea": "ideia central replicável em 2-3 frases",
  "transcription": "transcrição COMPLETA e detalhada do que a pessoa fala no vídeo, mínimo 250 palavras, com gírias brasileiras, pausas naturais, interjeições. Deve parecer real, como se fosse a transcrição de um vídeo de verdade. Inclua o hook nos primeiros segundos, desenvolvimento do conteúdo, e CTA final.",
  "hook": "hook exato dos 3 primeiros segundos",
  "hookType": "um de: Curiosidade|Controvérsia|Storytelling|Desafio|Tutorial|Choque|Pergunta|Promessa",
  "punchLine": "frase de impacto principal",
  "cta": "call to action",
  "emotionalTrigger": "gatilho emocional",
  "tags": ["tag1","tag2","tag3","tag4","tag5"]
}}""", max_tokens=3000)

def ai_full_transcription(title, summary):
    return gemini(f"""Gere uma transcrição COMPLETA e detalhada em português brasileiro para este vídeo viral:

Título: {title}
Resumo: {summary}

A transcrição deve:
- Ter entre 300-500 palavras
- Soar 100% natural, como alguém falando pra câmera
- Usar gírias brasileiras (tipo "gente", "miga", "amiga", "olha só")
- Ter hook FORTE nos primeiros 2 segundos
- Incluir pausas naturais com "..."
- Ter desenvolvimento completo do conteúdo
- Incluir CTA forte no final
- NÃO usar formatação markdown, apenas texto corrido

Retorne APENAS a transcrição, nada mais.""", max_tokens=1500)

def ai_generate_trending(niche="maquiagem"):
    return gemini_json(f"""Gere 5 ideias de conteúdo viral ATUAL para o nicho de {niche} no Brasil (Instagram/TikTok).
Cada ideia deve ser algo que está viralizando AGORA em março de 2026.

Retorne JSON puro:
[
  {{
    "title": "título chamativo do vídeo",
    "summary": "resumo em 2-3 frases",
    "idea": "ideia central replicável",
    "transcription": "transcrição completa (200+ palavras, em pt-BR, natural)",
    "platform": "tiktok ou instagram",
    "type": "Video, Reel, Carousel, Short",
    "hookType": "Curiosidade|Controvérsia|Storytelling|Desafio|Tutorial|Choque|Pergunta|Promessa",
    "tags": ["tag1","tag2","tag3"]
  }}
]""", max_tokens=4000)

def ai_analyze_profile(username):
    return gemini_json(f"""Analise o perfil @{username} do Instagram/TikTok brasileiro.
Considerando que é do nicho de beleza, maquiagem, cabelo, maternidade ou LGBTQ+.

Retorne JSON puro:
{{
  "displayName": "nome do criador",
  "bio": "bio estimada do perfil",
  "niche": "nicho principal (Maquiagem, Cabelo, Skincare, Maternidade, LGBTQ+ Beauty, Beleza)",
  "contentStyle": "estilo de conteúdo em 1 frase",
  "targetAudience": "público-alvo em 1 frase",
  "estimatedFollowers": 0,
  "estimatedEngagement": 0.0,
  "isVerified": true,
  "topContentTypes": ["tipo1", "tipo2"],
  "bestPostingTimes": "melhores horários para postar"
}}""")

# ═══════════════════════════════════════
# SCRAPING DE MÉTRICAS
# ═══════════════════════════════════════

def fetch_url(url, headers=None):
    cache_key = hashlib.md5(url.encode()).hexdigest()
    now = time.time()
    if cache_key in _cache and _cache_ttl.get(cache_key, 0) > now:
        return _cache[cache_key]

    h = {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
        "Accept-Language": "pt-BR,pt;q=0.9",
    }
    if headers:
        h.update(headers)

    req = urllib.request.Request(url, headers=h)
    try:
        with urllib.request.urlopen(req, context=ssl_ctx, timeout=15) as resp:
            data = resp.read().decode("utf-8", errors="ignore")
            _cache[cache_key] = data
            _cache_ttl[cache_key] = now + CACHE_DURATION
            return data
    except Exception as e:
        print(f"[Fetch] Erro: {url} → {e}")
        return None

def scrape_profile_metrics(username):
    """Tenta pegar métricas de várias fontes gratuitas"""
    username = username.lstrip("@").strip().strip("/")
    result = {"username": f"@{username}", "platform": "instagram", "source": "ai"}

    # 1. Not Just Analytics
    nja = fetch_url(f"https://www.notjustanalytics.com/instagram/{username}")
    if nja:
        m = re.search(r'"followers":\s*"?([\d,.]+)', nja)
        if m:
            result["followers"] = parse_num(m.group(1))
            result["source"] = "notjustanalytics"
        m = re.search(r'engagement.*?([\d.]+)\s*%', nja, re.I)
        if m:
            result["engagementRate"] = float(m.group(1))

    # 2. Enriquecer com Gemini
    ai = ai_analyze_profile(username)
    if ai:
        for k in ["displayName", "bio", "niche", "contentStyle", "targetAudience", "topContentTypes", "bestPostingTimes"]:
            if k in ai:
                result[k] = ai[k]
        if "estimatedFollowers" in ai and result.get("followers", 0) == 0:
            result["followers"] = ai["estimatedFollowers"]
        if "estimatedEngagement" in ai and "engagementRate" not in result:
            result["engagementRate"] = ai["estimatedEngagement"]
        if "isVerified" in ai:
            result["isVerified"] = ai["isVerified"]

    result.setdefault("displayName", username.replace(".", " ").replace("_", " ").title())
    result.setdefault("followers", 0)
    result.setdefault("engagementRate", 0)
    result.setdefault("bio", "")
    result.setdefault("niche", "Beleza")
    result.setdefault("isVerified", False)
    result["avatarURL"] = f"https://i.pravatar.cc/150?u={username}"

    return result

def parse_num(s):
    s = s.strip().replace(",", "").replace(".", "")
    mult = 1
    if s[-1:].upper() == "M": mult = 1_000_000; s = s[:-1]
    elif s[-1:].upper() == "K": mult = 1_000; s = s[:-1]
    try: return int(float(s) * mult)
    except: return 0

def extract_username(text):
    """Extrai username de texto compartilhado do Instagram"""
    m = re.search(r'instagram\.com/([a-zA-Z0-9_.]+)', text)
    if m and m.group(1) not in ("reel", "p", "stories", "explore", "tv", "accounts"):
        return m.group(1)
    m = re.search(r'@([a-zA-Z0-9_.]+)', text)
    if m: return m.group(1)
    text = text.strip().lstrip("@")
    if re.match(r'^[a-zA-Z0-9_.]+$', text):
        return text
    return None

# ═══════════════════════════════════════
# HTTP HANDLER
# ═══════════════════════════════════════

def fetch_ig_profile_pic(username):
    """Fetch Instagram profile picture URL by scraping the public profile page."""
    username = username.lstrip('@').strip().lower()
    if username in _ig_pic_cache:
        return _ig_pic_cache[username]

    url = f'https://www.instagram.com/{username}/'
    req = urllib.request.Request(url, headers=IG_HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10, context=ssl_ctx) as resp:
            html = resp.read().decode('utf-8', errors='replace')
        # Try og:image meta tag
        match = re.search(r'<meta\s+property="og:image"\s+content="([^"]+)"', html)
        if not match:
            match = re.search(r'<meta\s+content="([^"]+)"\s+property="og:image"', html)
        if match:
            pic_url = match.group(1).replace('&amp;', '&')
            _ig_pic_cache[username] = pic_url
            return pic_url
        # Try JSON data
        match = re.search(r'"profile_pic_url_hd"\s*:\s*"([^"]+)"', html)
        if not match:
            match = re.search(r'"profile_pic_url"\s*:\s*"([^"]+)"', html)
        if match:
            pic_url = match.group(1).replace('\\u0026', '&')
            _ig_pic_cache[username] = pic_url
            return pic_url
    except Exception as e:
        print(f'  [IG] Error fetching @{username}: {e}')
    return None


def proxy_image(image_url):
    """Fetch an image and return (bytes, content_type)."""
    req = urllib.request.Request(image_url, headers=IG_HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10, context=ssl_ctx) as resp:
            return resp.read(), resp.headers.get('Content-Type', 'image/jpeg')
    except Exception as e:
        print(f'  [PROXY] Error: {e}')
        return None, None


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        p = urllib.parse.urlparse(self.path)

        if p.path == "/api/status":
            self._json({"status": "ok", "gemini": True, "model": GEMINI_MODEL, "profiles": len(load_profiles())})

        elif p.path == "/api/profiles":
            self._json(load_profiles())

        elif p.path.startswith("/api/profile/"):
            user = p.path.split("/api/profile/")[1].strip("/")
            self._json(scrape_profile_metrics(user))

        elif p.path.startswith("/api/ig/pic/"):
            username = p.path.split("/api/ig/pic/")[1].strip("/")
            pic_url = fetch_ig_profile_pic(username)
            if pic_url:
                data, ct = proxy_image(pic_url)
                if data:
                    self.send_response(200)
                    self.send_header("Content-Type", ct)
                    self.send_header("Cache-Control", "public, max-age=3600")
                    self._cors()
                    self.end_headers()
                    self.wfile.write(data)
                    return
            # Fallback to generated avatar
            self.send_response(302)
            self.send_header("Location", f"https://ui-avatars.com/api/?name={username}&background=7c3aed&color=fff&size=150")
            self.end_headers()

        elif p.path == "/api/trending":
            q = urllib.parse.parse_qs(p.query)
            niche = q.get("niche", ["maquiagem"])[0]
            data = ai_generate_trending(niche)
            self._json({"content": data or [], "niche": niche})

        elif p.path == "/api/analyze":
            q = urllib.parse.parse_qs(p.query)
            title = q.get("title", [""])[0]
            platform = q.get("platform", ["instagram"])[0]
            niche = q.get("niche", ["beleza"])[0]
            data = ai_analyze_content(title, platform, niche)
            self._json(data or {"error": "Analysis failed"})

        elif p.path == "/api/transcribe":
            q = urllib.parse.parse_qs(p.query)
            title = q.get("title", [""])[0]
            summary = q.get("summary", [""])[0]
            text = ai_full_transcription(title, summary)
            self._json({"transcription": text or "Transcrição não disponível"})

        else:
            super().do_GET()

    def do_POST(self):
        p = urllib.parse.urlparse(self.path)
        body = self._body()

        if p.path == "/api/profile/add":
            text = body.get("text", "") or body.get("url", "") or body.get("username", "")
            username = extract_username(text)
            if not username:
                self._json({"error": "Não consegui extrair o username", "input": text}, 400)
                return

            print(f"[+] Adicionando perfil: @{username}")
            profile = scrape_profile_metrics(username)

            profiles = load_profiles()
            existing = [i for i, p in enumerate(profiles) if p.get("username") == f"@{username}"]
            if existing:
                profiles[existing[0]] = profile
            else:
                profiles.append(profile)
            save_profiles(profiles)

            self._json({"success": True, "username": f"@{username}", "profile": profile})

        elif p.path == "/api/profile/remove":
            username = body.get("username", "").lstrip("@")
            profiles = load_profiles()
            profiles = [p for p in profiles if p.get("username") != f"@{username}"]
            save_profiles(profiles)
            self._json({"success": True, "removed": username})

        elif p.path == "/api/chat":
            message = body.get("message", "")
            history = body.get("history", [])
            context = body.get("context", {})

            # Build conversation for Gemini
            history_text = "\n".join([f"{'Usuario' if h.get('role') == 'user' else 'Assistente'}: {h.get('text', '')}" for h in history[-6:]])
            prompt = f"""Voce e o assistente de IA do Punk.io, um app de conteudo viral focado em beleza, maquiagem, cabelo, skincare, maternidade e LGBTQ+ no Brasil.

Contexto atual: {json.dumps(context, ensure_ascii=False)}

Historico recente:
{history_text}

Usuario: {message}

Responda de forma util, concisa e pratica. Foque em dicas acionaveis sobre criacao de conteudo viral. Use portugues brasileiro informal. Nao use emojis. Limite a resposta a 200 palavras."""

            response = gemini(prompt, 1024)
            self._json({"response": response or "Desculpa, nao consegui processar. Tente novamente."})

        elif p.path == "/api/content/analyze":
            title = body.get("title", "")
            platform = body.get("platform", "instagram")
            niche = body.get("niche", "beleza")
            data = ai_analyze_content(title, platform, niche)
            self._json(data or {"error": "Falha na análise"})

        elif p.path == "/api/content/transcribe":
            title = body.get("title", "")
            summary = body.get("summary", "")
            text = ai_full_transcription(title, summary)
            self._json({"transcription": text or "Indisponível"})

        else:
            self.send_error(404)

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors()
        self.end_headers()

    def _json(self, data, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self._cors()
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode())

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _body(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            return json.loads(self.rfile.read(length).decode())
        except:
            return {}

    def log_message(self, fmt, *args):
        path = str(args[0]) if args else ""
        if "/api/" in path:
            print(f"  [API] {path}")

# ═══════════════════════════════════════
# MAIN
# ═══════════════════════════════════════

def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try: s.connect(("8.8.8.8", 80)); return s.getsockname()[0]
    except: return "127.0.0.1"
    finally: s.close()

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    ip = get_ip()

    print(f"""
╔══════════════════════════════════════════════════════╗
║            ⚡ PUNK.IO + GEMINI AI ⚡                 ║
╠══════════════════════════════════════════════════════╣
║                                                      ║
║  🌐 Local:  http://localhost:{PORT}                   ║
║  📱 Rede:   http://{ip}:{PORT}                      ║
║                                                      ║
║  🤖 Gemini: {GEMINI_MODEL}                    ║
║  📊 Métricas: Not Just Analytics + AI                ║
║                                                      ║
║  📱 iPhone/iPad (mesmo Wi-Fi):                       ║
║     Safari → http://{ip}:{PORT}                     ║
║     Compartilhar (↑) → Tela de Início                ║
║                                                      ║
║  🔌 APIs:                                            ║
║  GET  /api/status        — Status                    ║
║  GET  /api/profiles      — Perfis salvos             ║
║  GET  /api/profile/:user — Scrape perfil             ║
║  GET  /api/ig/pic/:user  — Foto real do Instagram    ║
║  GET  /api/trending      — Conteúdo trending (AI)    ║
║  GET  /api/analyze       — Análise de conteúdo       ║
║  GET  /api/transcribe    — Transcrição completa      ║
║  POST /api/profile/add   — Adicionar perfil          ║
║  POST /api/profile/remove — Remover perfil           ║
║                                                      ║
║  Ctrl+C para parar                                   ║
╚══════════════════════════════════════════════════════╝
""")

    try:
        HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        print("\n⚡ Servidor encerrado.")
