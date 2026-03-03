"""
FileWatcher — Monitora o sistema de arquivos do CodX Empire em tempo real.
Usa watchdog quando disponível, fallback para polling.
"""

import os
import threading
import time
from pathlib import Path
from typing import Optional

from data.state import AppState


# Caminho raiz dos escritórios (configurável via env)
EMPIRE_ROOT = os.environ.get(
    "CODX_EMPIRE_ROOT",
    os.path.expanduser("~/CodX/ESCRITORIOS")
)

ESCRITORIOS = [
    ("OBLIV",           "obliv-brand"),
    ("NEXUS",           "nexus-rh"),
    ("NXS",             "nxs-rh"),
    ("ENGEX",           "engex-construcao"),
    ("ESPACO_SINGULAR", "espaco-singular"),
    ("HUMAN_ARCH",      "human-arch"),
    ("AVIA",            "avia-saude"),
    ("ADV_PROJECT",     "adv-lab"),
    ("BLENX",           "blenx"),
    ("VERACCI",         "veracci-luxo"),
    ("SHALON",          "shalon-varejo"),
    ("MAKER",           "maker-digital"),
]


class FileWatcher(threading.Thread):
    """
    Thread que monitora os status.md de cada escritório e
    atualiza o AppState conforme detecta mudanças.
    """
    daemon = True

    def __init__(self, state: AppState):
        super().__init__(name="FileWatcher")
        self.state = state
        self._stop_ev = threading.Event()
        self._last_mtimes: dict = {}
        self._use_watchdog = self._try_import_watchdog()

    def _try_import_watchdog(self) -> bool:
        try:
            import watchdog  # noqa
            return True
        except ImportError:
            return False

    def run(self):
        if self._use_watchdog:
            self._run_watchdog()
        else:
            self._run_polling()

    def _run_polling(self):
        """Polling a cada 3s como fallback se watchdog não disponível."""
        interval = 3
        while not self._stop_ev.is_set():
            self._scan_all()
            time.sleep(interval)

    def _run_watchdog(self):
        from watchdog.observers import Observer
        from watchdog.events import FileSystemEventHandler

        watcher = self

        class Handler(FileSystemEventHandler):
            def on_modified(self, ev):
                if ev.src_path.endswith("status.md"):
                    watcher._handle_status_change(ev.src_path)
            def on_created(self, ev):
                if ev.src_path.endswith("status.md"):
                    watcher._handle_status_change(ev.src_path)

        obs = Observer()
        root = Path(EMPIRE_ROOT)
        if root.exists():
            obs.schedule(Handler(), str(root), recursive=True)
        obs.start()
        while not self._stop_ev.is_set():
            time.sleep(1)
        obs.stop()
        obs.join()

    def _scan_all(self):
        root = Path(EMPIRE_ROOT)
        if not root.exists():
            # Sem escritório real → simula atividade
            self.state.simulate_activity()
            return

        for folder, agent_id in ESCRITORIOS:
            status_file = root / folder / "_BRAIN" / "status.md"
            if status_file.exists():
                mtime = status_file.stat().st_mtime
                if self._last_mtimes.get(str(status_file)) != mtime:
                    self._last_mtimes[str(status_file)] = mtime
                    self._handle_status_change(str(status_file), agent_id)

    def _handle_status_change(self, path: str, agent_id: Optional[str] = None):
        if not agent_id:
            # Tenta derivar o agent_id a partir do path
            for folder, aid in ESCRITORIOS:
                if folder in path:
                    agent_id = aid
                    break

        if not agent_id:
            return

        try:
            content = Path(path).read_text(encoding="utf-8")
            self._parse_and_update(agent_id, content)
        except Exception:
            pass

    def _parse_and_update(self, agent_id: str, content: str):
        """Extrai informações básicas do status.md."""
        status = "idle"
        tasks  = 0

        lower = content.lower()
        if "em andamento" in lower or "running" in lower or "ativo" in lower:
            status = "running"
            # Conta itens de lista com checkbox aberto
            tasks = lower.count("- [ ]")
        elif "erro" in lower or "error" in lower or "falha" in lower:
            status = "error"
        elif "concluído" in lower or "done" in lower or "completo" in lower:
            status = "completed"

        self.state.set_agent_status(agent_id, status, tasks)
        self.state.push_event(agent_id, f"status.md atualizado → {status}", "info")

    def stop(self):
        self._stop_ev.set()
