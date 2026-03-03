"""
Definições de todos os Workflows do CodX Empire.
Formato: lista de nós e arestas compatível com FlowCanvas.
"""

from typing import TypedDict, List, Optional


class NodeDef(TypedDict):
    id: str
    label: str
    subtitle: str
    x: float          # posição normalizada 0–1
    y: float
    kind: str         # "agent" | "process" | "io" | "decision" | "parallel" | "export"
    tier: str         # "core" | "premium" | "corporate" | "volume" | "labs" | "neutral"


class EdgeDef(TypedDict):
    src: str
    dst: str
    label: str
    style: str        # "solid" | "dashed" | "animated"
    parallel: bool


class WorkflowDef(TypedDict):
    id: str
    title: str
    nodes: List[NodeDef]
    edges: List[EdgeDef]


# ─────────────────────────────────────────────────────────────────────────────
#  FLUXO 1 — Produção de Conteúdo Semanal
# ─────────────────────────────────────────────────────────────────────────────
PRODUCAO_SEMANAL: WorkflowDef = {
    "id": "producao_semanal",
    "title": "Produção de Conteúdo Semanal",
    "nodes": [
        {"id": "reenzi",       "label": "REENZI",         "subtitle": "Pedido semanal",        "x": 0.05, "y": 0.45, "kind": "io",       "tier": "core"},
        {"id": "bliv_recv",    "label": "BLIV",           "subtitle": "Recebe pedido",          "x": 0.18, "y": 0.45, "kind": "agent",    "tier": "core"},
        {"id": "creative",     "label": "CreativeDirector","subtitle": "Scaffold + calendário", "x": 0.33, "y": 0.45, "kind": "process",  "tier": "neutral"},
        {"id": "aprovacao",    "label": "Aprovação",      "subtitle": "Reenzi valida",          "x": 0.45, "y": 0.45, "kind": "decision", "tier": "neutral"},
        {"id": "bliv_copy",    "label": "BLIV",           "subtitle": "Escreve copy",           "x": 0.57, "y": 0.45, "kind": "agent",    "tier": "core"},
        {"id": "cd_fill",      "label": "CreativeDirector","subtitle": "Preenche briefings",    "x": 0.70, "y": 0.45, "kind": "process",  "tier": "neutral"},
        {"id": "freepik",      "label": "FreepikFlux",    "subtitle": "Gera imagens",           "x": 0.82, "y": 0.28, "kind": "process",  "tier": "premium"},
        {"id": "cleaner",      "label": "AssetCleaner",   "subtitle": "Remove fundo",           "x": 0.82, "y": 0.62, "kind": "process",  "tier": "neutral"},
        {"id": "psd",          "label": "PSDAssembler",   "subtitle": "Monta composição",       "x": 0.91, "y": 0.45, "kind": "process",  "tier": "neutral"},
        {"id": "export",       "label": "Export PNG",     "subtitle": "Artes finais",           "x": 1.00, "y": 0.45, "kind": "export",   "tier": "volume"},
    ],
    "edges": [
        {"src": "reenzi",    "dst": "bliv_recv", "label": "linguagem natural", "style": "animated", "parallel": False},
        {"src": "bliv_recv", "dst": "creative",  "label": "parseia pedido",    "style": "solid",    "parallel": False},
        {"src": "creative",  "dst": "aprovacao", "label": "calendário",        "style": "solid",    "parallel": False},
        {"src": "aprovacao", "dst": "bliv_copy", "label": "aprovado ✓",        "style": "animated", "parallel": False},
        {"src": "bliv_copy", "dst": "cd_fill",   "label": "copy",              "style": "solid",    "parallel": False},
        {"src": "cd_fill",   "dst": "freepik",   "label": "briefings",         "style": "solid",    "parallel": True},
        {"src": "cd_fill",   "dst": "cleaner",   "label": "briefings",         "style": "solid",    "parallel": True},
        {"src": "freepik",   "dst": "psd",       "label": "imagens",           "style": "solid",    "parallel": False},
        {"src": "cleaner",   "dst": "psd",       "label": "assets limpos",     "style": "solid",    "parallel": False},
        {"src": "psd",       "dst": "export",    "label": "composição",        "style": "animated", "parallel": False},
    ],
}


# ─────────────────────────────────────────────────────────────────────────────
#  FLUXO 2 — Dashboard CEO (Status Cross-Office)
# ─────────────────────────────────────────────────────────────────────────────
DASHBOARD_CEO: WorkflowDef = {
    "id": "dashboard_ceo",
    "title": "Status Cross-Office — Dashboard CEO",
    "nodes": [
        {"id": "trigger",    "label": "/dashboard-ceo", "subtitle": "Slash command",        "x": 0.05, "y": 0.45, "kind": "io",      "tier": "core"},
        {"id": "bliv",       "label": "BLIV",           "subtitle": "Orquestra leituras",   "x": 0.20, "y": 0.45, "kind": "agent",   "tier": "core"},
        {"id": "nexus",      "label": "NEXUS",          "subtitle": "Lê status.md",         "x": 0.40, "y": 0.15, "kind": "process", "tier": "corporate"},
        {"id": "veracci",    "label": "VERACCI",        "subtitle": "Lê status.md",         "x": 0.40, "y": 0.32, "kind": "process", "tier": "premium"},
        {"id": "maker",      "label": "MAKER",          "subtitle": "Lê status.md",         "x": 0.40, "y": 0.50, "kind": "process", "tier": "core"},
        {"id": "shalon",     "label": "SHALON",         "subtitle": "Lê status.md",         "x": 0.40, "y": 0.67, "kind": "process", "tier": "volume"},
        {"id": "obliv",      "label": "OBLIV",          "subtitle": "Lê status.md",         "x": 0.40, "y": 0.84, "kind": "process", "tier": "core"},
        {"id": "consolida",  "label": "BLIV",           "subtitle": "Consolida KPIs",       "x": 0.68, "y": 0.45, "kind": "agent",   "tier": "core"},
        {"id": "report",     "label": "Relatório CEO",  "subtitle": "Apresenta Reenzi",     "x": 0.88, "y": 0.45, "kind": "export",  "tier": "neutral"},
    ],
    "edges": [
        {"src": "trigger",  "dst": "bliv",      "label": "",              "style": "animated", "parallel": False},
        {"src": "bliv",     "dst": "nexus",     "label": "lê status",     "style": "dashed",   "parallel": True},
        {"src": "bliv",     "dst": "veracci",   "label": "lê status",     "style": "dashed",   "parallel": True},
        {"src": "bliv",     "dst": "maker",     "label": "lê status",     "style": "dashed",   "parallel": True},
        {"src": "bliv",     "dst": "shalon",    "label": "lê status",     "style": "dashed",   "parallel": True},
        {"src": "bliv",     "dst": "obliv",     "label": "lê status",     "style": "dashed",   "parallel": True},
        {"src": "nexus",    "dst": "consolida", "label": "kpis",          "style": "solid",    "parallel": False},
        {"src": "veracci",  "dst": "consolida", "label": "kpis",          "style": "solid",    "parallel": False},
        {"src": "maker",    "dst": "consolida", "label": "kpis",          "style": "solid",    "parallel": False},
        {"src": "shalon",   "dst": "consolida", "label": "kpis",          "style": "solid",    "parallel": False},
        {"src": "obliv",    "dst": "consolida", "label": "kpis",          "style": "solid",    "parallel": False},
        {"src": "consolida","dst": "report",    "label": "relatório",     "style": "animated", "parallel": False},
    ],
}


# ─────────────────────────────────────────────────────────────────────────────
#  FLUXO 3 — Onboarding Novo Escritório
# ─────────────────────────────────────────────────────────────────────────────
ONBOARDING: WorkflowDef = {
    "id": "onboarding",
    "title": "Onboarding — Novo Escritório",
    "nodes": [
        {"id": "dados",      "label": "Dados Cliente",   "subtitle": "Input Reenzi",          "x": 0.05, "y": 0.45, "kind": "io",      "tier": "neutral"},
        {"id": "bliv",       "label": "BLIV",            "subtitle": "Recebe dados",           "x": 0.20, "y": 0.45, "kind": "agent",   "tier": "core"},
        {"id": "estrutura",  "label": "Criar Pastas",    "subtitle": "ESCRITORIOS/{cliente}/", "x": 0.38, "y": 0.30, "kind": "process", "tier": "neutral"},
        {"id": "brain",      "label": "Criar _BRAIN",    "subtitle": "alma + status + regras", "x": 0.38, "y": 0.60, "kind": "process", "tier": "core"},
        {"id": "governance", "label": "GovernanceBuilder","subtitle": "Extrai DNA do PSD",     "x": 0.58, "y": 0.30, "kind": "process", "tier": "premium"},
        {"id": "regras",     "label": "regras_design.md","subtitle": "Identidade visual",      "x": 0.58, "y": 0.60, "kind": "process", "tier": "neutral"},
        {"id": "agente",     "label": "Criar Agente",    "subtitle": ".claude/agents/*.md",    "x": 0.76, "y": 0.45, "kind": "process", "tier": "core"},
        {"id": "checklist",  "label": "Checklist",       "subtitle": "Confirma onboarding",    "x": 0.92, "y": 0.45, "kind": "export",  "tier": "volume"},
    ],
    "edges": [
        {"src": "dados",      "dst": "bliv",       "label": "dados brutos",  "style": "animated", "parallel": False},
        {"src": "bliv",       "dst": "estrutura",  "label": "cria estrutura", "style": "solid",   "parallel": True},
        {"src": "bliv",       "dst": "brain",      "label": "cria _BRAIN",   "style": "solid",    "parallel": True},
        {"src": "estrutura",  "dst": "governance", "label": "pasta pronta",  "style": "solid",    "parallel": False},
        {"src": "brain",      "dst": "regras",     "label": "alma.md",       "style": "solid",    "parallel": False},
        {"src": "governance", "dst": "agente",     "label": "DNA extraído",  "style": "solid",    "parallel": False},
        {"src": "regras",     "dst": "agente",     "label": "regras visuais","style": "solid",    "parallel": False},
        {"src": "agente",     "dst": "checklist",  "label": "agente criado", "style": "animated", "parallel": False},
    ],
}


# ─────────────────────────────────────────────────────────────────────────────
#  FLUXO 4 — Design Factory Engine v1.3.0
# ─────────────────────────────────────────────────────────────────────────────
DESIGN_FACTORY: WorkflowDef = {
    "id": "design_factory",
    "title": "Design Factory Engine v1.3.0",
    "nodes": [
        {"id": "pedido",      "label": "Pedido",          "subtitle": "Linguagem natural",       "x": 0.04, "y": 0.45, "kind": "io",      "tier": "neutral"},
        {"id": "creative",    "label": "CreativeDirector","subtitle": "Planeja → scaffold",      "x": 0.18, "y": 0.45, "kind": "process", "tier": "neutral"},
        {"id": "bliv_copy",   "label": "BLIV",            "subtitle": "Escreve copy (zero API)", "x": 0.33, "y": 0.45, "kind": "agent",   "tier": "core"},
        {"id": "cd_json",     "label": "CreativeDirector","subtitle": "Valida JSON schema",      "x": 0.47, "y": 0.45, "kind": "process", "tier": "neutral"},
        {"id": "decoder",     "label": "BlivBrandDecoder","subtitle": "Extrai identidade visual","x": 0.62, "y": 0.25, "kind": "process", "tier": "premium"},
        {"id": "flux",        "label": "FreepikFluxEngine","subtitle": "Gera imagens Freepik",   "x": 0.62, "y": 0.65, "kind": "process", "tier": "premium"},
        {"id": "cleaner",     "label": "AssetCleaner",    "subtitle": "Remove fundo + normaliza","x": 0.76, "y": 0.45, "kind": "process", "tier": "neutral"},
        {"id": "psd",         "label": "PSDAssembler",    "subtitle": "ExtendScript → Photoshop","x": 0.88, "y": 0.45, "kind": "process", "tier": "corporate"},
        {"id": "png",         "label": "PNG Final",       "subtitle": "06_Exportacoes/",         "x": 1.00, "y": 0.45, "kind": "export",  "tier": "volume"},
    ],
    "edges": [
        {"src": "pedido",    "dst": "creative",  "label": "natural lang",    "style": "animated", "parallel": False},
        {"src": "creative",  "dst": "bliv_copy", "label": "scaffold",        "style": "solid",    "parallel": False},
        {"src": "bliv_copy", "dst": "cd_json",   "label": "copy",            "style": "solid",    "parallel": False},
        {"src": "cd_json",   "dst": "decoder",   "label": "briefings JSON",  "style": "solid",    "parallel": True},
        {"src": "cd_json",   "dst": "flux",      "label": "briefings JSON",  "style": "solid",    "parallel": True},
        {"src": "decoder",   "dst": "cleaner",   "label": "brand identity",  "style": "solid",    "parallel": False},
        {"src": "flux",      "dst": "cleaner",   "label": "imagens brutas",  "style": "solid",    "parallel": False},
        {"src": "cleaner",   "dst": "psd",       "label": "assets limpos",   "style": "solid",    "parallel": False},
        {"src": "psd",       "dst": "png",       "label": "composição",      "style": "animated", "parallel": False},
    ],
}


WORKFLOWS = {
    "producao_semanal": PRODUCAO_SEMANAL,
    "dashboard_ceo":    DASHBOARD_CEO,
    "onboarding":       ONBOARDING,
    "design_factory":   DESIGN_FACTORY,
}
