"""
IPC Writer — Utilitário para agentes Claude enviarem status ao dashboard.
Use este módulo dentro dos agentes/scripts do CodX para atualizar o dashboard.

Uso:
    from ipc_writer import report_node, report_agent

    report_agent("nexus-rh", "running", tasks=3)
    report_node("bliv_recv", "running")
"""

import json
import os
import time
from pathlib import Path

IPC_DIR = Path(os.environ.get("CODX_IPC_DIR", Path.home() / ".codx" / "ipc"))


def _write(data: dict):
    IPC_DIR.mkdir(parents=True, exist_ok=True)
    filename = IPC_DIR / f"{int(time.time()*1000)}_{os.getpid()}.json"
    filename.write_text(json.dumps(data), encoding="utf-8")


def report_agent(agent_id: str, status: str, tasks: int = 0):
    """
    Reporta status de um agente ao dashboard.

    Args:
        agent_id: ID do agente (ex: "nexus-rh", "bliv-orchestrator")
        status: "idle" | "running" | "completed" | "error" | "waiting"
        tasks: número de tarefas em andamento
    """
    _write({"agent_id": agent_id, "status": status, "tasks": tasks})


def report_node(node_id: str, state: str):
    """
    Reporta estado de um nó de workflow ao dashboard.

    Args:
        node_id: ID do nó (ex: "bliv_recv", "creative", "psd")
        state: "idle" | "running" | "completed" | "error" | "waiting"
    """
    _write({"node_id": node_id, "node_state": state})


def report_workflow_step(agent_id: str, node_id: str, state: str, tasks: int = 0):
    """Combina report_agent e report_node em uma só chamada."""
    _write({
        "agent_id":   agent_id,
        "status":     state,
        "tasks":      tasks,
        "node_id":    node_id,
        "node_state": state,
    })
