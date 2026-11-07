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
│   ├── theme/                tokens de cor, tipografia, espaçamento
│   ├── utils/                formatadores de moeda, data e consumo
│   └── widgets/              componentes do design system
├── data/
│   ├── models/               Unidade, Leitura, Fatura, Previa, Imovel,
│   │                         Usuario, Cobranca, Consumo
│   ├── datasources/          ApiClient
│   └── repositories/         auth, imovel, leitura, fatura, fechamento,
│                             inquilino
└── features/
    ├── auth/                 view/ + viewmodel/
    ├── unidades/             view/ + viewmodel/
    ├── leituras/             view/ + viewmodel/
    ├── faturas/              view/ + viewmodel/
    ├── fechamento/           view/ + viewmodel/
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
- **Adicionar uma tela**: nova pasta em `features/`, com `view/` e
  `viewmodel/`, e registre o ViewModel em `main.dart` se ele for global
  (os de tela ficam num `ChangeNotifierProvider` local, como em
  `LeiturasPage`)

## O que falta

Registro de pagamento pelo app (a API já tem
`POST /cobrancas/{id}/pagamento`), cadastro de unidade e contrato, e seletor
de competência — o mês está fixo em `2026-11`, que é o que o mock carrega, e
hoje mora em quatro `static const competencia` espalhados pelos ViewModels.
Quando o seletor entrar, ele é que vira a fonte única desse valor.
