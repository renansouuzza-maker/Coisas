# CodX Empire — Dashboard de Fluxos

> Popup desktop macOS. Zero terminal. Zero browser.
> Monitora workflows do CodX Empire em tempo real com nós animados.

---

## Instalação (uma linha)

```bash
cd codx-dashboard && ./scripts/install.sh
```

O script:
1. Detecta Python 3.10+ instalado
2. Cria `.venv/` isolado com PyQt6
3. Gera `CodX Dashboard.app` em `~/Applications/`
4. Registra LaunchAgent → **inicia sozinho no login**
5. Abre o popup imediatamente

---

## Uso

- **Popup**: aparece automaticamente ao ligar o Mac
- **Tray icon** (barra de menu): clique para mostrar/ocultar
- **Arrastar**: clique e arraste no header para mover
- **Abas**: Produção Semanal / Dashboard CEO / Onboarding / Design Factory

---

## Estrutura de Nós

| Forma       | Tipo       |
|-------------|------------|
| ◇ Diamante  | IO / Decisão (input do Reenzi, aprovações) |
| ⬡ Hexágono  | Agente (BLIV, agentes de escritório) |
| ▭ Arredondado | Processo (CreativeDirector, AssetCleaner) |
| ⬭ Stadium   | Export (PNG final, relatórios) |

### Estados dos nós

| Cor | Estado |
|-----|--------|
| 🔵 Azul | Completo |
| 🟢 Verde | Rodando |
| 🟡 Amarelo | Aguardando |
| 🔴 Vermelho | Erro |
| ⚫ Cinza | Idle |

---

## Monitoramento Real

O dashboard lê dados de:
1. **`_BRAIN/status.md`** de cada escritório (detecta mudanças em tempo real)
2. **Log do Claude Desktop** (`~/Library/Logs/Claude/`)
3. **IPC files** em `~/.codx/ipc/` (agentes escrevem aqui)

### Enviando status do seu agente

```python
# Em qualquer script do CodX
from ipc_writer import report_workflow_step

report_workflow_step("nexus-rh", "cd_fill", "running", tasks=3)
```

---

## Configuração

Edite `config/empire_config.json` para:
- Ajustar caminho dos escritórios (`empire_root`)
- Mudar refresh interval
- Modificar tamanho da janela

---

## Requisitos

- macOS 12+ (Monterey ou superior)
- Python 3.10+
- Claude Desktop instalado (para integração de logs)

---

## Desinstalar

```bash
./scripts/uninstall.sh
```

---

*"Não fazemos gambiarras. Construímos catedrais."*
— CodX Empire
