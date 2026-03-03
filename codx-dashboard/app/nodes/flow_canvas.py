"""
FlowCanvas — Canvas de nós e arestas para visualização de workflows.
Renderização customizada via QPainter. Zero dependências externas de UI.
"""

import math
from typing import Dict, List, Optional
from PyQt6.QtWidgets import QWidget, QScrollArea
from PyQt6.QtCore import Qt, QRect, QRectF, QPointF, QTimer, pyqtSignal
from PyQt6.QtGui import (
    QPainter, QColor, QPen, QBrush, QFont, QFontMetrics,
    QLinearGradient, QPainterPath, QRadialGradient
)

from data.state import AppState
from data.workflows import WorkflowDef, NodeDef, EdgeDef


# ── Paleta ────────────────────────────────────────────────────────────────────

BG         = QColor("#0D0D0F")
BG_NODE    = QColor("#1A1A22")
BORDER_DIM = QColor("#2A2A38")

TIER_COLORS = {
    "core":      QColor("#FF3B30"),
    "premium":   QColor("#9B59B6"),
    "corporate": QColor("#3498DB"),
    "volume":    QColor("#2ECC71"),
    "labs":      QColor("#F1C40F"),
    "neutral":   QColor("#5A5A72"),
}

STATE_COLORS = {
    "idle":      QColor("#3A3A50"),
    "running":   QColor("#2ECC71"),
    "completed": QColor("#3498DB"),
    "error":     QColor("#FF3B30"),
    "waiting":   QColor("#F1C40F"),
}

KIND_SHAPES = {
    "io":       "diamond",
    "agent":    "hexagon",
    "process":  "rounded_rect",
    "decision": "diamond",
    "parallel": "rounded_rect",
    "export":   "stadium",
}

NODE_W = 120
NODE_H = 52
CANVAS_PAD_X = 60
CANVAS_PAD_Y = 40


class FlowCanvas(QWidget):
    node_clicked = pyqtSignal(str)

    def __init__(self, workflow: WorkflowDef, state: AppState, parent=None):
        super().__init__(parent)
        self.workflow = workflow
        self.state    = state
        self._anim_phase = 0.0    # 0.0 → 1.0, para animação de arestas
        self._anim_timer = QTimer()
        self._anim_timer.timeout.connect(self._advance_anim)
        self._anim_timer.start(32)  # ~30fps de animação de arestas
        self._hover_node: Optional[str] = None
        self.setMouseTracking(True)
        self.setMinimumSize(600, 300)
        self.setStyleSheet("background: #0D0D0F;")

    # ── Layout helpers ────────────────────────────────────────────────────────

    def _node_rect(self, node: NodeDef, w: int, h: int) -> QRectF:
        """Converte posição normalizada para pixel."""
        usable_w = w - 2 * CANVAS_PAD_X - NODE_W
        usable_h = h - 2 * CANVAS_PAD_Y - NODE_H
        cx = CANVAS_PAD_X + node["x"] * usable_w + NODE_W / 2
        cy = CANVAS_PAD_Y + node["y"] * usable_h + NODE_H / 2
        return QRectF(cx - NODE_W / 2, cy - NODE_H / 2, NODE_W, NODE_H)

    def _node_center(self, node: NodeDef, w: int, h: int) -> QPointF:
        r = self._node_rect(node, w, h)
        return r.center()

    def _find_node(self, node_id: str) -> Optional[NodeDef]:
        for n in self.workflow["nodes"]:
            if n["id"] == node_id:
                return n
        return None

    # ── Animação ──────────────────────────────────────────────────────────────

    def _advance_anim(self):
        self._anim_phase = (self._anim_phase + 0.02) % 1.0
        self.update()

    def tick(self):
        """Chamado pelo dashboard a cada 2s para refresh de estado."""
        self.update()

    # ── Mouse ─────────────────────────────────────────────────────────────────

    def mouseMoveEvent(self, ev):
        pt = QPointF(ev.position())
        w, h = self.width(), self.height()
        hit = None
        for node in self.workflow["nodes"]:
            r = self._node_rect(node, w, h)
            if r.contains(pt):
                hit = node["id"]
                break
        if hit != self._hover_node:
            self._hover_node = hit
            self.setCursor(Qt.CursorShape.PointingHandCursor if hit else Qt.CursorShape.ArrowCursor)
            self.update()

    def mousePressEvent(self, ev):
        if ev.button() == Qt.MouseButton.LeftButton and self._hover_node:
            self.node_clicked.emit(self._hover_node)

    # ── Paint ─────────────────────────────────────────────────────────────────

    def paintEvent(self, ev):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setRenderHint(QPainter.RenderHint.TextAntialiasing)

        w, h = self.width(), self.height()

        # Fundo
        p.fillRect(0, 0, w, h, BG)

        # Grid sutil
        self._draw_grid(p, w, h)

        # Título
        self._draw_title(p, w)

        # Arestas (atrás dos nós)
        for edge in self.workflow["edges"]:
            self._draw_edge(p, edge, w, h)

        # Nós
        for node in self.workflow["nodes"]:
            self._draw_node(p, node, w, h)

        p.end()

    def _draw_grid(self, p: QPainter, w: int, h: int):
        pen = QPen(QColor("#16161E"))
        pen.setWidth(1)
        p.setPen(pen)
        spacing = 28
        for x in range(0, w, spacing):
            p.drawLine(x, 0, x, h)
        for y in range(0, h, spacing):
            p.drawLine(0, y, w, y)

    def _draw_title(self, p: QPainter, w: int):
        font = QFont("SF Pro Display, Helvetica Neue, Arial", 11, QFont.Weight.Medium)
        p.setFont(font)
        p.setPen(QColor("#5A5A72"))
        p.drawText(CANVAS_PAD_X, 22, self.workflow["title"])

    def _draw_edge(self, p: QPainter, edge: EdgeDef, w: int, h: int):
        src_node = self._find_node(edge["src"])
        dst_node = self._find_node(edge["dst"])
        if not src_node or not dst_node:
            return

        src_c = self._node_center(src_node, w, h)
        dst_c = self._node_center(dst_node, w, h)

        # Cor da aresta baseada no estado do nó destino
        dst_state = self.state.get_node_state(dst_node["id"])
        tier_col  = TIER_COLORS.get(src_node["tier"], TIER_COLORS["neutral"])

        if edge["style"] == "animated":
            self._draw_animated_edge(p, src_c, dst_c, tier_col, edge.get("label", ""))
        elif edge["style"] == "dashed":
            self._draw_dashed_edge(p, src_c, dst_c, tier_col, edge.get("label", ""))
        else:
            self._draw_solid_edge(p, src_c, dst_c, tier_col, edge.get("label", ""))

    def _draw_solid_edge(self, p: QPainter, src: QPointF, dst: QPointF, col: QColor, label: str):
        pen = QPen(col)
        pen.setWidth(1)
        pen.setColor(QColor(col.red(), col.green(), col.blue(), 80))
        p.setPen(pen)
        path = self._bezier_path(src, dst)
        p.drawPath(path)
        self._draw_arrow(p, src, dst, col, 60)
        if label:
            self._draw_edge_label(p, src, dst, label, col)

    def _draw_dashed_edge(self, p: QPainter, src: QPointF, dst: QPointF, col: QColor, label: str):
        pen = QPen(QColor(col.red(), col.green(), col.blue(), 60))
        pen.setWidth(1)
        pen.setStyle(Qt.PenStyle.DashLine)
        p.setPen(pen)
        path = self._bezier_path(src, dst)
        p.drawPath(path)
        if label:
            self._draw_edge_label(p, src, dst, label, col)

    def _draw_animated_edge(self, p: QPainter, src: QPointF, dst: QPointF, col: QColor, label: str):
        """Aresta com partícula animada mostrando fluxo de dados."""
        # Linha de fundo
        pen = QPen(QColor(col.red(), col.green(), col.blue(), 50))
        pen.setWidth(1)
        p.setPen(pen)
        path = self._bezier_path(src, dst)
        p.drawPath(path)

        # Partícula animada
        t = self._anim_phase
        bx = self._bezier_point(src, dst, t)

        grad = QRadialGradient(bx, 5)
        grad.setColorAt(0.0, QColor(col.red(), col.green(), col.blue(), 220))
        grad.setColorAt(1.0, QColor(col.red(), col.green(), col.blue(), 0))
        p.setBrush(QBrush(grad))
        p.setPen(Qt.PenStyle.NoPen)
        p.drawEllipse(bx, 5, 5)

        # Seta
        self._draw_arrow(p, src, dst, col, 120)

        if label:
            self._draw_edge_label(p, src, dst, label, col)

    def _bezier_path(self, src: QPointF, dst: QPointF) -> QPainterPath:
        path = QPainterPath(src)
        dx = (dst.x() - src.x()) * 0.45
        cp1 = QPointF(src.x() + dx, src.y())
        cp2 = QPointF(dst.x() - dx, dst.y())
        path.cubicTo(cp1, cp2, dst)
        return path

    def _bezier_point(self, src: QPointF, dst: QPointF, t: float) -> QPointF:
        dx = (dst.x() - src.x()) * 0.45
        cp1 = QPointF(src.x() + dx, src.y())
        cp2 = QPointF(dst.x() - dx, dst.y())
        # De Casteljau
        def lerp(a: QPointF, b: QPointF, t: float) -> QPointF:
            return QPointF(a.x() + (b.x()-a.x())*t, a.y() + (b.y()-a.y())*t)
        l1 = lerp(src, cp1, t)
        l2 = lerp(cp1, cp2, t)
        l3 = lerp(cp2, dst, t)
        l4 = lerp(l1, l2, t)
        l5 = lerp(l2, l3, t)
        return lerp(l4, l5, t)

    def _draw_arrow(self, p: QPainter, src: QPointF, dst: QPointF, col: QColor, alpha: int):
        angle = math.atan2(dst.y() - src.y(), dst.x() - src.x())
        arrow_len = 8
        arrow_angle = 0.4
        tip = dst
        l1 = QPointF(
            tip.x() - arrow_len * math.cos(angle - arrow_angle),
            tip.y() - arrow_len * math.sin(angle - arrow_angle),
        )
        l2 = QPointF(
            tip.x() - arrow_len * math.cos(angle + arrow_angle),
            tip.y() - arrow_len * math.sin(angle + arrow_angle),
        )
        path = QPainterPath(l1)
        path.lineTo(tip)
        path.lineTo(l2)
        pen = QPen(QColor(col.red(), col.green(), col.blue(), alpha))
        pen.setWidth(2)
        pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        p.setPen(pen)
        p.drawPath(path)

    def _draw_edge_label(self, p: QPainter, src: QPointF, dst: QPointF, label: str, col: QColor):
        mid = QPointF((src.x() + dst.x()) / 2, (src.y() + dst.y()) / 2 - 8)
        font = QFont("SF Mono, Menlo, Monaco, monospace", 8)
        p.setFont(font)
        p.setPen(QColor(col.red(), col.green(), col.blue(), 100))
        fm = QFontMetrics(font)
        tw = fm.horizontalAdvance(label)
        p.drawText(int(mid.x() - tw/2), int(mid.y()), label)

    def _draw_node(self, p: QPainter, node: NodeDef, w: int, h: int):
        rect = self._node_rect(node, w, h)
        state     = self.state.get_node_state(node["id"])
        tier_col  = TIER_COLORS.get(node["tier"], TIER_COLORS["neutral"])
        state_col = STATE_COLORS.get(state, STATE_COLORS["idle"])
        is_hover  = (node["id"] == self._hover_node)
        shape     = KIND_SHAPES.get(node["kind"], "rounded_rect")

        # Glow se ativo
        if state in ("running", "completed", "error"):
            self._draw_glow(p, rect, state_col)

        # Fundo do nó
        if shape == "diamond":
            self._draw_diamond(p, rect, tier_col, state_col, state, is_hover)
        elif shape == "hexagon":
            self._draw_hexagon(p, rect, tier_col, state_col, state, is_hover)
        elif shape == "stadium":
            self._draw_stadium(p, rect, tier_col, state_col, state, is_hover)
        else:
            self._draw_rounded_rect(p, rect, tier_col, state_col, state, is_hover)

        # Texto
        self._draw_node_text(p, rect, node, tier_col, state)

    def _draw_glow(self, p: QPainter, rect: QRectF, col: QColor):
        cx, cy = rect.center().x(), rect.center().y()
        r = max(rect.width(), rect.height()) * 0.85
        grad = QRadialGradient(cx, cy, r)
        grad.setColorAt(0.0, QColor(col.red(), col.green(), col.blue(), 35))
        grad.setColorAt(1.0, QColor(col.red(), col.green(), col.blue(), 0))
        p.setBrush(QBrush(grad))
        p.setPen(Qt.PenStyle.NoPen)
        p.drawEllipse(int(cx - r), int(cy - r), int(r*2), int(r*2))

    def _node_bg_brush(self, state: str) -> QBrush:
        if state == "idle":
            return QBrush(QColor("#18181F"))
        col = STATE_COLORS[state]
        bg = QColor(col.red(), col.green(), col.blue(), 20)
        return QBrush(bg)

    def _node_border_pen(self, tier_col: QColor, state_col: QColor, state: str, hover: bool) -> QPen:
        if state not in ("idle",):
            col = state_col
            alpha = 200 if hover else 160
        else:
            col = tier_col
            alpha = 120 if hover else 60
        pen = QPen(QColor(col.red(), col.green(), col.blue(), alpha))
        pen.setWidth(2 if hover or state not in ("idle",) else 1)
        return pen

    def _draw_rounded_rect(self, p, rect, tier_col, state_col, state, hover):
        p.setBrush(self._node_bg_brush(state))
        p.setPen(self._node_border_pen(tier_col, state_col, state, hover))
        p.drawRoundedRect(rect, 8, 8)

        # Faixa de cor no topo
        top_strip = QRectF(rect.x(), rect.y(), rect.width(), 3)
        p.setBrush(QBrush(tier_col))
        p.setPen(Qt.PenStyle.NoPen)
        p.drawRoundedRect(top_strip, 2, 2)

    def _draw_diamond(self, p, rect, tier_col, state_col, state, hover):
        cx = rect.center().x()
        cy = rect.center().y()
        hw = rect.width()  * 0.55
        hh = rect.height() * 0.65
        path = QPainterPath()
        path.moveTo(cx, cy - hh)
        path.lineTo(cx + hw, cy)
        path.lineTo(cx, cy + hh)
        path.lineTo(cx - hw, cy)
        path.closeSubpath()
        p.setBrush(self._node_bg_brush(state))
        p.setPen(self._node_border_pen(tier_col, state_col, state, hover))
        p.drawPath(path)

    def _draw_hexagon(self, p, rect, tier_col, state_col, state, hover):
        cx = rect.center().x()
        cy = rect.center().y()
        r  = min(rect.width(), rect.height()) * 0.50
        path = QPainterPath()
        for i in range(6):
            angle = math.radians(60 * i - 30)
            px = cx + r * math.cos(angle)
            py = cy + r * math.sin(angle)
            if i == 0:
                path.moveTo(px, py)
            else:
                path.lineTo(px, py)
        path.closeSubpath()
        p.setBrush(self._node_bg_brush(state))
        p.setPen(self._node_border_pen(tier_col, state_col, state, hover))
        p.drawPath(path)

        # Linha de tier no centro
        pen = QPen(QColor(tier_col.red(), tier_col.green(), tier_col.blue(), 80))
        pen.setWidth(1)
        p.setPen(pen)
        p.drawLine(int(cx - r*0.4), int(cy), int(cx + r*0.4), int(cy))

    def _draw_stadium(self, p, rect, tier_col, state_col, state, hover):
        p.setBrush(self._node_bg_brush(state))
        p.setPen(self._node_border_pen(tier_col, state_col, state, hover))
        p.drawRoundedRect(rect, rect.height()/2, rect.height()/2)

    def _draw_node_text(self, p, rect: QRectF, node: NodeDef, tier_col: QColor, state: str):
        is_diamond   = KIND_SHAPES.get(node["kind"]) == "diamond"
        is_hexagon   = KIND_SHAPES.get(node["kind"]) == "hexagon"
        text_area    = QRectF(rect.x()+4, rect.y()+8, rect.width()-8, rect.height()-8)

        # Label principal
        font = QFont("SF Pro Text, Helvetica Neue, Arial", 9, QFont.Weight.Bold)
        p.setFont(font)
        col = QColor(tier_col.red(), tier_col.green(), tier_col.blue(), 230)
        p.setPen(col)
        p.drawText(
            text_area, Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop,
            node["label"]
        )

        # Subtitle
        font2 = QFont("SF Pro Text, Helvetica Neue, Arial", 7)
        p.setFont(font2)
        p.setPen(QColor("#888899"))
        sub_area = QRectF(rect.x()+4, rect.y()+22, rect.width()-8, rect.height()-22)
        p.drawText(
            sub_area, Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop,
            node["subtitle"]
        )

        # Indicador de estado (ponto pequeno embaixo)
        state_col = STATE_COLORS.get(state, STATE_COLORS["idle"])
        p.setBrush(QBrush(state_col))
        p.setPen(Qt.PenStyle.NoPen)
        dot_x = int(rect.center().x() - 3)
        dot_y = int(rect.bottom() - 8)
        p.drawEllipse(dot_x, dot_y, 6, 6)
