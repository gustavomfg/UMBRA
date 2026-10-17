# Nocturne Greeter — Umbra 0.9

Preview em Quickshell/QML + GLSL: um corpo obsidiano com matéria orbital, identidade de eclipse e autenticação em uma coluna editorial. O preview executa dentro da sessão atual. A fase 0.8 provou o login real (greetd + PAM + sessão Wayland + boot) **somente dentro de uma VM descartável**; nesta máquina nada altera display manager, PAM, boot ou serviços de login.

![Nocturne em idle](docs/screenshots/final/1920x1080-idle.png)

## Iniciar

Os comandos abaixo partem da raiz do clone; os scripts resolvem o próprio caminho e podem ser chamados de qualquer diretório.

```sh
./scripts/run-preview.sh
```

Abre em tela cheia no monitor primário. `Ctrl+Q` encerra; `Alt+F4` também fecha.

```sh
NOCTURNE_WINDOWED=1 NOCTURNE_WIDTH=1280 NOCTURNE_HEIGHT=720 ./scripts/run-preview.sh
```

Em compositores com tiling, a geometria solicitada pode ser substituída pelo layout do compositor. As dimensões efetivas guiam a composição.

## Interações

- Clique no fundo ou pressione uma tecla: WAKE, seguido de AUTH; campo recebe foco imediatamente.
- Digitação: pontos mascarados e perturbação mínima da matéria orbital.
- `Enter` ou seta: tentativa simulada, seguida de falha curta em lilás.
- `Ctrl+Enter`: sucesso visual de preview, convergência e preto. Não autentica ninguém.
- `Esc`: fecha menu aberto; no fluxo de autenticação retorna ao idle e limpa a senha.
- Sessão: mostra o ambiente atual. Energia: abre controles explicitamente desabilitados.
- Rede, áudio e bateria são somente leitura. Bateria só aparece quando aplicável.

O preview não registra nem persiste a senha. Use texto de teste, pois não existe autenticação real.

Para revelar os controles de desenvolvimento:

```sh
NOCTURNE_DEBUG=1 ./scripts/run-preview.sh
```

`NOCTURNE_USER_NAME` permite alterar apenas o nome exibido; por padrão usa `USER`. Hostname usa `HOSTNAME`/`HOST`, com fallback “Local system”. A interface está em inglês; a data segue o locale do Qt.

## Arquitetura

| Arquivo | Papel |
| --- | --- |
| `shell.qml` | Entrada do preview |
| `components/GreeterWindow.qml` | Composição responsiva, foco, relógio do shader |
| `components/GreeterController.qml` | IDLE → WAKE → AUTH → AUTHENTICATING → SUCCESS/FAILURE; retorno ao idle |
| `components/PreviewAuthenticator.qml` | Adaptador simulado, cancelamento de tentativa pendente |
| `components/CosmicScene.qml` | Uniforms e ShaderEffect |
| `components/AuthPanel.qml` | Identidade, senha mascarada, feedback |
| `components/ClockDisplay.qml` | Relógio editorial e data |
| `components/SystemChrome.qml`, `IconButton.qml` | Indicadores e menus com dados fornecidos pelo entrypoint |
| `components/LiveSystemStatus.qml` | Rede, áudio, bateria e sessão somente no preview da sessão atual |
| `components/AuthenticatorBridge.qml` | Fronteira entre state machine e backend |
| `components/GreetdAuthenticator.qml` | Adapter para `Quickshell.Services.Greetd`; `launch()` só com argv fixo da política e geração pronta |
| `components/SessionLaunchGate.qml` | Libera o lançamento só após o quadro preto ser apresentado (`wp_presentation`) |
| `components/SessionLaunchPolicy.qml` | Política administrativa: arquivos de usuários, catálogo de sessões, estado e comandos de energia |
| `components/GreeterCatalog.qml`, `greeter-model.js` | Usuários (`/etc/passwd` + `login.defs`), sessões do catálogo, última escolha |
| `system/` | Gerador do catálogo, verificação do módulo, hooks do pacman, tmpfiles, config/drop-in do greetd |
| `packaging/arch/` | PKGBUILD local (`makepkg -si`) |
| `greeter/shell.qml` | Entrada pré-login para greetd (sem preview, captura, debug ou mock) |
| `presentation/` | Módulo C++ `Nocturne.Presentation` (`PresentationProbe`) |
| `vm/` | Controle da VM descartável (`nocturne-vm.py`) e instalação do pacote no guest |
| `components/PreviewCapture.qml` | Captura opt-in, ausente do fluxo normal |
| `shaders/pulse.frag`, `.qsb` | Esfera e planos orbitais analíticos; pacote Qt |
| `assets/` | Marca e ícones SVG próprios |

Fontes instaladas: **Noto Sans Light** no relógio; **Adwaita Sans** na interface; **Adwaita Mono** apenas no debug. Nenhuma fonte ou dependência foi baixada. O preview usa Quickshell e serviços de rede, PipeWire e UPower; o harness usa dados mock e funciona sem barramento de sessão. Build/testes usam as ferramentas Qt 6 já instaladas.

## Harness Wayland isolado 0.7

```sh
./scripts/run-isolated-greeter.sh
```

Abre KWin Wayland **aninhado** em uma janela da sessão atual, cria socket/runtime/D-Bus próprios e carrega uma cópia temporária do Umbra com backend mock por padrão. `Enter` produz falha mock; `--mock-success` avalia o SUCCESS visual sem autenticar nem lançar sessão. Encerre com `Ctrl+C` no terminal. Os logs ficam em `logs/isolated-greeter/`.

Para testar sem D-Bus de sessão ou capturar um estado:

```sh
./scripts/run-isolated-greeter.sh --no-session-bus --duration 10
./scripts/run-isolated-greeter.sh --scenario success
./scripts/test-greetd-protocol.sh
```

O último comando executa o módulo Greetd instalado contra um socket fixture local dentro do KWin aninhado. O fixture não roda greetd, PAM ou comandos de sessão; nesses cenários rejeita `start_session` (só o cenário `launch-acknowledged`, usado por `test-launch-gate-e2e.sh`, confirma o pedido, ainda sem executar nada). O harness **não** altera o Plasma Login Manager e ainda depende do Wayland/GPU da sessão host como compositor pai. Leia [a integração Greetd 0.7](docs/GREETD_PROTOCOL_0.7.md), [o relatório completo 0.6](docs/ISOLATED_GREETER_HARNESS_0.6.md) e [a arquitetura de login 0.5](docs/REAL_LOGIN_ARCHITECTURE_0.5.md) antes de considerar qualquer passo pré-login real.

## Verificação e capturas

```sh
./scripts/build-shader.sh
./scripts/test-greeter.sh
./scripts/lint-qml.sh
./scripts/test-greetd-protocol.sh
./scripts/test-real-login-vm-guard.sh
./scripts/build-presentation-probe.sh
./scripts/test-greetd-adapter.sh
./scripts/test-launch-gate-e2e.sh            # e --no-probe: o lançamento precisa ficar bloqueado
python3 -m unittest tests/test_sessions_catalog.py
```

Os testes Qt Quick offscreen verificam estados, teclado, clique/foco e submissão. Não substituem avaliação visual.

```sh
cd nocturne-greeter   # raiz do clone
./scripts/capture-preview.sh
```

A captura abre previews temporários em tela cheia, um processo por estado. Em 1920×1080 inclui também `typing-long` para revisar o limite visual dos pontos da senha. Renderiza canvases Qt nas dimensões 1280×720, 1920×1080, 2560×1440 e 3440×1440 sem alterar a resolução do monitor. Saída: `docs/screenshots/final/`. Não equivale a testar quatro monitores físicos. O layer adicional existe somente no modo de captura.

Veja [a revisão e suas limitações](docs/ART_DIRECTION_REVIEW.md), [o sistema visual](DESIGN.md) e [as referências estudadas](docs/REFERENCE_NOTES.md).

## Captura temporal longa

Para manter o shader rodando em idle ou AUTH por cerca de 30 segundos e salvar uma imagem de verificação (use um diretório já existente):

```sh
NOCTURNE_CAPTURE_DIR=/tmp NOCTURNE_CAPTURE_STATE=idle-long ./scripts/run-preview.sh
NOCTURNE_CAPTURE_DIR=/tmp NOCTURNE_CAPTURE_STATE=auth-long ./scripts/run-preview.sh
```

Cada execução encerra depois da captura. Isso permite conferir a fase orbital após espera; não é uma gravação de vídeo.

## Histórico e snapshots

O primeiro histórico público descreve o estado atual Umbra 0.6 em commits temáticos, sem reconstruir versões históricas. Snapshots e scripts locais de restauração dependem de `backups/`, que não é distribuído. Para recuperar o estado publicado, use os commits Git disponíveis no clone.

## Fronteira de autenticação e lançamento

`AuthenticatorBridge` normaliza mock e `GreetdAuthenticator`, incluindo prompt secreto/visível, mensagens, cancelamento e geração por tentativa. Depois de `readyToLaunch`, o SUCCESS termina, uma cena preta opaca cobre a janela e `SessionLaunchGate` arma `wp_presentation_feedback` na superfície exata do Umbra. Só o evento `presented` para esse commit libera `Greetd.launch(argv fixo, env, quit=true)`, uma única vez. Sem o módulo, com `discarded` ou timeout, o lançamento fica bloqueado e o greeter reinicia. O argv vem apenas do catálogo `/var/lib/nocturne-greeter/sessions.json`, gerado por root a partir de `/usr/share/wayland-sessions`; o greeter nunca interpreta `.desktop`, PATH ou entrada do usuário. Veja [o relatório 0.7](docs/GREETD_PROTOCOL_0.7.md) para a API.

## Real login 0.8 — provado em VM

Resultados, inventário, matriz de falhas e limites em [REAL_LOGIN_VM_0.8.md](docs/REAL_LOGIN_VM_0.8.md). Numa VM Arch descartável (QEMU/KVM sem privilégios no host), o Umbra rodou como greeter real via greetd + Cage, autenticou com o PAM empacotado, apresentou o quadro preto antes de lançar uma sessão Wayland de teste, fez três ciclos de logout e dois boots. O host não foi alterado. GPU física, multi-monitor e PLM continuam não testados.

## 0.9 — usuários, sessões, energia e pacote

Seleção de usuário e sessão (Hyprland, Hyprland via uwsm, Plasma), memória da última escolha, Suspender/Reiniciar/Desligar e um PKGBUILD local, tudo provado na VM. Para instalar neste computador siga o roteiro em [INSTALL_0.9.md](docs/INSTALL_0.9.md); o pacote não habilita o greetd sozinho.
