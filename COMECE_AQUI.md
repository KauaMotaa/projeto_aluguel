# Projeto de Mobile II — app de gestão de aluguel

Duas partes, nesta pasta:

| Pasta | O que é |
| --- | --- |
| `api_mock/` | backend mock em FastAPI, com o cálculo do rateio |
| `aluguel_app/` | app Flutter em MVVM |

Suba o mock primeiro: sem ele o app abre, mas não tem o que mostrar.

---

## 1. Subir o mock

```bash
cd api_mock
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Confira em http://localhost:8000/docs. Deixe esse terminal aberto.

O `--host 0.0.0.0` é o que permite o celular e o emulador enxergarem a API.
Sem ele, só o próprio computador acessa.

Nesta máquina já existe um ambiente pronto em `api_mock/.venv` (ignorado
pelo git), e dele dá para subir direto, sem instalar nada:

```bash
cd api_mock
.venv/Scripts/python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Um aviso para quando você for instalar do zero: no Python 3.15 desta
máquina o extra `uvicorn[standard]` não compila, porque o `pyyaml` dele
precisa do compilador C da Microsoft. O `.venv` acima foi montado com
`fastapi`, `uvicorn` e `pydantic` sem extras — o `--reload` funciona
igual, só usa o vigia por data de arquivo em vez do nativo. Em Python 3.12
ou 3.13 o `requirements.txt` instala inteiro, sem esse contorno.

## 2. Gerar as pastas de plataforma do Flutter

O projeto vem com `lib/` e `pubspec.yaml` prontos, mas **sem** as pastas
`android/` e `ios/`. Isso é de propósito: essas pastas são geradas pelo SDK
da sua máquina, com a versão de Gradle e Kotlin que você tem instalada. Se
eu mandasse elas prontas daqui, quebrariam no seu ambiente.

Gerar leva um comando:

```bash
cd aluguel_app
flutter create . --platforms=android --project-name aluguel_app
flutter pub get
```

O `flutter create .` numa pasta que já tem `lib/` **não apaga o seu
código** — ele só preenche o que está faltando.

## 3. Rodar

**No emulador Android**, direto:

```bash
flutter run
```

Já está apontado para `http://10.0.2.2:8000/api/v1`, que é o apelido que o
emulador usa para falar com o computador que o hospeda. Dentro do emulador,
`localhost` é o próprio emulador — por isso não funciona.

**No celular físico**, pegue o IP do seu computador na rede e passe na hora
de rodar. Celular e computador precisam estar no mesmo Wi-Fi:

```bash
# descubra o IP: ip addr (Linux) ou ipconfig (Windows)
flutter run --dart-define=API_URL=http://192.168.0.15:8000/api/v1
```

Troque `192.168.0.15` pelo seu IP de verdade.

## 4. Entrar

| Perfil | Email | Senha |
| --- | --- | --- |
| Proprietário | `kaua@exemplo.com` | `123456` |
| Inquilino | `maria@exemplo.com` | `123456` |

A tela de login já vem preenchida com o proprietário. Trocar de perfil não
pede reiniciar o app: o ícone de sair, no canto do cabeçalho, volta para o
login. O app escolhe a tela pelo perfil que o login devolve — proprietário
vai para o painel, inquilino vai para o painel dele.

---

## O que dá para fazer no app hoje

1. **Entrar** como proprietário.
2. **Painel** com as unidades agrupadas por endereço, subtotal por ponto e
   o total a receber no topo.
3. **Leituras** — lançar água e energia de cada unidade, com a leitura
   anterior ao lado e recusa de valor menor que ela.
4. **Prévia do fechamento** — ver o rateio calculado unidade por unidade,
   com os alertas que travam o fechamento. Se a fatura da concessionária
   estiver faltando, o alerta traz o atalho para lançá-la; se já estiver
   lançada, o cartão dela tem *Corrigir*.
5. **Fatura da concessionária** — o valor da conta e o consumo do relógio
   geral, um par por medidor. A tela mostra quanto os submedidores já
   somam e recusa consumo menor que isso.
6. **Confirmar** e gerar as cobranças. Volte ao painel e puxe para baixo:
   os status aparecem.
7. **Sair** e entrar como `maria@exemplo.com`: o painel do inquilino mostra
   as cobranças dela, com a quebra entre aluguel, água e energia, e o
   histórico de consumo mês a mês.

O segundo ponto (Quadra 104 Sul) começa sem leitura e sem fatura. Abra a
prévia dele para ver os dois alertas e o botão desabilitado — e, se quiser,
leve ele até o fim sem sair do app: lance as leituras das duas casas, lance
as duas faturas pelo atalho do alerta e feche o mês.

## Testes que valem fazer

Na tela de leituras, digite um valor **menor** que a leitura anterior. O
campo fica vermelho, a legenda explica, e o botão de salvar desabilita. Essa
mesma regra está repetida na API, que devolve 422 — validar nos dois lados é
de propósito: o app evita a viagem, a API garante a integridade.

Na tela de fatura, digite um consumo **menor** que a soma dos submedidores
que a legenda mostra. O campo barra. Essa é a regra que a API não pega na
entrada: ela aceita o lançamento e só acusa depois, na prévia, com
`consumo_medido_acima_da_fatura`. Barrar no campo evita lançar, ir fechar e
descobrir lá que não dá.

O último é a volta completa entre os dois perfis. Entre como proprietário,
feche novembro no primeiro ponto, saia e entre como `maria@exemplo.com`:
setembro e outubro aparecem pagos, e novembro aparece **em aberto**, com o
vencimento em 10/11 e o total somando no topo da tela. É o mesmo cálculo
do rateio chegando no inquilino.

## Se reiniciar o mock

Os dados são em memória. Reiniciar o `uvicorn` devolve tudo ao estado
inicial, inclusive desfazendo o fechamento que você tiver feito. É útil para
testar o fluxo de novo do zero.

## Problemas comuns

**"Não consegui falar com o servidor"** — o mock não está rodando, ou o
endereço está errado. Confira se o uvicorn subiu com `--host 0.0.0.0` e se
o IP em `--dart-define` é o da sua máquina.

**Celular não conecta** — o firewall do Windows costuma bloquear a porta
8000 na primeira vez. Libere quando ele perguntar, ou desative
temporariamente para testar.

**`flutter create` reclamando do nome** — o nome do pacote tem que bater com
o `name:` do `pubspec.yaml`, que é `aluguel_app`. É por isso que o comando
leva `--project-name aluguel_app`.
