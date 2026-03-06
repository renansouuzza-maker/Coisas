"""
StatusReader — Lê periodicamente métricas de log do Claude Desktop
e do sistema operacional para atualizar estado dos fluxos.
Sem API claude. Lê apenas arquivos locais e processos do sistema.
"""

import os
import threading
import time
import subprocess
import json
from pathlib import Path
from datetime import datetime

from data.state import AppState


# Log do Claude Desktop e Claude Code (macOS)
CLAUDE_LOG_PATHS = [
    # Claude Code (CLI / desktop sessions)
    os.path.expanduser("~/.claude/logs/claude.log"),
    os.path.expanduser("~/.claude/logs/main.log"),
    os.path.expanduser("~/.claude.log"),
    # Claude Desktop (app Electron)
    os.path.expanduser("~/Library/Logs/Claude/claude.log"),
    os.path.expanduser("~/Library/Application Support/Claude/logs/main.log"),
    os.path.expanduser("~/Library/Logs/Claude/main.log"),
    # Claude Code — diretório de projetos (logs locais)
    os.path.expanduser("~/.claude/projects/*/logs/*.log"),
]

# Arquivo de IPC que os agentes escrevem (opcional)
IPC_DIR = os.environ.get(
    "CODX_IPC_DIR",
    os.path.expanduser("~/.codx/ipc")
)


class StatusReader(threading.Thread):
    """
    Thread que:
    1. Verifica se Claude.app está rodando
    2. Lê tail do log do Claude Desktop
    3. Lê arquivos IPC que agentes escrevem (se existirem)
    """
    daemon = True

    def __init__(self, state: AppState):
        super().__init__(name="StatusReader")
        self.state   = state
        self._stop   = threading.Event()
        self._log_fd = None
        self._log_path: str = ""
        self._sim_mode = False

    def run(self):
        self._setup_log()
        while not self._stop.is_set():
            self._check_claude_running()
            self._read_log_tail()
            self._read_ipc()
            if self._sim_mode:
                self._simulate_node_events()
            time.sleep(2)

    def _setup_log(self):
        import glob as globmod
        for pattern in CLAUDE_LOG_PATHS:
            # Suporta glob patterns (ex: ~/.claude/projects/*/logs/*.log)
            matched = globmod.glob(pattern) if "*" in pattern else [pattern]
            for path in sorted(matched, key=lambda p: Path(p).stat().st_mtime if Path(p).exists() else 0, reverse=True):
                if Path(path).exists():
                    try:
                        self._log_fd   = open(path, "r", encoding="utf-8", errors="replace")
                        self._log_path = path
                        self._log_fd.seek(0, 2)  # vai pro final
                        self.state.push_event("StatusReader", f"Monitorando log: {path}", "info")
                        return
                    except Exception:
                        pass
        # Sem log real → modo simulação
        self._sim_mode = True
        self.state.push_event("StatusReader", "Claude log não encontrado — modo demo ativo", "warn")

    def _check_claude_running(self):
        """Verifica se o processo Claude (Desktop ou Code) está ativo."""
        try:
            # Tenta detectar Claude Desktop ou Claude Code
            for proc_name in ["Claude", "claude"]:
                result = subprocess.run(
                    ["pgrep", "-xi", proc_name],
                    capture_output=True, text=True, timeout=2
                )
                if result.returncode == 0:
                    self.state.push_event(
                        "system", f"Claude ({proc_name}): sessão ativa", "info"
                    )
                    return

            # Fallback: verifica se há processo node rodando claude
            result = subprocess.run(
                ["pgrep", "-f", "claude"],
                capture_output=True, text=True, timeout=2
            )
            if result.returncode == 0:
                self.state.push_event("system", "Claude Code: sessão ativa", "info")
                return

            self.state.push_event("system", "Claude: nenhuma sessão ativa", "warn")
        except Exception:
            pass

    def _read_log_tail(self):
        if not self._log_fd:
            return
        try:
            for line in self._log_fd:
                line = line.strip()
                if not line:
                    continue
                self._parse_log_line(line)
        except Exception:
            pass

    def _parse_log_line(self, line: str):
        """Extrai eventos relevantes do log do Claude."""
        lower = line.lower()
        level = "info"

        if "error" in lower or "exception" in lower:
            level = "error"
        elif "warn" in lower:
            level = "warn"
        elif "success" in lower or "complete" in lower:
            level = "success"

        # Detecta agente no log via padrão "[agent-name]"
        agent = "claude"
        for marker in [
            "obliv", "nexus", "veracci", "maker", "shalon",
            "bliv", "human-arch", "avia", "blenx", "adv-lab",
        ]:
            if marker in lower:
                agent = marker
                break

        # Trunca linha longa
        msg = line[:120] + ("..." if len(line) > 120 else "")
        self.state.push_event(agent, msg, level)

    def _read_ipc(self):
        """
        Lê arquivos IPC que agentes podem escrever.
        Formato esperado: JSON com campos agent_id, status, node_id, node_state.
        """
        ipc = Path(IPC_DIR)
        if not ipc.exists():
            return
        try:
            for f in ipc.glob("*.json"):
                try:
                    data = json.loads(f.read_text())
                    if "agent_id" in data and "status" in data:
                        self.state.set_agent_status(
                            data["agent_id"],
                            data["status"],
                            data.get("tasks", 0)
                        )
                    if "node_id" in data and "node_state" in data:
                        self.state.set_node_state(data["node_id"], data["node_state"])
                    # Remove após ler (one-shot)
                    f.unlink(missing_ok=True)
                except Exception:
                    pass
        except Exception:
            pass

    def _simulate_node_events(self):
        """Anima os nós em modo demo quando não há dados reais."""
        import random
        # Alterna estados dos nós para simular atividade
        sim_sequences = [
            # Produção Semanal
            [
                ("reenzi", "completed"), ("bliv_recv", "running"),
                ("creative", "waiting"),
            ],
            [
                ("bliv_recv", "completed"), ("creative", "running"),
                ("aprovacao", "waiting"),
            ],
            [
                ("creative", "completed"), ("aprovacao", "running"),
                ("bliv_copy", "waiting"),
            ],
            [
                ("aprovacao", "completed"), ("bliv_copy", "running"),
                ("cd_fill", "waiting"),
            ],
            [
                ("bliv_copy", "completed"), ("cd_fill", "running"),
                ("freepik", "running"), ("cleaner", "running"),
            ],
            [
                ("cd_fill", "completed"), ("freepik", "completed"),
                ("cleaner", "completed"), ("psd", "running"),
            ],
            [
                ("psd", "completed"), ("export", "running"),
            ],
            [
                ("export", "completed"),
            ],
        ]

        # Cicla a cada ~16s (8 passos × 2s)
        idx = (int(time.time()) // 2) % len(sim_sequences)
        for node_id, node_state in sim_sequences[idx]:
            self.state.set_node_state(node_id, node_state)

        # CEO dashboard
        ceo_cycle = (int(time.time()) // 4) % 4
        ceo_nodes = [
            [("trigger", "completed"), ("bliv", "running")],
            [("bliv", "running"), ("nexus", "running"), ("veracci", "running"),
             ("maker", "running"), ("shalon", "running"), ("obliv", "running")],
            [("nexus", "completed"), ("veracci", "completed"),
             ("maker", "running"), ("shalon", "running"), ("obliv", "completed"),
             ("consolida", "running")],
            [("consolida", "completed"), ("report", "running")],
        ]
        for node_id, node_state in ceo_nodes[ceo_cycle]:
            self.state.set_node_state(node_id, node_state)

    def stop(self):
        self._stop.set()
        if self._log_fd:
            self._log_fd.close()
