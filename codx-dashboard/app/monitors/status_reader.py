"""
StatusReader — Lê periodicamente métricas de log do Claude Desktop/Code
e do sistema operacional para atualizar estado dos fluxos.
Sem API claude. Lê apenas arquivos locais e processos do sistema.
Compatível com macOS e Linux.
"""

import os
import sys
import platform
import threading
import time
import subprocess
import json
from pathlib import Path
from datetime import datetime

from data.state import AppState


def _build_log_paths():
    """Constrói lista de caminhos de log baseado no SO."""
    home = os.path.expanduser("~")
    paths = [
        # Claude Code (CLI) — funciona em qualquer SO
        os.path.join(home, ".claude", "logs", "claude.log"),
        os.path.join(home, ".claude", "logs", "main.log"),
        os.path.join(home, ".claude.log"),
        # Claude Code — logs de projetos (glob)
        os.path.join(home, ".claude", "projects", "*", "logs", "*.log"),
    ]

    system = platform.system()
    if system == "Darwin":
        # macOS — Claude Desktop (app Electron)
        paths.extend([
            os.path.join(home, "Library", "Logs", "Claude", "claude.log"),
            os.path.join(home, "Library", "Application Support", "Claude", "logs", "main.log"),
            os.path.join(home, "Library", "Logs", "Claude", "main.log"),
        ])
    elif system == "Linux":
        # Linux — locais comuns para Claude Desktop/Code
        paths.extend([
            os.path.join(home, ".config", "claude", "logs", "claude.log"),
            os.path.join(home, ".config", "claude", "logs", "main.log"),
            os.path.join(home, ".local", "share", "claude", "logs", "*.log"),
            # Snap / Flatpak
            os.path.join(home, "snap", "claude", "common", "logs", "*.log"),
        ])

    return paths


CLAUDE_LOG_PATHS = _build_log_paths()

# Arquivo de IPC que os agentes escrevem (opcional)
IPC_DIR = os.environ.get(
    "CODX_IPC_DIR",
    os.path.expanduser("~/.codx/ipc")
)


class StatusReader(threading.Thread):
    """
    Thread que:
    1. Verifica se Claude (Desktop ou Code) está rodando
    2. Lê tail do log do Claude
    3. Lê arquivos IPC que agentes escrevem (se existirem)
    """
    daemon = True

    # PID do próprio processo (para excluir da detecção)
    _OWN_PID = str(os.getpid())

    def __init__(self, state: AppState):
        super().__init__(name="StatusReader")
        self.state   = state
        self._stop   = threading.Event()
        self._log_fd = None
        self._log_path: str = ""
        self._sim_mode = False
        self._last_claude_status: str = ""  # evita flood de eventos repetidos

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

        # Tenta caminhos configurados
        for pattern in CLAUDE_LOG_PATHS:
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

        # Fallback: procura qualquer .log ou .jsonl dentro de ~/.claude/
        claude_home = Path.home() / ".claude"
        if claude_home.exists():
            all_logs = list(claude_home.rglob("*.log")) + list(claude_home.rglob("*.jsonl"))
            # Ordena por mais recente
            all_logs.sort(key=lambda p: p.stat().st_mtime if p.exists() else 0, reverse=True)
            for path in all_logs:
                try:
                    self._log_fd   = open(str(path), "r", encoding="utf-8", errors="replace")
                    self._log_path = str(path)
                    self._log_fd.seek(0, 2)
                    self.state.push_event("StatusReader", f"Monitorando log (auto): {path}", "info")
                    return
                except Exception:
                    pass

        # Sem log real → modo simulação
        self._sim_mode = True
        self.state.push_event("StatusReader", "Claude log não encontrado — modo demo ativo", "warn")

    def _check_claude_running(self):
        """Verifica se o processo Claude (Desktop ou Code) está ativo."""
        try:
            found = False
            label = ""

            # 1. Verifica sessão ativa via ~/.claude/ (Claude Code cria arquivos de sessão)
            claude_dir = Path.home() / ".claude"
            if claude_dir.exists():
                # Procura por arquivos de lock / sessão recentes
                for marker in ["CLAUDE.md", ".claude.json"]:
                    # Procura em projetos ativos
                    for f in claude_dir.glob(f"projects/**/{marker}"):
                        if f.exists():
                            # Arquivo existe → pode haver sessão
                            age = time.time() - f.stat().st_mtime
                            if age < 300:  # modificado nos últimos 5 min
                                found = True
                                label = "Claude Code: sessão ativa (projeto recente)"
                                break
                    if found:
                        break

            # 2. Verifica processos
            if not found:
                # pgrep -f busca no cmdline completo; filtra nosso próprio PID
                result = subprocess.run(
                    ["pgrep", "-af", "claude"],
                    capture_output=True, text=True, timeout=2
                )
                if result.returncode == 0:
                    own_pid = self._OWN_PID
                    for line in result.stdout.strip().splitlines():
                        pid = line.split()[0] if line.split() else ""
                        if pid == own_pid:
                            continue
                        # Ignora o próprio dashboard (python rodando este script)
                        if "status_reader" in line or "codx-dashboard" in line or "dashboard.py" in line:
                            continue
                        # Match real
                        found = True
                        if "node" in line.lower() or "claude" in line.lower():
                            label = "Claude Code: sessão ativa"
                        else:
                            label = "Claude: sessão ativa"
                        break

            # 3. Publica evento apenas se mudou de estado (evita flood)
            new_status = "active" if found else "inactive"
            if new_status != self._last_claude_status:
                self._last_claude_status = new_status
                if found:
                    self.state.push_event("system", label, "info")
                else:
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
