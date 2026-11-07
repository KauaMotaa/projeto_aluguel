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

O mês não está escrito no código: o app pergunta à API quais competências
têm lançamento e abre na mais recente. O mock carrega setembro, outubro e
novembro de 2026, então dá para navegar entre um mês fechado e um aberto.

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

Como **proprietário**: painel das unidades agrupadas por ponto, com seletor
de mês, lançamento das leituras dos submedidores, lançamento da fatura da
concessionária, prévia do fechamento com os alertas que o travam, e geração
das cobranças. Depois do fechamento, cada cobrança pode ser **compartilhada
com o inquilino** pelo WhatsApp e ter o pagamento registrado — inclusive
parcial, que deixa a cobrança aberta pela diferença. E o cadastro de
unidade nova e do contrato que a aluga.

Duas coisas resolvem o que mais atrapalha na prática. As **leituras
funcionam sem sinal**: ler submedidor é na garagem, no quadro de luz, e o
que for digitado ali fica guardado no aparelho até a rede voltar. E o app
**avisa quando o consumo destoa** do que aquela unidade costuma gastar, que
é como se pega a tecla a mais — 3650 no lugar de 365 passa pela regra de
"não pode ser menor que a anterior", mas não passa pela média.

Como **inquilino**: as cobranças dele, com a quebra entre aluguel, água e
energia, e o histórico de consumo mês a mês.

## Testes

```bash
cd aluguel_app && flutter test
```

```bash
cd api_mock && python -m pytest -q
```

93 testes: 78 do app e 15 do rateio. Nenhum dos do app precisa da API no
ar — o dublê é o cliente HTTP de dentro do `ApiClient`, então o teste ainda
passa pela conversão de JSON, pela query string e pelo tratamento de erro
de verdade. E esse mesmo dublê sabe ficar sem rede, que é como se testa a
fila offline.

Os do rateio afirmam, contra 500 entradas sorteadas, que a soma das
parcelas fecha exatamente com a fatura. Um deles compara o histórico do
cenário com o que a conta produz, e achou um centavo fora do lugar nos
dados de demonstração.

Detalhes de arquitetura em [`aluguel_app/README.md`](aluguel_app/README.md)
e das rotas em [`api_mock/README.md`](api_mock/README.md).
