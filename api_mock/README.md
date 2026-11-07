# API mock — gestão de aluguel

Mock do backend para o app Flutter da disciplina de Mobile II. Dados em
memória, sem banco: reiniciar o servidor volta tudo ao estado inicial.

## Rodar

```bash
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- Swagger: http://localhost:8000/docs
- OpenAPI (é o arquivo que entra na documentação da disciplina):
  http://localhost:8000/openapi.json

O `--host 0.0.0.0` é o que permite o celular acessar pelo IP da máquina na
mesma rede. No Flutter, mantenha essa URL base num arquivo de configuração.

## Entrar

| Perfil | Email | Senha |
| --- | --- | --- |
| Proprietário | `kaua@exemplo.com` | `123456` |
| Inquilino | `maria@exemplo.com` | `123456` |

O login devolve um token; mande-o em `Authorization: Bearer <token>`.

## Cenário carregado

Dois imóveis. O primeiro, **Rua das Palmeiras, 240**, tem quatro unidades
(Kitnet 03 vaga), leituras e faturas de novembro lançadas — fecha sem
pendência. O segundo, **Quadra 104 Sul**, está sem leituras e sem faturas,
e serve para ver os alertas da prévia funcionando.

## Rotas

| Método | Rota | Perfil |
| --- | --- | --- |
| POST | `/api/v1/auth/login` | — |
| GET | `/api/v1/competencias` | proprietário |
| GET | `/api/v1/imoveis` | proprietário |
| GET | `/api/v1/unidades?competencia=&imovel_id=` | proprietário |
| GET | `/api/v1/unidades/{id}` | proprietário |
| POST | `/api/v1/unidades` | proprietário |
| GET | `/api/v1/inquilinos` | proprietário |
| POST | `/api/v1/inquilinos` | proprietário |
| POST | `/api/v1/contratos` | proprietário |
| GET | `/api/v1/leituras?competencia=&imovel_id=` | proprietário |
| POST | `/api/v1/leituras` | proprietário |
| GET | `/api/v1/imoveis/{id}/faturas?competencia=` | proprietário |
| POST | `/api/v1/imoveis/{id}/faturas` | proprietário |
| GET | `/api/v1/imoveis/{id}/competencias/{comp}/previa` | proprietário |
| POST | `/api/v1/imoveis/{id}/competencias/{comp}/fechar` | proprietário |
| GET | `/api/v1/cobrancas?competencia=&imovel_id=` | proprietário |
| POST | `/api/v1/cobrancas/{id}/pagamento` | proprietário |
| GET | `/api/v1/minhas-cobrancas` | inquilino |
| GET | `/api/v1/meu-consumo` | inquilino |

Fatura, prévia e fechamento penduram no imóvel porque cada ponto tem a
própria fatura de concessionária e o próprio consumo comum.

`/competencias` existe para o app não ter o mês escrito no código. Devolve
os meses que já têm algum lançamento, mais o mês do calendário, do mais
recente para o mais antigo, e em cada um quantos pontos já foram fechados —
o fechamento é por ponto, então um mês pode estar fechado num imóvel e
aberto no outro. Quem sabe onde os lançamentos começam é a API; um
intervalo calculado no cliente ofereceria meses vazios.

`/inquilinos` traz, em cada pessoa, as unidades que ela ocupa hoje. A lista
de nomes sozinha não diz quem já está alojado, e é isso que evita escolher
por engano alguém que já tem contrato ativo.

## Convenções

- Dinheiro em **centavos**, inteiro. `65000` é R$ 650,00.
- Consumo em float: m³ com casa decimal, kWh inteiro.
- Competência no formato `AAAA-MM`.
- Datas em ISO 8601.

## O rateio

Está isolado em `rateio.py`. Por tipo de medidor:

```
valor_unitario  = valor_total_fatura / consumo_total_fatura
consumo_unidade = leitura_atual - leitura_anterior
consumo_comum   = consumo_total_fatura - soma(consumo_unidade)
rateio          = consumo_comum / unidades_ocupadas
valor_unidade   = (consumo_unidade + rateio) * valor_unitario
```

Dois detalhes que valem citar na defesa do trabalho:

**O consumo comum existe sempre.** A soma dos submedidores nunca fecha com
o relógio geral — sobra a área comum, a perda e a imprecisão dos medidores
baratos. Ignorar essa diferença faria o proprietário absorver silenciosamente
parte da conta.

**O arredondamento usa maior resto.** Arredondar cada parcela isoladamente
deixa a soma um ou dois centavos fora da fatura, e isso aparece. Cada valor
cai para o inteiro de baixo e os centavos restantes vão para quem tem a maior
parte fracionária, então a soma das parcelas é exatamente o valor da fatura.

## Validações da prévia

A prévia devolve `alertas` e `pode_fechar`. O fechamento recusa com 409
enquanto houver alerta. O que é checado:

- `leitura_faltando` — unidade ocupada sem leitura na competência
- `leitura_menor_que_anterior` — medidor andou para trás
- `fatura_faltando` — fatura da concessionária não lançada
- `consumo_medido_acima_da_fatura` — a soma dos submedidores passou o
  consumo da fatura, o que indica erro de leitura
- `sem_unidade_ocupada` — nada a ratear

Lançar leitura menor que a anterior também é recusado na entrada, com 422.

## Arquivos

| Arquivo | O que tem |
| --- | --- |
| `main.py` | app FastAPI e todas as rotas |
| `models.py` | schemas Pydantic de entrada e saída |
| `db.py` | dados em memória e consultas de conveniência |
| `rateio.py` | o cálculo, isolado e sem dependência de framework |
