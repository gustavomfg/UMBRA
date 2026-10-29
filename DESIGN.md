---
name: Nocturne — Umbra
description: Um observatório silencioso para a transição entre tempo e identidade.
colors:
  black: "#000000"
  text: "#F2F2F3"
  secondary: "#A6A6B0"
  quiet: "#777781"
  placeholder: "#92929E"
  lilac: "#A78BFA"
  purple: "#8B5CF6"
  graphite: "#111116"
  menu-active: "#1C1C24"
  outline: "#34343D"
  surface-edge: "#292930"
typography:
  display:
    fontFamily: "Noto Sans"
    fontSize: "88px"
    fontWeight: 300
    letterSpacing: "-3px"
  identity:
    fontFamily: "Adwaita Sans"
    fontSize: "37px"
    fontWeight: 400
    letterSpacing: "-0.6px"
  body:
    fontFamily: "Adwaita Sans"
    fontSize: "15px"
    fontWeight: 400
  date:
    fontFamily: "Adwaita Sans"
    fontSize: "14px"
    fontWeight: 400
  label:
    fontFamily: "Adwaita Sans"
    fontSize: "12px"
    fontWeight: 400
  wordmark:
    fontFamily: "Adwaita Sans"
    fontSize: "13px"
    fontWeight: 500
    letterSpacing: "3.5px"
rounded:
  popover: "10px"
  tooltip: "5px"
spacing:
  compact: "10px"
  label-gap: "12px"
  surface-inset: "18px"
components:
  icon-button:
    width: "40px"
    height: "40px"
  icon-button-hover:
    backgroundColor: "{colors.graphite}"
  popover:
    backgroundColor: "{colors.graphite}"
    rounded: "{rounded.popover}"
    padding: "{spacing.surface-inset}"
  password:
    height: "60px"
    textColor: "{colors.text}"
    typography: "{typography.body}"
---

# Design System: Nocturne — Umbra

## Overview

**Creative North Star: "Um observatório silencioso"**

O Nocturne usa preto como espaço, um corpo celeste quase apagado como presença e matéria orbital prateada/violeta como luz. A interface tem densidade baixa, tipografia legível e movimento amortecido. O gesto recorrente é a abertura: a marca deixa o preto atravessar duas crescentes; o campo de senha deixa os pontos flutuarem sem uma caixa.

A direção substitui o visual anterior com autorização explícita do usuário. O contrato continua: tempo e identidade compartilham uma coluna; tensão gravitacional precede a identidade; a senha surge em seguida; no sucesso, matéria converge e a luz fecha. O shader procedural e as capturas reais de QML são a autoridade visual. Não há imagem conceitual usada como substituto da implementação.

**Key Characteristics:**

- Preto AMOLED com luz orbital localizada.
- Hierarquia editorial e interface em sentence case.
- Marca e ícones vetoriais originais, com geometria consistente.
- Movimento amortecido com foco imediato e revelação escalonada.

O exercício de forma usou o seed **c9abc37a**. O brief explícito Umbra / singularity planet governou a escolha; alternativas de catálogo incompatíveis com a paleta, o espaço cinematográfico e a interface esparsa foram descartadas. A disciplina aproveitada foi a consistência geométrica dos pequenos ícones. A produção é código QML, GLSL e SVG; não existe dependência raster ou Blender no runtime.

## Colors

Preto, grafite e cinzas frios sustentam uma única família de acento violeta.

### Primary

- **Lilac:** foco, feedback de falha e a segunda crescente da marca.
- **Purple:** referência cromática da matéria no shader; sua constante GLSL é uma aproximação normalizada da paleta. O shader mistura essa cor com prata violeta e iluminação calculada, sem preencher o fundo.

### Neutral

- **Black:** fundo integral e destino do sucesso.
- **Text:** relógio e identidade do usuário.
- **Secondary:** data, greeting, ícones e sessão.
- **Quiet:** hostname e hints secundários.
- **Placeholder:** convite idle e texto do campo vazio.
- **Graphite:** hover e superfícies dos popovers.
- **Outline:** separador e foco inativo; **surface-edge** delimita os popovers.

**The Reserved Light Rule.** O acento acompanha foco, matéria e feedback; fundos grandes permanecem pretos ou grafite.

## Typography

**Display Font:** Noto Sans Light, exclusivamente para o relógio.

**Body Font:** Adwaita Sans, em pesos normal e medium.

**Label/Mono Font:** Adwaita Mono somente no modo de debug. As fontes são instaladas no sistema; o projeto não as distribui. Não há fallback nomeado no QML: Qt resolve ausência de uma família.

As medidas dos tokens são pixels lógicos na escala base. Tamanhos, tracking e grande parte dos espaços multiplicam `uiScale`; a altura de linha continua a métrica nativa da fonte.

### Hierarchy

- **Display:** numerais abertos e leves; horário em `HH:mm`.
- **Identity:** nome real/selecionado pelo ambiente, com elisão à direita.
- **Body:** greeting e campo de senha, sem uppercase.
- **Date:** data local e título do popover de sessão.
- **Label:** hints e identificação de sistema.
- **Wordmark:** token da identidade visual; a tela de login não exibe a marca no topo.

Os convites idle e as linhas de power usam o tamanho da wordmark sem seu peso/tracking. Notas dos popovers atualmente usam 11 px; debug usa 10 px. São exceções observadas, não um novo padrão de texto funcional pequeno. O tooltip mantém 12 px sem multiplicar a escala.

**The Shared Column Rule.** O relógio desaparece antes de a identidade ocupar sua coluna; a troca não sobrepõe as duas hierarquias.

## Layout

A composição implementada tem coluna editorial à esquerda, fenômeno à direita e dois pequenos grupos de controles no rodapé. O topo permanece livre, sem símbolo ou texto NOCTURNE. Não há painel envolvendo a autenticação nem linha contínua de status.

- `uiScale = clamp(height / 900, 1, 1.35)`.
- Margem lateral: `clamp(width × 0.075, 42, 220)`.
- Coluna: `min(width × 0.27, 340 × uiScale)`; origem vertical em 35% da altura.
- Hero: largura `min(width × 0.79, height × 1.85)`, altura 84%; centro em 66% da largura e 51% da altura.
- Acima de aspect ratio 2.1, o centro horizontal do hero passa a 65%.
- Abaixo de aspect ratio 1.45, hero em cima, coluna a 63% da altura, largura limitada por margens e `380 × uiScale`; hero com largura de 115% e altura de 66%, centro em 58%/35%.
- Rodapé: controles de 40 unidades e afastamento inferior de 28 unidades, ambos escalados.

Estas fórmulas descrevem esta tela; não obrigam outras superfícies Nocturne a copiar a mesma composição. As capturas em quatro resoluções são evidência de renderização virtual do Qt, não testes físicos de quatro monitores.

## Elevation & Depth

A UI usa camadas tonais e nenhum efeito de sombra ou blur. No hero, a esfera analítica possui normal, superfície escura, rim light fino e sombra sobre planos orbitais inclinados. A comparação de profundidade oculta os trechos posteriores dos anéis; estratos radiais, poeira e uma segunda inclinação criam matéria. O movimento lento altera rotação e iluminação; a aproximação é uma transformação procedural sutil, sem câmera 3D ou mesh.

**The Quiet Surface Rule.** Profundidade vem do fenômeno e da oclusão. Controles usam camadas tonais e contornos finos, sem sombras ou blur decorativos.

## Shapes

O símbolo usa duas crescentes opostas, afiladas e separadas por preto, em uma prancheta vetorial de 40 unidades. Ícones têm prancheta de 24 unidades, traço de 1.5 unidades e terminais/arremates arredondados. São paths SVG, não glifos de fonte.

Controles compactos são circulares. Popovers usam o raio de superfície, tooltips usam o raio menor, e a senha usa pontos circulares. A linha de foco é curta; não desenha a largura total de um formulário.

## Components

### Icon buttons

Alvo circular de 40 unidades, ícone de 19 unidades. O submit amplia o alvo a 44 unidades. Em hover/foco aparece grafite; o foco ganha contorno lilás de 1 px. A imagem contrai a 0.92 durante o clique, com resposta de 160 ms OutCubic. A opacidade da superfície usa 160 ms. Indicadores de rede/áudio/bateria usam o mesmo desenho, mas sem ação nem foco por Tab.

### Password

Pontos de 5 unidades, espaçamento de 10 unidades, corte pela largura disponível. O TextInput nativo mantém teclado, acessibilidade e proteção de senha, enquanto a representação gráfica evita a caixa convencional. O último ponto responde com escala máxima 1.16; não há flash. Linha de foco cresce de 18 para 42 unidades em 240 ms OutCubic. Enter envia a resposta ao backend ativo; Escape cancela e retorna ao idle. Somente no preview, Ctrl+Enter aciona o sucesso simulado. O segredo não vira texto de debug.

### Session and system status

Hostname e sessão ficam à esquerda; rede, áudio, bateria quando presente e power ficam à direita. Os ícones de rede e áudio permanecem visíveis mesmo sem serviço disponível. Tooltips distinguem estado desconhecido, conexão e volume; indisponibilidade não é mostrada como volume zero ou áudio silenciado. Na produção, a rede é observada pelo NetworkManager no barramento do sistema; o áudio informa indisponibilidade antes do login, sem acessar o PipeWire de outro usuário. Na produção, a sessão vem do catálogo administrativo e o menu de energia executa ações reais. No preview, a sessão mostra o ambiente atual e as ações de energia ficam desativadas. Popovers têm grafite, contorno fino e 18 unidades de inset, com fade de 240 ms OutCubic e deslocamento vinculado de 10 px. Os menus aceitam setas, Home/End e Enter/Espaço; foco tem contorno lilás e superfície `menu-active`. Escape devolve o foco ao botão de origem; Tab fecha e avança. Não há cartões de widgets independentes.

### Clock / authentication exchange

A tensão do hero começa no wake. O controlador espera 160 ms e anima `authReveal` por 840 ms OutCubic. O relógio chega a opacidade zero em reveal 0.32; identidade inicia em 0.36, campo em 0.50 e hint em 0.68. O relógio sobe até 18 unidades e reduz escala até 0.975. Identidade, campo e hint têm deslocamentos pequenos, vinculados à mesma revelação. O foco é imediato, independentemente da visibilidade.

### Cosmic state response

- **Idle:** tempo orbital lento, breathing e refresh de shader a cada 120 ms.
- **Wake:** tensão sobe por 190 ms e se dissipa em 820 ms; hero lidera o texto.
- **Auth:** refresh a cada 65 ms; digitação decai em 280 ms OutCubic e desloca minimamente a geometria.
- **Authenticating:** tensão anima em 440 ms InOutCubic, reduz velocidade do tempo orbital em até 82% e modula o alinhamento dos estratos.
- **Failure:** deformação curta de plano; 90 ms de entrada, 360 ms de pausa e 200 ms de saída. Feedback lilás localizado.
- **Success:** 1480 ms InOutCubic; os anéis contraem, a esfera cresce e a luz se apaga. UI some no primeiro terço de progressão. O shader para ao atingir preto.
- **Return to idle:** reveal e sucesso retornam em 460 ms InOutCubic; tensão em 360 ms OutSine.

Estados de transição usam timer de shader de 33 ms. Animações QML de propriedades também podem invalidar frames fora desse timer; esses valores não são um teto global de FPS. A camada extra de captura só existe com `NOCTURNE_CAPTURE_DIR`.

## Do's and Don'ts

### Do:

- Do manter a coluna editorial alinhada à identidade da máquina no rodapé.
- Do usar o foco lilás e o alvo circular dos controles existentes.
- Do revelar identidade, senha e hint na sequência do controlador, preservando o foco imediato.
- Do verificar as mudanças em capturas reais do QML em cada proporção suportada.

### Don't:

- Don't introduzir cyan, azul brilhante, amarelo ou RGB na identidade.
- Don't transformar roxo em preenchimento de tela, brilho por tecla ou flash de falha.
- Don't promover texto de debug ou monospace a linguagem da interface normal.
- Don't copiar o símbolo ou os assets de terceiros; manter a família vetorial própria.

As amostras HTML/CSS do sidecar são ilustrações isoladas para o painel da ferramenta, traduzidas do QML. Elas não são código de produção nem implementam o shader ou a máquina de estados. Ramps de cor são amostras sintéticas para inspeção, não uma paleta runtime adicional.
