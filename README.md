# Gestão de aluguel — projeto de Mobile II

App de gestão de aluguel de kitnets, com **rateio de água e energia** entre
as unidades de um mesmo ponto. App em Flutter, arquitetura MVVM, contra uma
API mock em FastAPI.

| Pasta | O que é |
| --- | --- |
| [`aluguel_app/`](aluguel_app/) | app Flutter em MVVM |
| [`api_mock/`](api_mock/) | backend mock em FastAPI, com o cálculo do rateio |

## Como rodar

O passo a passo está em **[COMECE_AQUI.md](COMECE_AQUI.md)**. Em resumo:
suba o mock, gere as pastas de plataforma do Flutter e rode.

```bash
cd api_mock && pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000

cd ../aluguel_app && flutter create . --platforms=android --project-name aluguel_app
flutter pub get && flutter run
```

> As pastas `android/` e `ios/` **não estão no repositório**, de propósito:
> elas são geradas pelo SDK de cada máquina, com a versão de Gradle e Kotlin
> instalada ali. O `flutter create .` numa pasta que já tem `lib/` só
> preenche o que falta, não apaga código.

Para entrar: `kaua@exemplo.com` (proprietário) ou `maria@exemplo.com`
(inquilino), senha `123456` nos dois. São dados fictícios do mock.

## O problema que ele resolve

Um ponto de aluguel tem um relógio de água e um de energia na entrada, e
submedidores em cada kitnet. A conta que chega é uma só. A soma dos
submedidores nunca fecha com o relógio geral — a diferença é área comum,
perda e imprecisão de medidor barato.

O cálculo está isolado em [`api_mock/rateio.py`](api_mock/rateio.py):

```
valor_unitario  = valor_total_fatura / consumo_total_fatura
consumo_unidade = leitura_atual - leitura_anterior
consumo_comum   = consumo_total_fatura - soma(consumo_unidade)
rateio          = consumo_comum / unidades_ocupadas
valor_unidade   = (consumo_unidade + rateio) * valor_unitario
```

O arredondamento usa o **método do maior resto**, então a soma das parcelas
fecha exatamente com o valor da fatura, sem sobrar centavo.

## O que o app faz

Como **proprietário**: painel das unidades agrupadas por ponto, lançamento
das leituras dos submedidores, lançamento da fatura da concessionária,
prévia do fechamento com os alertas que o travam, e geração das cobranças.

Como **inquilino**: as cobranças dele, com a quebra entre aluguel, água e
energia, e o histórico de consumo mês a mês.

Detalhes de arquitetura em [`aluguel_app/README.md`](aluguel_app/README.md)
e das rotas em [`api_mock/README.md`](api_mock/README.md).
