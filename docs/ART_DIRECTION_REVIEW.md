# Segunda passagem — Nocturne / Umbra

## Direção e resultado

A composição foi refeita como um observatório silencioso: coluna editorial à esquerda, corpo obsidiano oblíquo à direita, preto dominante e luz violeta concentrada na matéria orbital. Relógio e autenticação compartilham o mesmo lugar em momentos separados. Marca e controles acompanham a cena sem formar uma barra de widgets.

O projeto foi inspecionado e executado antes das alterações. A comparação está em [before-idle.png](screenshots/before-idle.png). A arquitetura de estados e o adaptador de preview foram preservados.

## Capturas do runtime

| Resolução | Idle | Auth |
| --- | --- | --- |
| 1280×720 | [Imagem](screenshots/final/1280x720-idle.png) | [Imagem](screenshots/final/1280x720-auth.png) |
| 1920×1080 | [Imagem](screenshots/final/1920x1080-idle.png) | [Imagem](screenshots/final/1920x1080-auth.png) |
| 2560×1440 | [Imagem](screenshots/final/2560x1440-idle.png) | [Imagem](screenshots/final/2560x1440-auth.png) |
| 3440×1440 | [Imagem](screenshots/final/3440x1440-idle.png) | [Imagem](screenshots/final/3440x1440-auth.png) |

Estados adicionais em 1920×1080: [wake](screenshots/final/1920x1080-wake.png), [wake intermediário](screenshots/final/1920x1080-wake-middle.png), [retorno intermediário](screenshots/final/1920x1080-return-middle.png), [digitação](screenshots/final/1920x1080-typing.png), [digitação longa](screenshots/final/1920x1080-typing-long.png), [autenticando](screenshots/final/1920x1080-authenticating.png), [falha](screenshots/final/1920x1080-failure.png), [colapso](screenshots/final/1920x1080-collapse.png), [preto](screenshots/final/1920x1080-black.png), [energia](screenshots/final/1920x1080-power.png), [sessão](screenshots/final/1920x1080-session.png).

São renders reais do Qt nas dimensões indicadas, obtidos por grabToImage/saveToFile; não são mockups. O monitor físico usado foi 1920×1080. As outras resoluções usam um canvas virtual de tamanho exato. Não houve alteração de resolução/configuração do compositor.

## Tipografia e identidade

- Noto Sans Light no relógio: numerais amplos e hierarquia editorial.
- Adwaita Sans no restante: greeting discreto, nome maior, labels em sentence case. A marca escrita usa tracking próprio.
- Adwaita Mono somente na informação opcional de desenvolvimento.
- Fontes já instaladas, sem download ou redistribuição.
- Marca SVG nova: dois crescentes afilados e opostos. Ícones próprios de 24 unidades, traço uniforme de 1,5, extremidades arredondadas. Origem em [assets/README.md](../assets/README.md).

## Hero

O GLSL foi refeito com esfera analítica e planos orbitais inclinados. A comparação de profundidade determina quais partes dos anéis passam à frente ou atrás do corpo. Normais, rim light fino, iluminação discreta da superfície e sombra projetada dão volume. Estratos radiais irregulares, lacunas e poeira quebram a regularidade dos anéis. Uma segunda inclinação adiciona espessura aparente. O enquadramento varia com o aspect ratio e não estica o planeta.

A primeira iteração parecia um disco de vinil luminoso. Reduzi a escala, quebrei a periodicidade radial e contive a iluminação. O resultado ainda possui regularidade procedural; não pretende simular dispersão volumétrica física.

## Auth e indicadores

Greeting reduzido; nome em destaque; senha representada por pontos, segmento curto de foco e seta. Nenhuma caixa grande. Feedback de falha local em lilás. Os comandos técnicos ficam escondidos, revelados por NOCTURNE_DEBUG=1.

Hostname/sessão ficam à esquerda do rodapé; rede/áudio/bateria/energia à direita. Ícones seguem a mesma família. Tooltip fornece detalhes sob demanda. PipeWire tem tracker do sink para manter valores atualizados. Energia permanece desabilitada; sessão apenas informa o ambiente atual.

## Movimento

| Momento | Tratamento |
| --- | --- |
| Idle | Órbitas lentas em velocidades radiais distintas, respiração mínima; atualização do shader a cada 120 ms |
| Wake | Tensão/dolly do hero primeiro; reveal da UI após 160 ms, ao longo de 840 ms |
| Troca de conteúdo | Relógio termina em authReveal .32; identidade começa em .36; campo em .50; hint em .68; sem colisão de textos |
| Digitação | Perturbação geométrica mínima, sem flash; feedback de 280 ms |
| Autenticando | Tensão de 440 ms, alinhamento orbital e velocidade reduzida |
| Falha | Pequeno desalinhamento; sequência total de 650 ms |
| Sucesso | Convergência, expansão do corpo e fechamento da luz em 1480 ms |
| Retorno | 460 ms, reversão da composição e limpeza da senha |
| Controles | Hover/foco/press de 160 ms; menus de 240 ms |

A senha recebe foco durante o wake, antes de terminar sua entrada visual. Não há animações de spring/overshoot ou shockwave.

## Arquivos

Modificados: `components/GreeterWindow.qml`, `GreeterController.qml`, `CosmicScene.qml`, `AuthPanel.qml`, `ClockDisplay.qml`, `SystemChrome.qml`; `shaders/pulse.frag` e `.qsb`; `tests/tst_greeter.qml`; `README.md`; `docs/REFERENCE_NOTES.md`.

Criados: `components/IconButton.qml`, `PreviewCapture.qml`; `assets/nocturne-mark.svg`, `assets/icons/*.svg`, `assets/README.md`; `scripts/capture-preview.sh`, `restore-first-pass.sh`; `PRODUCT.md`, `DESIGN.md`, `.impeccable/design.json`; este relatório e as capturas; `backups/pre-art-direction/`.

Preservados: entrada `shell.qml`, adaptador `PreviewAuthenticator.qml`, scripts originais de execução/build/teste/restauração e backup anterior.

## Testes e correções

- Qt Quick Test: **10 passed, 0 failed**, incluindo setup/cleanup; oito cenários de comportamento. Reexecutados após a última correção de motion.
- Teclado: wake, texto, Enter/falha, Ctrl+Enter/sucesso, Escape/limpeza, repetição rápida.
- Mouse: clique real do QtTest no campo, foco, digitação e botão de submissão.
- Cancelamento de tentativa pendente e prevenção de submissão duplicada.
- qmllint: sem diagnósticos com os imports locais Qt/Quickshell.
- QSB recompilado; glslangValidator SPIR-V concluído.
- Logs das execuções/capturas sem warnings QML ou binding loops observados.
- Bash: syntax check; backup da primeira passagem: todos os SHA-256 conferidos.
- Revisão visual em quatro dimensões, menus e estados de transição, seguida de correção e nova execução.

Correções encontradas durante o processo: modelo negativo no Repeater de pontos durante layout inicial; testes de mouse sem janela visível (`TestCase.visible`); animação de typing concorrendo com reset; captura de typing avançando cedo demais; relógio e identidade sobrepostos no wake/retorno; captura repetida de layers/texto pouco confiável nesta configuração Qt. O capturador agora usa um processo e uma captura por estado. Uma divergência posterior de clipping existia no transporte PNG da ferramenta do revisor; cópias JPEG confirmaram que os arquivos estavam completos. A revisão independente aprovou a correção final da coreografia, sem regressões identificadas nesse escopo. As 18 capturas iniciais desta passagem tiveram as dimensões conferidas; o endpoint de sucesso possui RGB (0,0,0) em todos os pixels.

## Performance observada

Amostra local: fullscreen 1920×1080, quatro segundos de aquecimento e oito segundos de coleta em idle, leitura de `/proc` do processo lançado pelo script. **0,75% de um núcleo de CPU**, RSS **210540 KiB (~206 MiB)**. É uma amostra curta deste sistema, sem benchmark comparativo ou teste de longa duração. GPU não foi medida isoladamente.

Shader: idle ~8,3 Hz, AUTH estável ~15,4 Hz, demais fases ~30,3 Hz. Uniforms animados também podem causar renders durante interação; estes intervalos não são um limite rígido global de frames. Relógio atualiza por minuto. Não há loop JS de partículas por frame. Timer para quando invisível ou no preto final. O layer de captura só é ativado explicitamente.

## Limitações e pontos ainda fracos

- Anéis ainda são mais laminares e contínuos que um campo de fragmentos tridimensionais. Este é o principal limite visual remanescente.
- Corpo quase preto depende da qualidade/contraste do monitor; sombras podem perder detalhe em painéis com black crush.
- Capturas estáticas e leitura dos timings não certificam fluidez temporal percebida nem frame pacing. Não foi gravado vídeo de alta frequência nem medido GPU frame time.
- Ultrawide foi avaliado por render exato, não em monitor físico ultrawide. Portrait não teve revisão visual completa.
- Sem autenticação real, escolha real de usuário/sessão, teclado virtual ou controles de energia ativos.
- Data usa locale Qt; textos de interface estão em inglês. O nome é o usuário de ambiente, não um perfil AccountsService.
- Fontes dependem do sistema instalado. Nenhum pacote foi adicionado.
- Não há detecção automática de preferência por movimento reduzido nesta passagem.

## Próxima integração e execução

Trocar o adaptador simulado por uma ponte de autenticação; implementar modelos reais e capacidades; testar falha, cancelamento e troca de sessão com o backend escolhido antes de qualquer implantação. Não houve alteração no login real.

```sh
./scripts/run-preview.sh
```

Sair: Ctrl+Q. Falha simulada: Enter. Sucesso visual: Ctrl+Enter. Voltar ao idle: Escape.

Restaurar a implementação da primeira passagem:

```sh
./scripts/restore-first-pass.sh
```


# Umbra 0.3 — polish & production readiness

As capturas finais 0.3 foram regeneradas no mesmo diretório; agora são **19 PNGs**. Incluem o estado AUTH com senha longa em 1920×1080.

## Mudanças mantidas

- A primeira tecla imprimível pressionada ainda no idle agora inicia o WAKE e entra na senha no mesmo evento. Modificadores Ctrl/Alt/Meta não são inseridos como texto; Tab continua fora do wake. O campo segue em modo Password e o feedback visual recebe pulso para essa primeira tecla.
- Os pontos da senha têm capacidade derivada da largura disponível. Ao atingir o limite visual, o ponto terminal acompanha as teclas seguintes; a senha continua sujeita ao máximo de 256 caracteres.
- O capturador opcional ganhou estados de digitação longa e espera de 30 s em idle/AUTH para revisão temporal e amostragem. O fluxo normal não carrega o capturador.
- Criado `backups/umbra-approved/` com hashes conferidos e `scripts/restore-umbra-approved.sh`. O backup antecede toda alteração 0.3. Os backups anteriores permanecem intactos.

## Hero e tempo

Revisei o shader ampliado e comparei duas alternativas de distribuição. A primeira introduziu padrões diagonais de amostragem; a segunda mal se distinguia no enquadramento completo. Ambas foram descartadas, e `pulse.frag`/QSB foram restaurados byte a byte ao snapshot aprovado. Nenhuma alteração arbitrária de ruído, cor, composição ou custo do hero ficou no build. As capturas 1920×1080 feitas após ~0,7 s e após ~30,7 s mostram progresso orbital e breathing lentos, sem reinício da variável `shaderTime`. A taxa troca entre 120, 65 e 33 ms por estado; o tempo do shader acumula os intervalos e desacelera por `authenticationTension` suavizada. Essas imagens pontuais não demonstram frame pacing contínuo.

## Regressões cobertas

A suíte cresceu de 10 para **14 testes**: primeira tecla no idle fica retida; backspace continua funcional numa senha longa; o campo satura no máximo de 256 caracteres sem quebrar os pontos; senha vazia e Enter repetido geram somente uma solicitação; Escape cancela tentativa pendente e nenhuma falha atrasada aparece depois do idle. Os testes anteriores de mouse, sucesso/falha, foco e repetição continuam passando.

Validações nesta fase: Qt Quick Test **14 passed, 0 failed**; `qmllint` sem diagnósticos; `bash -n scripts/*.sh`; QSB compilado e `glslangValidator` concluído. Hashes do snapshot Umbra conferidos. Nenhum warning/binding loop surgiu nos logs dos previews capturados.

## Performance observada

Amostras locais em janela cheia 1920×1080, com quatro segundos de aquecimento e oito segundos lendo `/proc`: no preview normal, sem layer de captura, idle mediu **0,625% de um núcleo** e **216292 KiB** (~211 MiB) de RSS. No modo de captura prolongada, cuja composição habilita um layer para salvar a imagem, idle mediu **1,00% / 221348 KiB** (~216 MiB) e AUTH estável **2,25% / 224508 KiB** (~219 MiB). Os valores de AUTH/idle com layer incluem esse custo adicional e não representam o runtime final. A primeira amostra Umbra havia dado 0,75%/206 MiB em idle; diferenças dessa ordem dependem do sistema, compositor e carga. Uma amostra curta não é benchmark. GPU e frame time não foram isolados.

## Limites restantes

- O material orbital conserva estrias radiais visíveis sob ampliação. As variantes testadas ou ficaram visualmente inconsequentes ou trouxeram aliasing; manter a referência aprovada tem melhor equilíbrio.
- Capturas de 30 s verificam estado tardio, não continuidade quadro a quadro; não há gravação de alta frequência nem medição específica de GPU.
- A rota de primeira tecla foi verificada no helper usado pelo roteador, e a máquina completa passou QML Test; não foi possível interagir com a superfície nativa via ferramenta CUA nesta sessão (nenhum app/window foi exposto). Os previews de captura reais cobriram todos os estados funcionais.
- Sem autenticação/power reais, sem detector de movimento reduzido; nada desta fase configura o greeter no boot.

## Preview e restauração

```sh
./scripts/run-preview.sh
./scripts/restore-umbra-approved.sh
```

Arquivos com alterações de implementação na fase 0.3: `components/AuthPanel.qml`, `components/GreeterWindow.qml`, `components/PreviewCapture.qml`, `tests/tst_greeter.qml` e `scripts/capture-preview.sh`. Documentação: `README.md` e este relatório. Novo restore/snapshot: `scripts/restore-umbra-approved.sh` e `backups/umbra-approved/`. O shader compilado final, a marca, a composição, o par tipográfico e os ícones são idênticos à Umbra aprovada.
