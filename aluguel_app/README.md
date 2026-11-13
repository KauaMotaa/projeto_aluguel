# aluguel_app

App Flutter do projeto de Mobile II. Arquitetura MVVM.

Para subir tudo pela primeira vez, veja o `COMECE_AQUI.md` na pasta acima.

## Camadas

Cada camada conhece apenas a de baixo. A View não sabe que existe HTTP, e o
Model não sabe que existe tela.

```
View          widgets e telas; lê o estado e dispara comandos
  ↕
ViewModel     estado da tela; chama o Repository e notifica a View
  ↕
Repository    única porta de entrada de dados; converte JSON em Model
  ↕
DataSource    chamadas HTTP contra a API; devolve JSON cru
  ↕
Model         classes puras com fromJson
```

## Pastas

```
lib/
├── main.dart                 injeção de dependência com provider
├── core/
│   ├── config/               endereço da API
│   ├── state/                CompetenciaStore: o mês que o app olha
│   ├── theme/                tokens de cor, tipografia, espaçamento
│   ├── utils/                formatadores, e o texto da cobrança
│   └── widgets/              componentes do design system
├── data/
│   ├── models/               Unidade, Leitura, Fatura, Previa, Imovel,
│   │                         Usuario, Cobranca, Consumo, Competencia,
│   │                         Pagamento, Inquilino, Contrato
│   ├── datasources/          ApiClient, LeiturasLocais (cache offline)
│   └── repositories/         auth, imovel, leitura, fatura, fechamento,
│                             inquilino, cobranca, cadastro, competencia
└── features/
    ├── auth/                 view/ + viewmodel/
    ├── unidades/             view/ + viewmodel/
    ├── leituras/             view/ + viewmodel/
    ├── faturas/              view/ + viewmodel/
    ├── fechamento/           view/ + viewmodel/
    ├── cobrancas/            view/ + viewmodel/
    ├── cadastro/             view/ + viewmodel/
    └── inquilino/            view/ + viewmodel/
```

## Os dois perfis

O login decide a tela: proprietário cai no `PainelPage`, inquilino no
`InquilinoPage`. A decisão está em `LoginPage._entrar`, olhando
`Usuario.ehProprietario`.

Isso não é cosmético. As rotas do proprietário respondem **403** para token
de inquilino, então mandar os dois para a mesma tela dava erro de permissão
na cara do usuário. O inquilino tem duas rotas próprias
(`/minhas-cobrancas` e `/meu-consumo`), e nenhuma delas leva id: a API
resolve de quem são os dados pelo token.

## O mês mora num lugar só

A competência é o único filtro do app do proprietário: painel, leituras,
fatura e prévia falam todos do mesmo mês. Ela mora no
`CompetenciaStore`, em `core/state/`, que é um `ChangeNotifier` global —
nem repository nem ViewModel de tela.

A lista de meses vem da API, de `GET /competencias`, e não de um cálculo de
calendário. Quem sabe onde os lançamentos começam é o servidor; um
intervalo inventado no cliente ofereceria meses vazios. O painel carrega
essa lista antes dos dados e o store seleciona o mês mais recente.

Quem lê o valor, lê de lá:

| Quem | Como recebe |
| --- | --- |
| `PainelViewModel` | o store injetado, porque o seletor vive no painel |
| `LeiturasViewModel`, `FaturasViewModel`, `PreviaViewModel` | uma `String` no construtor |

As três telas recebem o mês pronto porque trabalham num mês fixo enquanto
estão abertas — não há como trocar de dentro delas, e uma `String` deixa o
ViewModel testável sem o store. Trocar o mês é `selecionar` no store
seguido de recarregar o painel, e isso acontece em um lugar só: a
`CompetenciaSheet`, que é a única que escreve nesse valor.

O `CompetenciaSheet` fica em `features/unidades/view/`, e não em
`core/widgets/`, justamente porque lê estado: os componentes do design
system recebem tudo por parâmetro.

## O painel é a porta das ações

O card da unidade leva a uma coisa diferente conforme o estado dela, e a
nenhuma quando não há o que fazer:

| Estado da unidade | Toque leva a |
| --- | --- |
| vaga | contrato de aluguel |
| ocupada, cobrança aberta ou atrasada | registro do pagamento |
| ocupada, mês não fechado ou cobrança paga | nada, o card fica parado |

É por isso que `_CardUnidade` recebe um `onToque` que pode ser nulo, e não
um booleano: quem decide qual das duas ações cabe é o `PainelViewModel`,
que tem a cobrança na mão. Um card clicável que não faz nada é pior que um
parado.

A **cobrança** abre em folha, não em tela cheia: quem mexe nela está
olhando a lista e volta para ela. A folha tem duas ações.

**Compartilhar** manda a quebra para o inquilino pelo menu do sistema —
WhatsApp, na prática. Sem isso o cálculo só existe para quem instalou este
app, e inquilino de kitnet não instala. O texto termina explicando que água
e energia já incluem a parte da área comum: é a linha que evita a discussão
de todo mês, porque sem ela o inquilino soma a própria leitura, acha menos
do que está cobrado, e a conversa começa errada. Ele vai acentuado, ao
contrário do resto da interface — "Agua" na tela do dono é um deslize de
estilo, "Agua" numa mensagem cobrando alguém é desleixo.

**Registrar o pagamento** vem com o valor preenchido com o total mas
editável, porque a API aceita pagamento parcial e só marca a cobrança como
paga quando a soma dos lançamentos cobre o total — quem decide o status é
ela, e a folha avisa, ao digitar menos, que a cobrança vai continuar aberta
pela diferença.

Cobrança já paga abre só para compartilhar: a rota de pagamento devolve 409
nesse caso, e um botão que só serve para dar erro é pior que nenhum.

O **cadastro** são duas telas, e separadas de propósito: a unidade nasce
vaga, pelo botão do painel, e o contrato entra depois, pelo card dela. É o
que permite cadastrar a kitnet enquanto ela está sendo construída, antes de
haver inquilino. No contrato, a pessoa pode ser alguém já cadastrado ou um
nome novo — nesse caso são duas chamadas, a pessoa primeiro, porque o
contrato precisa do id dela.

## As leituras funcionam sem sinal

Ler submedidor é descer na garagem, no corredor dos fundos, no quadro de
luz. Se a tela morrer sem rede, o dono anota no papel e digita em casa — e
o app vira uma planilha mais bonita.

O `LeiturasLocais`, em `data/datasources/`, guarda duas coisas por ponto e
competência, em `SharedPreferences`:

| O quê | Para quê |
| --- | --- |
| o **espelho** da última resposta da API | abrir offline com as unidades, as leituras anteriores e as médias |
| as **pendências** | valores digitados que a API ainda não aceitou |

Quem escolhe entre API e cache é o **repository**, não a ViewModel: do
mesmo jeito que ela não sabe que existe HTTP, segue sem saber que existe
cache. Ela recebe um `LeiturasDoMes`, que diz o que veio e de onde.

A distinção que sustenta tudo é `ApiException.semRede` — status nulo quer
dizer que a requisição nem chegou a ter resposta:

| Situação | O que acontece |
| --- | --- |
| rede falhou | vira fila no aparelho; repetir pode dar certo |
| 422, 409, 401 | erro na tela; repetir daria o mesmo, e a fila só adiaria |

Salvar sem sinal devolve **sucesso**, não erro: o valor está a salvo, só
não chegou. Sair da tela ali não perde nada, e é isso que precisa ficar
claro para quem está na garagem.

## O consumo fora do padrão

A regra que já existia — a leitura não pode ser menor que a anterior — não
pega o erro mais comum, que é a tecla a mais. 365 e 3650 são os dois
maiores que a anterior, e só o histórico distingue os dois.

A API manda `media_consumo` e `meses_historico` em cada linha de
`/leituras`; o ViewModel compara e avisa acima de **3× a média** ou abaixo
de **um terço** dela. O limite é folgado de propósito: variação de 50% é
rotina num aluguel, e falso alarme toda vez ensina quem usa a ignorar o
aviso. Com menos de dois meses de histórico não avisa nada — um mês só não
é média.

É **aviso, não erro**: âmbar em vez de vermelho, não trava o botão, e o
rodapé diz "dá para salvar assim mesmo". Um mês de consumo alto acontece, e
o app não tem como saber qual é qual.

## O lado do inquilino

Era a metade fraca: duas telas só de leitura, mostrando **quanto** sem
dizer **por quê**, e sem nada que ele pudesse responder. Três coisas
mudaram isso.

**A conta se explica.** Cada parcela mostra de onde saiu — "7,5 m³ seus e
0,3 m³ de área comum, a R$ 16,00/m³". A quebra vem guardada na cobrança,
não recalculada na hora: a conta é daquela competência, e corrigir uma
leitura em março não pode mudar o que foi cobrado em janeiro. Cobrança
antiga, sem a quebra guardada, mostra só o total — a tela não inventa de
onde ele veio.

**O histórico virou gráfico.** A tabela respondia "quanto gastei em
outubro"; a barra responde "estou gastando mais que antes", que é a
pergunta de quem olha a conta. Ao lado do título vai a comparação com o
mês anterior por extenso. Mês sem leitura é um tracinho no chão, não uma
barra zerada — pelo mesmo motivo que a tabela mostrava travessão.

**Ele avisa que pagou**, e isso é o que mais exigiu decisão de projeto.

## O aviso de pagamento não quita nada

O inquilino informa valor, data e forma. A cobrança **continua em
aberto**. Quem sabe se o dinheiro entrou é o proprietário, e continua
sendo o lançamento dele que vale.

Deixar o inquilino mudar o status sozinho seria pior do que não ter o
recurso: a cobrança apareceria paga para os dois sem ninguém ter
conferido nada. E um botão que não leva a lugar nenhum também seria —
ele apertaria achando que comunicou, e do outro lado ninguém veria.

Então o aviso é um recado anexado à cobrança, e cada lado sabe o que
esperar:

| Lado | O que vê |
| --- | --- |
| inquilino | a folha diz, antes de enviar, que só fica pago quando o outro confirmar; depois o card mostra o que foi informado e que está aguardando |
| proprietário | o card ganha destaque, o cabeçalho conta quantos esperam conferência, e a folha de pagamento abre **preenchida** com o que o inquilino informou |

Preencher é o ponto prático: conferir um número já na tela é mais rápido,
e menos sujeito a engano, do que redigitar o que o outro lado já disse.
Lançado o pagamento, o aviso some — cumpriu o papel, e manter a etiqueta
acesa para sempre seria ruído.

Avisar de novo corrige o aviso anterior, que é o caso comum depois do
primeiro: errou o valor e quer arrumar.

## Design system

Componentes em `core/widgets/`. Nenhum deles conhece ViewModel ou
Repository: recebem dado por parâmetro e devolvem callback.

| Componente | Variações |
| --- | --- |
| `AppButton` | `primary`, `secondary`, `danger` |
| `StatusBadge` | `aberta`, `paga`, `atrasada`, `vaga`, `doStatus` |
| `AppCard` | normal, destaque, clicável |
| `ValueRow` | `normal`, `total`, `comOrigem` |
| `MeterInput` | com leitura anterior, validação e aviso |
| `FormaPagamento` | os jeitos de pagar que a API aceita |
| `BarrasConsumo` | consumo mês a mês |
| `SectionHeader` | endereço do ponto com subtotal |
| `EmptyState` | lista vazia e erro de carga |

`ValueRow.comOrigem` e `FormaPagamento` nasceram de necessidades das duas
pontas: a primeira porque "R$ 125,34" não diz nada a quem vai pagar, e a
segunda porque dono e inquilino perguntam a mesma coisa sobre a forma de
pagamento. Como todo componente daqui, nenhum dos dois conhece ViewModel:
recebem valor e devolvem callback.

As variações são **construtores nomeados** (padrão Factory), não um
parâmetro `tipo` com `switch` dentro do `build`. A chamada fica legível e a
variante vira parte da assinatura.

## A fatura entra pela prévia

A tela de fatura (`features/faturas/`) não tem botão no painel: ela se abre
pela prévia, que é onde o problema aparece. A prévia devolve
`fatura_faltando` ou `consumo_medido_acima_da_fatura` e o alerta ganha o
atalho *Lançar a fatura agora*; quando a fatura já está lançada, o cartão
dela tem *Corrigir*. Na volta a prévia recarrega, porque o rateio inteiro
muda com a fatura.

Duas validações ficam no cliente, e as duas por motivos diferentes:

| Regra | Onde a API pega |
| --- | --- |
| valor e consumo maiores que zero | 422 na hora, pelo Pydantic |
| consumo do relógio ≥ soma dos submedidores | só na prévia, como alerta |

A segunda é a que vale explicar: a API aceita o lançamento e só reclama
depois, na prévia, porque é lá que ela sabe o que foi medido. Barrar no
campo evita o beco sem saída de lançar, ir fechar e descobrir que não dá.

## Formatação mora no ViewModel

A View recebe `String` pronta, nunca `int` de centavos. `PainelViewModel`
expõe `totalFormatado`, não `total`. É o que mantém a View burra, que é o
ponto do padrão.

## Onde mexer primeiro

- **Trocar o endereço da API**: `core/config/api_config.dart`
- **Mudar a paleta**: `core/theme/app_colors.dart`
- **Mexer no mês**: `core/state/competencia_store.dart` — é o único lugar
- **Adicionar uma tela**: nova pasta em `features/`, com `view/` e
  `viewmodel/`, e registre o ViewModel em `main.dart` se ele for global
  (os de tela ficam num `ChangeNotifierProvider` local, como em
  `LeiturasPage`)

## Testes

```bash
flutter test
```

123 testes, e nenhum deles precisa da API no ar. O dublê não é o
repository: é o `http.Client` de dentro do `ApiClient`, trocado por um
`MockClient` em `test/support/api_falsa.dart`. Assim o teste passa pela
conversão de JSON, pela query string e pelo tratamento de erro de verdade,
que é onde moram os enganos — trocar o repository por um falso testaria o
ViewModel contra uma camada que não existe em produção.

Esse mesmo dublê sabe ficar **sem rede**: a rota com valor `SemRede()`
lança em vez de responder, que é como o celular sem sinal chega no
`ApiClient`. É o que permite testar a fila offline inteira sem tocar na
rede de verdade.

| Arquivo | O que cobre |
| --- | --- |
| `competencia_store_test.dart` | a escolha do mês, os rótulos do seletor |
| `painel_viewmodel_test.dart` | agrupamento, totais, o mês indo na query |
| `cobranca_viewmodel_test.dart` | parcial, quitação, 409, o texto compartilhado |
| `leituras_viewmodel_test.dart` | o aviso de consumo, a fila offline |
| `cadastro_viewmodel_test.dart` | nome repetido, as duas chamadas do contrato |
| `inquilino_viewmodel_test.dart` | a origem da conta, a tendência de consumo |
| `aviso_pagamento_viewmodel_test.dart` | o aviso que não quita nada |
| `painel_page_test.dart` | a tela do dono: seletor, card, folha |
| `inquilino_page_test.dart` | a tela do inquilino: explicação, gráfico, aviso |

O `painel_page_test.dart` é o que cobre a fiação que o teste de ViewModel
não alcança — que tocar no card vago abre o contrato e no card com cobrança
abre a folha dela, e que o painel recarrega depois.

A API tem os seus, à parte: `cd ../api_mock && python -m pytest -q`.

## O que falta

Cadastro de **ponto** (imóvel) — hoje só dá para adicionar unidade a um
ponto que já existe, e a API também não tem `POST /imoveis`. Encerramento
de contrato, que a API representa com `data_fim` e `ativo` mas não expõe em
rota nenhuma. Histórico de pagamentos de uma cobrança: a API guarda cada
lançamento, e o app só mostra o status que sai deles.

**Notificação** de vencimento, que seria o próximo passo natural do lado
do inquilino, esbarra numa decisão do projeto: o `flutter_local_notifications`
exige entradas no `AndroidManifest.xml`, que mora na pasta `android/` —
gerada na máquina de cada um e fora do repositório de propósito. Entraria
em conflito com o "`flutter create .` e pronto". O `share_plus` passou
justamente porque não precisa de manifesto.

A fila offline cobre só as **leituras**, que é onde o problema existe de
verdade. Fatura e fechamento continuam exigindo rede — e tudo bem: os dois
se fazem sentado, com a conta da concessionária na mão.
