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
│   ├── utils/                formatadores de moeda, data e consumo
│   └── widgets/              componentes do design system
├── data/
│   ├── models/               Unidade, Leitura, Fatura, Previa, Imovel,
│   │                         Usuario, Cobranca, Consumo, Competencia,
│   │                         Pagamento, Inquilino, Contrato
│   ├── datasources/          ApiClient
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

O **pagamento** abre em folha, não em tela cheia: três campos não pagam uma
navegação, e quem registra um recebimento está olhando a lista e volta para
ela. O valor vem preenchido com o total mas fica editável, porque a API
aceita pagamento parcial e só marca a cobrança como paga quando a soma dos
lançamentos cobre o total — quem decide o status é ela, e a folha avisa, ao
digitar menos, que a cobrança vai continuar aberta pela diferença.

O **cadastro** são duas telas, e separadas de propósito: a unidade nasce
vaga, pelo botão do painel, e o contrato entra depois, pelo card dela. É o
que permite cadastrar a kitnet enquanto ela está sendo construída, antes de
haver inquilino. No contrato, a pessoa pode ser alguém já cadastrado ou um
nome novo — nesse caso são duas chamadas, a pessoa primeiro, porque o
contrato precisa do id dela.

## Design system

Componentes em `core/widgets/`. Nenhum deles conhece ViewModel ou
Repository: recebem dado por parâmetro e devolvem callback.

| Componente | Variações |
| --- | --- |
| `AppButton` | `primary`, `secondary`, `danger` |
| `StatusBadge` | `aberta`, `paga`, `atrasada`, `vaga`, `doStatus` |
| `AppCard` | normal, destaque, clicável |
| `ValueRow` | `normal`, `total` |
| `MeterInput` | com leitura anterior e validação |
| `SectionHeader` | endereço do ponto com subtotal |
| `EmptyState` | lista vazia e erro de carga |

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

52 testes, e nenhum deles precisa da API no ar. O dublê não é o
repository: é o `http.Client` de dentro do `ApiClient`, trocado por um
`MockClient` em `test/support/api_falsa.dart`. Assim o teste passa pela
conversão de JSON, pela query string e pelo tratamento de erro de verdade,
que é onde moram os enganos — trocar o repository por um falso testaria o
ViewModel contra uma camada que não existe em produção.

| Arquivo | O que cobre |
| --- | --- |
| `competencia_store_test.dart` | a escolha do mês, os rótulos do seletor |
| `painel_viewmodel_test.dart` | agrupamento, totais, o mês indo na query |
| `pagamento_viewmodel_test.dart` | parcial, quitação, 409 |
| `cadastro_viewmodel_test.dart` | nome repetido, as duas chamadas do contrato |
| `painel_page_test.dart` | a tela: seletor abre, card leva à ação certa |

O `painel_page_test.dart` é o que cobre a fiação que o teste de ViewModel
não alcança — que tocar no card vago abre o contrato e no card com cobrança
abre o pagamento, e que o painel recarrega depois.

## O que falta

Cadastro de **ponto** (imóvel) — hoje só dá para adicionar unidade a um
ponto que já existe, e a API também não tem `POST /imoveis`. Encerramento
de contrato, que a API representa com `data_fim` e `ativo` mas não expõe em
rota nenhuma. Histórico de pagamentos de uma cobrança: a API guarda cada
lançamento, e o app só mostra o status que sai deles.
