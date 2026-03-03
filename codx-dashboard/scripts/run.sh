#!/usr/bin/env bash
# Executa o CodX Dashboard diretamente (sem instalar)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$ROOT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "Ambiente virtual não encontrado. Execute ./scripts/install.sh primeiro."
    exit 1
fi

source "$VENV_DIR/bin/activate"
export CODX_ROOT="$ROOT_DIR"
exec python "$ROOT_DIR/app/main.py" "$@"
