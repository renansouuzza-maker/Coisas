# PSD Importer — Figma Plugin (Open Source)

Plugin open-source para importar arquivos Adobe Photoshop (.psd/.psb) no Figma com camadas preservadas.

## Funcionalidades

- **Importação de camadas**: preserva a hierarquia de grupos e camadas do PSD
- **Textos editáveis**: importa camadas de texto como texto nativo do Figma
- **Imagens rasterizadas**: importa camadas de imagem com transparência
- **Blend modes**: converte modos de mesclagem do Photoshop para equivalentes no Figma
- **Opacidade**: preserva a opacidade original de cada camada
- **Camadas ocultas**: opção para incluir ou ignorar camadas invisíveis
- **Drag & drop**: arraste o arquivo .psd direto na interface

## Tecnologias

- [ag-psd](https://github.com/Agamnentzar/ag-psd) — parser JavaScript open-source para arquivos PSD
- [Figma Plugin API](https://www.figma.com/plugin-docs/) — API oficial para criação de plugins
- [esbuild](https://esbuild.github.io/) — bundler ultrarrápido
- TypeScript

## Como usar

### Desenvolvimento local

```bash
# Instalar dependências
npm install

# Build
npm run build

# Modo watch (recompila ao salvar)
npm run watch
```

### Instalar no Figma

1. No Figma Desktop, vá em **Plugins → Development → Import plugin from manifest...**
2. Selecione o arquivo `manifest.json` deste diretório
3. O plugin aparecerá no menu **Plugins → Development → PSD Importer**

### Usar o plugin

1. Abra o plugin no Figma
2. Arraste um arquivo `.psd` ou `.psb` na área de drop (ou clique para selecionar)
3. Configure as opções:
   - **Importar textos como editáveis**: converte textos do PSD para texto nativo do Figma
   - **Preservar opacidade das camadas**: mantém a opacidade original
   - **Importar camadas ocultas**: inclui camadas que estavam invisíveis no Photoshop
4. Aguarde o processamento — as camadas serão criadas automaticamente

## Estrutura do projeto

```
figma-psd-importer/
├── manifest.json    # Manifesto do plugin Figma
├── package.json     # Dependências e scripts
├── tsconfig.json    # Configuração TypeScript
├── code.ts          # Lógica principal do plugin
├── ui.html          # Interface do usuário
└── README.md        # Este arquivo
```

## Limitações conhecidas

- Efeitos avançados do Photoshop (smart objects, filtros, adjustment layers) são importados como retângulos placeholder
- Fontes precisam estar disponíveis no Figma — caso contrário, Inter é usada como fallback
- Arquivos muito grandes (>100MB) podem demorar mais para processar
- Vetores complexos do Photoshop são simplificados

## Licença

MIT License — use, modifique e distribua livremente.
