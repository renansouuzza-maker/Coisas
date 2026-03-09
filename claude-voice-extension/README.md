# Claude Voice — Interface de Voz para Claude.ai

Extensao de navegador que adiciona controle por voz ao [claude.ai](https://claude.ai). Fale com o Claude e ouca suas respostas automaticamente.

**100% gratuito. Sem API keys. Sem limites. Tudo roda localmente no navegador.**

## Funcionalidades

- **Fala para Texto** — Clique no microfone (ou pressione `Alt+Espaco`) e fale. Sua voz e transcrita em tempo real e enviada automaticamente para o Claude.
- **Texto para Fala** — As respostas do Claude sao lidas em voz alta automaticamente. Blocos de codigo sao ignorados por padrao.
- **Modo Automatico** — Sem comandos manuais. Fale, espere o silencio, e a mensagem e enviada. Quando o Claude responde, a leitura comeca sozinha.
- **Configuravel** — Idioma, voz, velocidade, tempo de silencio, tudo ajustavel no popup de configuracoes.
- **Arrastavel** — O botao do microfone pode ser movido para qualquer posicao na tela.

## Instalacao

### Chrome / Edge / Brave

1. Baixe ou clone este repositorio
2. Abra `chrome://extensions/` no navegador
3. Ative o **Modo do desenvolvedor** (canto superior direito)
4. Clique em **Carregar sem compactacao**
5. Selecione a pasta `claude-voice-extension`
6. Abra [claude.ai](https://claude.ai) — o botao de microfone aparecera no canto inferior direito

### Firefox

> **Nota:** O Firefox tem suporte limitado a Web Speech API. A extensao funciona melhor em navegadores baseados em Chromium.

## Como Usar

1. Abra [claude.ai](https://claude.ai)
2. Clique no botao do microfone (canto inferior direito) ou pressione `Alt + Espaco`
3. Fale normalmente — a transcricao aparece em tempo real
4. Apos um periodo de silencio (padrao: 2s), a mensagem e enviada automaticamente
5. Quando o Claude terminar de responder, a resposta e lida em voz alta
6. Pressione `Esc` para parar a leitura a qualquer momento

## Configuracoes

Clique no icone da extensao na barra de ferramentas para acessar:

| Configuracao | Descricao | Padrao |
|---|---|---|
| Idioma | Idioma do reconhecimento de voz | Portugues (Brasil) |
| Voz | Voz usada para leitura | Padrao do sistema |
| Velocidade | Velocidade da leitura (0.5x - 2.0x) | 1.0x |
| Enviar automaticamente | Envia apos detectar silencio | Ativado |
| Ler respostas | Le respostas do Claude em voz alta | Ativado |
| Ler blocos de codigo | Inclui codigo na leitura | Desativado |
| Tempo de silencio | Segundos de silencio antes de enviar | 2s |

## Atalhos de Teclado

| Atalho | Acao |
|---|---|
| `Alt + Espaco` | Ativar/desativar microfone |
| `Esc` | Parar leitura em voz alta |

## Estados do Botao

- **Cinza** — Inativo, pronto para uso
- **Vermelho (pulsante)** — Ouvindo, capturando audio
- **Azul (ondulante)** — Falando, lendo resposta

## Tecnologias

- [Web Speech API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API) — Reconhecimento de voz e sintese de fala nativos do navegador
- [Chrome Extensions Manifest V3](https://developer.chrome.com/docs/extensions/mv3/) — Formato moderno de extensao
- Sem dependencias externas. Sem frameworks. JavaScript puro.

## Limitacoes

- Funciona apenas em navegadores baseados em Chromium (Chrome, Edge, Brave, Opera)
- O reconhecimento de voz requer conexao com a internet (o navegador usa servidores do Google para STT)
- Os seletores do DOM do claude.ai podem mudar com atualizacoes do site

## Licenca

[MIT](LICENSE) — Use, modifique e distribua livremente.
