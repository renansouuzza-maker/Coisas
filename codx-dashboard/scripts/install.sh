#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
#  CodX Dashboard — Script de instalação para macOS
#  Instala dependências, configura LaunchAgent e cria atalho no Applications
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="CodX Dashboard"
PLIST_NAME="com.codx.dashboard"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
APP_BUNDLE="$HOME/Applications/${APP_NAME}.app"

echo ""
echo "  ██████╗ ██████╗ ██████╗ ██╗  ██╗"
echo "  ██╔════╝██╔═══██╗██╔══██╗╚██╗██╔╝"
echo "  ██║     ██║   ██║██║  ██║ ╚███╔╝ "
echo "  ██║     ██║   ██║██║  ██║ ██╔██╗ "
echo "  ╚██████╗╚██████╔╝██████╔╝██╔╝ ██╗"
echo "   ╚═════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝"
echo ""
echo "  CodX Empire — Dashboard de Fluxos"
echo "  Instalação para macOS"
echo ""

# ── 1. Verifica Python 3.10+ ──────────────────────────────────────────────────
echo "→ Verificando Python..."
PYTHON=""
for cmd in python3.12 python3.11 python3.10 python3; do
    if command -v "$cmd" &>/dev/null; then
        version=$("$cmd" -c "import sys; print(sys.version_info[:2])")
        if "$cmd" -c "import sys; assert sys.version_info >= (3,10)" 2>/dev/null; then
            PYTHON="$cmd"
            echo "  ✓ $cmd encontrado"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo ""
    echo "  ✗ Python 3.10+ não encontrado."
    echo "  Instale via: brew install python@3.12"
    exit 1
fi

# ── 2. Cria venv isolado ──────────────────────────────────────────────────────
VENV_DIR="$ROOT_DIR/.venv"
echo "→ Criando ambiente virtual em .venv/ ..."
"$PYTHON" -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# ── 3. Instala dependências ───────────────────────────────────────────────────
echo "→ Instalando dependências (PyQt6, watchdog)..."
pip install --quiet --upgrade pip
pip install --quiet -r "$ROOT_DIR/requirements.txt"
echo "  ✓ Dependências instaladas"

# ── 4. Gera .app bundle macOS ─────────────────────────────────────────────────
echo "→ Criando .app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.codx.dashboard</string>
    <key>CFBundleName</key>
    <string>CodX Dashboard</string>
    <key>CFBundleDisplayName</key>
    <string>CodX Dashboard</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>codx-dashboard</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

# Executável wrapper
cat > "$APP_BUNDLE/Contents/MacOS/codx-dashboard" << EXEC
#!/usr/bin/env bash
export CODX_ROOT="$ROOT_DIR"
source "$VENV_DIR/bin/activate"
exec python "$ROOT_DIR/app/main.py" "\$@"
EXEC
chmod +x "$APP_BUNDLE/Contents/MacOS/codx-dashboard"

# Gera ícone ICNS simples via Python
"$VENV_DIR/bin/python" - << 'PYICON'
import struct, zlib, base64, os

ICON_PATH = os.path.expanduser("~/Applications/CodX Dashboard.app/Contents/Resources/AppIcon.icns")

# PNG 64x64 vermelho com "CX" — gerado inline
try:
    from PyQt6.QtWidgets import QApplication
    from PyQt6.QtGui import QPixmap, QPainter, QColor, QFont
    from PyQt6.QtCore import Qt
    import sys
    app = QApplication.instance() or QApplication(sys.argv)
    px = QPixmap(64, 64)
    px.fill(Qt.GlobalColor.transparent)
    p = QPainter(px)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    p.setBrush(QColor("#FF3B30"))
    p.setPen(Qt.PenStyle.NoPen)
    p.drawRoundedRect(0, 0, 64, 64, 14, 14)
    p.setPen(QColor("white"))
    p.setFont(QFont("Helvetica Neue", 20, weight=700))
    p.drawText(px.rect(), Qt.AlignmentFlag.AlignCenter, "CX")
    p.end()
    os.makedirs(os.path.dirname(ICON_PATH), exist_ok=True)
    px.save(ICON_PATH.replace(".icns", ".png"))
except Exception as e:
    pass  # ícone é opcional
PYICON

echo "  ✓ .app criado em $APP_BUNDLE"

# ── 5. LaunchAgent (auto-start no login) ──────────────────────────────────────
echo "→ Configurando LaunchAgent para auto-start..."
mkdir -p "$LAUNCH_AGENTS"

PLIST_FILE="$LAUNCH_AGENTS/${PLIST_NAME}.plist"

cat > "$PLIST_FILE" << LAUNCHD
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.codx.dashboard</string>

    <key>ProgramArguments</key>
    <array>
        <string>$APP_BUNDLE/Contents/MacOS/codx-dashboard</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>StandardOutPath</key>
    <string>$HOME/.codx/logs/dashboard.log</string>

    <key>StandardErrorPath</key>
    <string>$HOME/.codx/logs/dashboard-error.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>CODX_ROOT</key>
        <string>$ROOT_DIR</string>
    </dict>
</dict>
</plist>
LAUNCHD

# Cria diretório de logs
mkdir -p "$HOME/.codx/logs"

# Registra o LaunchAgent
launchctl unload "$PLIST_FILE" 2>/dev/null || true
launchctl load "$PLIST_FILE"
echo "  ✓ LaunchAgent registrado — iniciará automaticamente no login"

# ── 6. Inicia agora ───────────────────────────────────────────────────────────
echo ""
echo "→ Iniciando CodX Dashboard..."
launchctl start "$PLIST_NAME" 2>/dev/null || open "$APP_BUNDLE"

echo ""
echo "  ✅ Instalação concluída!"
echo ""
echo "  O dashboard aparecerá como popup na tela."
echo "  Ícone na barra de menu: clique para mostrar/ocultar."
echo "  Inicia automaticamente ao fazer login no Mac."
echo ""
echo "  Para desinstalar: ./scripts/uninstall.sh"
echo ""
