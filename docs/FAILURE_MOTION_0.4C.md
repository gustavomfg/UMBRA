# Nocturne Umbra 0.4c — failure motion only

## Por que a falha parecia travada

No 0.4b, `Enter` iniciava `AUTHENTICATING` e limpava o campo imediatamente. A simulação esperava 920 ms antes de produzir a rejeição. `FAILURE` então subia em 90 ms, ficava 360 ms sem mudança e descia em 200 ms. A fase só voltava a `AUTH` depois desses 650 ms. Como `authenticationTensionActive` incluía `FAILURE`, o hero permanecia sob tensão máxima durante toda a espera e o pulso. O relógio orbital continuava ativo, mas avançava a 18% da velocidade normal. Só depois do retorno a `AUTH` começava a liberação de tensão de 440 ms.

O campo aceitava teclado e recebia foco na entrada de `FAILURE`, mas o feedback visual não devolvia presença ao hero nem mostrava progresso durante o hold. Havia uma espera simulada longa, uma pausa sem evolução visível e, por fim, um retorno separado.

## Timeline anterior

| Tempo desde Enter | Evento |
| ---: | --- |
| 0 ms | `AUTH → AUTHENTICATING`; campo limpo; foco sai do campo; tensão começa a subir em 360 ms (`OutCubic`). |
| 0–920 ms | Timer do adaptador de preview aguarda a falha simulada; a tensão fica máxima após os primeiros 360 ms. |
| 920 ms | Resultado negativo; `AUTHENTICATING → FAILURE`; foco e entrada são restaurados. |
| 920–1.010 ms | `failureProgress` sobe em 90 ms (`OutCubic`). |
| 1.010–1.370 ms | Hold de 360 ms com `failureProgress` parado em 1. |
| 1.370–1.570 ms | Pulso desce em 200 ms (`InOutSine`). |
| 1.570 ms | A fase retorna a `AUTH`; começa a liberação da tensão em 440 ms (`InOutCubic`). |
| 2.010 ms | Hero termina de liberar a tensão. |

## Timeline nova

| Tempo desde Enter | Evento |
| ---: | --- |
| 0 ms | `AUTH → AUTHENTICATING`; senha limpa; tensão começa a subir. |
| 0–360 ms | Latência curta do resultado simulado; a resposta de tensão confirma o submit desde o início. |
| 360 ms | Rejeição; `AUTHENTICATING → FAILURE`; foco volta ao campo, teclado volta a ser aceito e o hero começa a liberar tensão. |
| 360–500 ms | Perturbação progride em 140 ms (`OutCubic`). O texto de preparação cede lugar ao feedback de falha perto do ponto de maior presença. |
| 500–760 ms | A perturbação se desfaz em 260 ms (`InOutSine`); a mensagem de falha recua enquanto o hint de nova tentativa retorna. Não há hold. |
| 760 ms | `FAILURE → AUTH`; a tensão está praticamente liberada; o campo já estava pronto desde 360 ms. |
| 800 ms | Liberação de tensão de 440 ms termina. |

A rejeição simulada passou de 920 para 360 ms, igualando a latência de sucesso do preview. O pulso passou de 650 ms segmentados para uma curva contínua de 400 ms: subida de 140 ms e retorno de 260 ms, sem pausa. A liberação orbital começa junto da rejeição e se sobrepõe ao retorno visual. A velocidade orbital nunca é zerada: após o resultado ela cresce suavemente do fator mínimo de 18% até a velocidade base.

O prompt e a mensagem de falha fazem uma transferência de presença em limiar compartilhado, sem texto duplicado ou dois hints sobrepostos. O estado `failureResolving` só marca a direção da mesma timeline para que o texto de preparação mude quando sua opacidade chega a zero; é reiniciado em retry, Escape e conclusão da animação.

## Entrada e senha

`AuthPanel.submit()` continua limpando o campo de forma síncrona no submit, antes do timer de resultado; a senha não fica retida nem é escrita em log. Na entrada de `FAILURE`, o campo volta a ser habilitado e focado imediatamente. A fase de falha aceita digitação, Backspace e novo Enter; uma nova tentativa interrompe e limpa a timeline anterior antes de começar outra. Escape cancela a timeline e inclui a pequena perturbação orbital no retorno existente ao idle.

## Success, shader e cadence

O sucesso visual não foi redesenhado nem teve duração, easing, progress, ordem ou opacidade alterados. `authenticationTensionActive` continua verdadeiro através de `AUTHENTICATING → SUCCESS`, então essa fronteira não inicia nem reinicia um Behavior. `successTimeline` permanece em 1.480 ms `InOutCubic`; `GreeterWindow.qml`, `pulse.frag` e `pulse.frag.qsb` não mudaram. O QSB compilado manteve o hash do snapshot 0.4b: `c4868a489216f3f5b027b350541483d74352750d39592b6ddcde57f4bc695f6`.

O timer de shader continua em 16 ms. A amostra QSG do preview normal registrou mediana de 15 ms, p95 de 16 ms, p99 de 17 ms e máximo de 24 ms; o driver reportou VSync de 5,56 ms. Esses são callbacks do Qt Quick, não timestamps de apresentação do compositor. Não houve linhas `WARN` ou `ERROR` no log de runtime.

## Verificação e limitações

- 22 checks QML passaram: os 18 existentes mais quatro regressões para retry durante a recuperação, cinco falhas consecutivas, Escape durante falha e liberação sem hold.
- `qmllint -E`, build QSB, `glslangValidator -S frag` e `bash -n scripts/*.sh` passaram.
- O preview foi executado; a captura de falha mostrou uma única mensagem, com campo vazio e pronto. A captura `black` teve somente pixels RGB `(0,0,0)`.
- A inventory CUA desta sessão não expôs janela nativa. Assim, a sequência de teclado/mouse não pôde ser assistida como uso humano ao vivo; a máquina foi exercitada pelos testes Qt Quick e o preview real foi usado para as capturas e a amostra QSG.

## Backup e rollback

O snapshot hashado da Umbra 0.4b está em `backups/umbra-0.4b-before-failure-motion/` (69 arquivos). Para restaurá-lo:

```sh
./scripts/restore-umbra-0.4b.sh
```

O script valida o snapshot, restaura os arquivos do projeto e se remove depois do uso. Nenhum arquivo de display manager, PAM, boot ou serviço de login foi tocado.
