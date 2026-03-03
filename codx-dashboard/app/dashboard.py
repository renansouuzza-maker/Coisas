"""
Janela principal do CodX Dashboard.
Popup com borda arredondada, sem frame nativo, arrastável.
"""

from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QTabWidget, QFrame, QSizeGrip
)
from PyQt6.QtCore import Qt, QPoint, QTimer, QPropertyAnimation, QEasingCurve, QRect
from PyQt6.QtGui import QPainter, QColor, QFont, QPen, QBrush, QLinearGradient

from nodes.flow_canvas import FlowCanvas
from data.state import AppState
from data.workflows import WORKFLOWS
from monitors.file_watcher import FileWatcher
from monitors.status_reader import StatusReader


POPUP_W = 1100
POPUP_H = 720

# Paleta CodX Empire
BG_DARK   = "#0D0D0F"
BG_PANEL  = "#141418"
BG_CARD   = "#1A1A20"
BORDER    = "#2A2A35"
TEXT_PRI  = "#F0F0F5"
TEXT_SEC  = "#8888A0"
ACCENT    = "#FF3B30"      # Core red
TIER_COLORS = {
    "core":      "#FF3B30",
    "premium":   "#9B59B6",
    "corporate": "#3498DB",
    "volume":    "#2ECC71",
    "labs":      "#F1C40F",
}


class HeaderBar(QWidget):
    """Barra de título arrastável."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedHeight(48)
        self._drag_pos = None

        layout = QHBoxLayout(self)
        layout.setContentsMargins(16, 0, 8, 0)
        layout.setSpacing(8)

        # Logo / título
        dot = QLabel("●")
        dot.setStyleSheet(f"color: {ACCENT}; font-size: 12px;")
        title = QLabel("CodX Empire  —  Dashboard de Fluxos")
        title.setStyleSheet(f"color: {TEXT_PRI}; font-size: 13px; font-weight: 600; letter-spacing: 0.5px;")

        layout.addWidget(dot)
        layout.addWidget(title)
        layout.addStretch()

        # Status live
        self.status_dot = QLabel("●")
        self.status_dot.setStyleSheet(f"color: {TIER_COLORS['volume']}; font-size: 10px;")
        self.status_label = QLabel("live")
        self.status_label.setStyleSheet(f"color: {TEXT_SEC}; font-size: 11px;")
        layout.addWidget(self.status_dot)
        layout.addWidget(self.status_label)

        layout.addSpacing(12)

        # Botão fechar (minimiza para tray)
        btn_close = QPushButton("✕")
        btn_close.setFixedSize(24, 24)
        btn_close.setStyleSheet(f"""
            QPushButton {{
                background: transparent;
                color: {TEXT_SEC};
                border: none;
                font-size: 13px;
                border-radius: 12px;
            }}
            QPushButton:hover {{
                background: rgba(255,59,48,0.15);
                color: {ACCENT};
            }}
        """)
        btn_close.clicked.connect(self.window().hide)
        layout.addWidget(btn_close)

        self.setStyleSheet(f"background: {BG_PANEL}; border-bottom: 1px solid {BORDER};")

    def mousePressEvent(self, ev):
        if ev.button() == Qt.MouseButton.LeftButton:
            self._drag_pos = ev.globalPosition().toPoint() - self.window().frameGeometry().topLeft()

    def mouseMoveEvent(self, ev):
        if self._drag_pos and ev.buttons() == Qt.MouseButton.LeftButton:
            self.window().move(ev.globalPosition().toPoint() - self._drag_pos)

    def mouseReleaseEvent(self, ev):
        self._drag_pos = None


class SidePanel(QWidget):
    """Painel lateral: lista de escritórios e status."""

    def __init__(self, state: AppState, parent=None):
        super().__init__(parent)
        self.state = state
        self.setFixedWidth(220)
        self.setStyleSheet(f"background: {BG_PANEL}; border-right: 1px solid {BORDER};")

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Seção header
        hdr = QLabel("  ESCRITÓRIOS")
        hdr.setFixedHeight(36)
        hdr.setStyleSheet(f"color: {TEXT_SEC}; font-size: 10px; font-weight: 700; letter-spacing: 1.5px; background: {BG_DARK}; border-bottom: 1px solid {BORDER};")
        layout.addWidget(hdr)

        self.entries = []
        for tier_name, tier_color, offices in [
            ("CORE", TIER_COLORS["core"], [
                ("OBLIV", "obliv-brand"), ("MAKER", "maker-digital"),
            ]),
            ("PREMIUM", TIER_COLORS["premium"], [
                ("VERACCI", "veracci-luxo"), ("HUMAN ARCH", "human-arch"),
                ("ÁVIA", "avia-saude"), ("BLENX", "blenx"),
            ]),
            ("CORPORATE", TIER_COLORS["corporate"], [
                ("NEXUS", "nexus-rh"), ("NXS", "nxs-rh"),
                ("ENGEX", "engex-construcao"), ("ESPAÇO SINGULAR", "espaco-singular"),
            ]),
            ("VOLUME", TIER_COLORS["volume"], [
                ("SHALON", "shalon-varejo"),
            ]),
            ("LABS", TIER_COLORS["labs"], [
                ("ADV PROJECT", "adv-lab"),
            ]),
        ]:
            # Tier label
            tier_lbl = QLabel(f"  {tier_name}")
            tier_lbl.setFixedHeight(24)
            tier_lbl.setStyleSheet(
                f"color: {tier_color}; font-size: 9px; font-weight: 700; "
                f"letter-spacing: 1px; background: {BG_DARK}; "
                f"border-left: 2px solid {tier_color}; padding-left: 6px;"
            )
            layout.addWidget(tier_lbl)

            for office_name, agent_id in offices:
                row = OfficeRow(office_name, agent_id, tier_color, state)
                layout.addWidget(row)
                self.entries.append(row)

        layout.addStretch()

        # BLIV orquestradora
        bliv_lbl = QLabel("  ★  BLIV — Orquestradora")
        bliv_lbl.setFixedHeight(40)
        bliv_lbl.setStyleSheet(
            f"color: {ACCENT}; font-size: 11px; font-weight: 700; "
            f"background: rgba(255,59,48,0.08); border-top: 1px solid {BORDER}; "
            f"border-left: 3px solid {ACCENT}; padding-left: 10px;"
        )
        layout.addWidget(bliv_lbl)

    def refresh(self):
        for entry in self.entries:
            entry.refresh()


class OfficeRow(QWidget):
    def __init__(self, name, agent_id, color, state: AppState, parent=None):
        super().__init__(parent)
        self.agent_id = agent_id
        self.state = state
        self.setFixedHeight(34)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(12, 0, 8, 0)
        layout.setSpacing(6)

        self.indicator = QLabel("●")
        self.indicator.setStyleSheet(f"color: {TEXT_SEC}; font-size: 8px;")

        lbl = QLabel(name)
        lbl.setStyleSheet(f"color: {TEXT_PRI}; font-size: 11px;")

        self.count_lbl = QLabel("")
        self.count_lbl.setStyleSheet(f"color: {color}; font-size: 10px; font-weight: 600;")

        layout.addWidget(self.indicator)
        layout.addWidget(lbl)
        layout.addStretch()
        layout.addWidget(self.count_lbl)

        self.setStyleSheet(f"""
            OfficeRow {{
                background: transparent;
                border-left: 2px solid transparent;
            }}
            OfficeRow:hover {{
                background: rgba(255,255,255,0.03);
                border-left: 2px solid {color};
            }}
        """)

    def refresh(self):
        status = self.state.get_agent_status(self.agent_id)
        if status == "running":
            self.indicator.setStyleSheet(f"color: {TIER_COLORS['volume']}; font-size: 8px;")
        elif status == "error":
            self.indicator.setStyleSheet(f"color: {ACCENT}; font-size: 8px;")
        elif status == "idle":
            self.indicator.setStyleSheet(f"color: {TEXT_SEC}; font-size: 8px;")

        tasks = self.state.get_agent_tasks(self.agent_id)
        self.count_lbl.setText(f"{tasks}" if tasks else "")


class BottomBar(QWidget):
    def __init__(self, state: AppState, parent=None):
        super().__init__(parent)
        self.state = state
        self.setFixedHeight(32)
        self.setStyleSheet(f"background: {BG_DARK}; border-top: 1px solid {BORDER};")

        layout = QHBoxLayout(self)
        layout.setContentsMargins(16, 0, 16, 0)
        layout.setSpacing(24)

        self.total_lbl  = QLabel("Fluxos: —")
        self.active_lbl = QLabel("Ativos: —")
        self.error_lbl  = QLabel("Erros: —")
        self.time_lbl   = QLabel("")

        for lbl in (self.total_lbl, self.active_lbl, self.error_lbl):
            lbl.setStyleSheet(f"color: {TEXT_SEC}; font-size: 10px;")

        self.time_lbl.setStyleSheet(f"color: {TEXT_SEC}; font-size: 10px;")

        layout.addWidget(self.total_lbl)
        layout.addWidget(self.active_lbl)
        layout.addWidget(self.error_lbl)
        layout.addStretch()
        layout.addWidget(self.time_lbl)

        self._clock = QTimer()
        self._clock.timeout.connect(self._tick)
        self._clock.start(1000)
        self._tick()

    def _tick(self):
        from datetime import datetime
        self.time_lbl.setText(datetime.now().strftime("%d/%m/%Y  %H:%M:%S"))

    def refresh(self):
        stats = self.state.get_stats()
        self.total_lbl.setText(f"Fluxos: {stats['total']}")
        self.active_lbl.setText(f"Ativos: {stats['active']}")
        self.error_lbl.setStyleSheet(
            f"color: {ACCENT if stats['errors'] else TEXT_SEC}; font-size: 10px;"
        )
        self.error_lbl.setText(f"Erros: {stats['errors']}")


class DashboardWindow(QMainWindow):
    def __init__(self, state: AppState):
        super().__init__()
        self.state = state
        self._setup_window()
        self._build_ui()
        self._start_watchers()
        self._refresh_timer = QTimer()
        self._refresh_timer.timeout.connect(self._refresh)
        self._refresh_timer.start(2000)  # refresh a cada 2s

    def _setup_window(self):
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.resize(POPUP_W, POPUP_H)

        # Centraliza na tela
        from PyQt6.QtWidgets import QApplication
        screen = QApplication.primaryScreen().geometry()
        self.move(
            (screen.width()  - POPUP_W) // 2,
            (screen.height() - POPUP_H) // 2,
        )

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        central.setStyleSheet(f"""
            QWidget {{
                background: {BG_DARK};
                border: 1px solid {BORDER};
                border-radius: 12px;
            }}
        """)

        root = QVBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Header
        self.header = HeaderBar()
        root.addWidget(self.header)

        # Body: side panel + canvas
        body = QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)

        self.side = SidePanel(self.state)
        body.addWidget(self.side)

        # Tab widget para múltiplas views
        tabs = QTabWidget()
        tabs.setStyleSheet(f"""
            QTabWidget::pane {{
                border: none;
                background: {BG_DARK};
            }}
            QTabBar::tab {{
                background: {BG_PANEL};
                color: {TEXT_SEC};
                padding: 6px 16px;
                border: none;
                font-size: 11px;
                font-weight: 500;
            }}
            QTabBar::tab:selected {{
                background: {BG_DARK};
                color: {TEXT_PRI};
                border-bottom: 2px solid {ACCENT};
            }}
            QTabBar::tab:hover {{
                color: {TEXT_PRI};
            }}
        """)

        # Tab: Fluxos Principais
        self.canvas_main = FlowCanvas(
            WORKFLOWS["producao_semanal"], self.state
        )
        tabs.addTab(self.canvas_main, "  Produção Semanal  ")

        # Tab: CEO Dashboard
        self.canvas_ceo = FlowCanvas(
            WORKFLOWS["dashboard_ceo"], self.state
        )
        tabs.addTab(self.canvas_ceo, "  Dashboard CEO  ")

        # Tab: Onboarding
        self.canvas_onboard = FlowCanvas(
            WORKFLOWS["onboarding"], self.state
        )
        tabs.addTab(self.canvas_onboard, "  Onboarding Cliente  ")

        # Tab: Design Factory
        self.canvas_design = FlowCanvas(
            WORKFLOWS["design_factory"], self.state
        )
        tabs.addTab(self.canvas_design, "  Design Factory  ")

        body.addWidget(tabs)
        root_w = QWidget()
        root_w.setLayout(body)
        root_w.setStyleSheet("background: transparent;")
        root.addWidget(root_w)

        # Bottom bar
        self.bottom = BottomBar(self.state)
        root.addWidget(self.bottom)

        # Grip para redimensionar
        grip = QSizeGrip(self)
        grip.setFixedSize(16, 16)

    def _start_watchers(self):
        self.file_watcher = FileWatcher(self.state)
        self.file_watcher.start()
        self.status_reader = StatusReader(self.state)
        self.status_reader.start()

    def _refresh(self):
        self.side.refresh()
        self.bottom.refresh()
        self.canvas_main.tick()
        self.canvas_ceo.tick()
        self.canvas_onboard.tick()
        self.canvas_design.tick()

    def toggle_visibility(self):
        if self.isVisible():
            self.hide()
        else:
            self.show()
            self.raise_()
            self.activateWindow()

    def paintEvent(self, ev):
        """Sombra externa via pintura manual."""
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setPen(Qt.PenStyle.NoPen)
        shadow = QColor(0, 0, 0, 80)
        for i in range(8):
            shadow.setAlpha(80 - i * 10)
            p.setBrush(shadow)
            p.drawRoundedRect(i, i, self.width() - 2*i, self.height() - 2*i, 14, 14)
