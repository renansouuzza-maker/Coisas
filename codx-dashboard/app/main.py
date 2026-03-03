#!/usr/bin/env python3
"""
CodX Empire — Dashboard de Fluxos
Popup desktop macOS. Zero terminal. Zero browser.
Versão 1.0.0
"""

import sys
import os
import signal

# Garante que o diretório raiz está no path
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "app"))

from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu
from PyQt6.QtGui import QIcon, QPixmap, QColor, QPainter
from PyQt6.QtCore import Qt, QTimer

from dashboard import DashboardWindow
from data.state import AppState


def create_tray_icon():
    """Cria ícone 16x16 para a barra de menu."""
    px = QPixmap(16, 16)
    px.fill(Qt.GlobalColor.transparent)
    p = QPainter(px)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    p.setBrush(QColor("#FF3B30"))   # Core red — OBLIV/MAKER
    p.setPen(Qt.PenStyle.NoPen)
    p.drawEllipse(2, 2, 12, 12)
    p.end()
    return QIcon(px)


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("CodX Dashboard")
    app.setOrganizationName("CodX Empire")
    app.setQuitOnLastWindowClosed(False)  # Persiste na tray

    # Estado global
    state = AppState()

    # Janela principal (popup)
    window = DashboardWindow(state)

    # Tray icon → clique abre/fecha popup
    tray = QSystemTrayIcon(create_tray_icon(), app)
    tray.setToolTip("CodX Empire — Dashboard de Fluxos")

    menu = QMenu()
    act_show = menu.addAction("Mostrar Dashboard")
    act_show.triggered.connect(window.toggle_visibility)
    menu.addSeparator()
    act_quit = menu.addAction("Sair")
    act_quit.triggered.connect(app.quit)

    tray.setContextMenu(menu)
    tray.activated.connect(
        lambda reason: window.toggle_visibility()
        if reason == QSystemTrayIcon.ActivationReason.Trigger
        else None
    )
    tray.show()

    # Mostra ao iniciar
    window.show()

    # Ctrl+C no terminal fecha limpo
    signal.signal(signal.SIGINT, lambda *_: app.quit())

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
