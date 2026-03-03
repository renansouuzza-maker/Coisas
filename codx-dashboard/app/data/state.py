"""
Estado global da aplicação. Thread-safe.
Gerencia status de agentes, tarefas e eventos.
"""

import threading
from typing import Dict, Any, List, Optional
from datetime import datetime
from collections import deque


AGENTS = [
    "obliv-brand", "nexus-rh", "nxs-rh", "engex-construcao",
    "espaco-singular", "human-arch", "avia-saude", "adv-lab",
    "blenx", "veracci-luxo", "shalon-varejo", "maker-digital",
    "bliv-orchestrator",
]

NODE_STATES = ("idle", "running", "completed", "error", "waiting")


class Event:
    def __init__(self, source: str, message: str, level: str = "info"):
        self.source  = source
        self.message = message
        self.level   = level   # info | warn | error | success
        self.ts      = datetime.now()

    def formatted(self) -> str:
        return f"[{self.ts.strftime('%H:%M:%S')}] [{self.source}] {self.message}"


class AppState:
    def __init__(self):
        self._lock = threading.Lock()
        self._agents: Dict[str, Dict[str, Any]] = {
            a: {"status": "idle", "tasks": 0, "last_seen": None}
            for a in AGENTS
        }
        self._node_states: Dict[str, str] = {}   # node_id → state
        self._events: deque = deque(maxlen=200)   # log de eventos
        self._workflow_runs: Dict[str, Any] = {}  # workflow_id → info

    # ── Agentes ───────────────────────────────────────────────────────────────

    def get_agent_status(self, agent_id: str) -> str:
        with self._lock:
            return self._agents.get(agent_id, {}).get("status", "idle")

    def get_agent_tasks(self, agent_id: str) -> int:
        with self._lock:
            return self._agents.get(agent_id, {}).get("tasks", 0)

    def set_agent_status(self, agent_id: str, status: str, tasks: int = 0):
        with self._lock:
            if agent_id not in self._agents:
                self._agents[agent_id] = {}
            self._agents[agent_id].update({
                "status": status,
                "tasks": tasks,
                "last_seen": datetime.now(),
            })

    # ── Nós ───────────────────────────────────────────────────────────────────

    def get_node_state(self, node_id: str) -> str:
        with self._lock:
            return self._node_states.get(node_id, "idle")

    def set_node_state(self, node_id: str, state: str):
        with self._lock:
            self._node_states[node_id] = state

    def set_node_states_bulk(self, updates: Dict[str, str]):
        with self._lock:
            self._node_states.update(updates)

    # ── Eventos ───────────────────────────────────────────────────────────────

    def push_event(self, source: str, message: str, level: str = "info"):
        ev = Event(source, message, level)
        with self._lock:
            self._events.appendleft(ev)
        return ev

    def get_events(self, limit: int = 50) -> List[Event]:
        with self._lock:
            return list(self._events)[:limit]

    # ── Stats ─────────────────────────────────────────────────────────────────

    def get_stats(self) -> Dict[str, int]:
        with self._lock:
            statuses = [a["status"] for a in self._agents.values()]
            return {
                "total":  len(AGENTS),
                "active": statuses.count("running"),
                "errors": statuses.count("error"),
                "idle":   statuses.count("idle"),
            }

    # ── Demo / Simulação ──────────────────────────────────────────────────────

    def simulate_activity(self):
        """Popula estado com dados simulados para demo."""
        import random
        for agent in AGENTS:
            s = random.choice(["idle", "idle", "running", "running", "idle", "error"])
            t = random.randint(0, 5) if s == "running" else 0
            self.set_agent_status(agent, s, t)

        # Nós ativos
        demo_nodes = {
            "bliv_recv": "running", "creative": "running",
            "aprovacao": "waiting", "reenzi": "completed",
            "bliv": "running", "nexus": "completed",
            "veracci": "running",
        }
        self.set_node_states_bulk(demo_nodes)
