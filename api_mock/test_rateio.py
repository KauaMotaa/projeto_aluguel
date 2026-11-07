"""Testes do rateio.

Rodar de dentro de `api_mock/`:

    .venv/Scripts/python -m pytest -q

O rateio e o coracao do projeto e e funcao pura: nao toca em HTTP, em
banco nem em estado. Isso o torna o lugar mais barato de testar e o mais
caro de errar — um centavo fora aqui aparece na conta de alguem.
"""

import random

import db
import rateio


# --- a propriedade que importa -------------------------------------------

def test_a_soma_das_parcelas_fecha_exatamente_com_a_fatura():
    """E a razao de existir do metodo do maior resto.

    Arredondar cada parcela isoladamente deixaria a soma um ou dois
    centavos fora da fatura, e a diferenca sobraria para o proprietario.
    """
    resultado = rateio.calcular(69500, 560.0, {1: 165.0, 2: 150.0, 4: 170.0})
    parcelas = [p["valor"] for p in resultado["parcelas"].values()]

    assert sum(parcelas) == 69500


def test_a_soma_fecha_para_qualquer_entrada():
    """A mesma propriedade, agora contra entrada sorteada.

    Semente fixa para o teste ser reproduzivel: um caso que quebrar tem de
    quebrar de novo amanha.
    """
    sorteio = random.Random(20261107)

    for _ in range(500):
        unidades = sorteio.randint(1, 8)
        consumos = {
            uid: round(sorteio.uniform(0.0, 300.0), 2)
            for uid in range(1, unidades + 1)
        }
        medido = sum(consumos.values())
        # O relogio geral marca pelo menos o que os submedidores somam, e
        # ate 30% a mais: e a faixa que o consumo comum ocupa na pratica.
        consumo_total = round(medido * sorteio.uniform(1.0, 1.3), 2) or 1.0
        valor_total = sorteio.randint(1, 500_000)

        resultado = rateio.calcular(valor_total, consumo_total, consumos)
        parcelas = [p["valor"] for p in resultado["parcelas"].values()]

        assert sum(parcelas) == valor_total, (
            f"{valor_total} centavos entre {unidades} unidades nao fechou"
        )


def test_nenhuma_parcela_fica_mais_de_um_centavo_do_valor_exato():
    """O maior resto nao pode virar desculpa para distribuir torto.

    Cada parcela e o piso do valor exato, mais no maximo um centavo.
    """
    consumos = {1: 165.0, 2: 150.0, 4: 170.0}
    resultado = rateio.calcular(69500, 560.0, consumos)
    resumo = resultado["resumo"]

    for uid, parcela in resultado["parcelas"].items():
        exato = (consumos[uid] + resumo["rateio_comum_por_unidade"]) \
            * resumo["valor_unitario"]
        assert abs(parcela["valor"] - exato) < 1.5


# --- a conta -------------------------------------------------------------

def test_consumo_comum_e_o_que_o_relogio_geral_marcou_a_mais():
    resultado = rateio.calcular(69500, 560.0, {1: 165.0, 2: 150.0, 4: 170.0})
    resumo = resultado["resumo"]

    assert resumo["consumo_medido"] == 485.0
    assert resumo["consumo_comum"] == 75.0
    assert resumo["rateio_comum_por_unidade"] == 25.0


def test_o_comum_e_dividido_em_partes_iguais():
    """A decisao do projeto: area comum nao e proporcional ao consumo.

    Quem consome pouco na kitnet nao usa menos o corredor.
    """
    resultado = rateio.calcular(10000, 100.0, {1: 10.0, 2: 50.0, 3: 20.0})

    rateios = {p["rateio_comum"] for p in resultado["parcelas"].values()}
    assert rateios == {round(20.0 / 3, 3)}


def test_valor_unitario_e_a_fatura_dividida_pelo_relogio_geral():
    resultado = rateio.calcular(36800, 23.0, {1: 10.0, 2: 12.0})

    assert resultado["resumo"]["valor_unitario"] == 1600.0


def test_quem_consome_mais_paga_mais():
    resultado = rateio.calcular(100000, 100.0, {1: 10.0, 2: 30.0, 3: 50.0})
    parcelas = resultado["parcelas"]

    assert parcelas[1]["valor"] < parcelas[2]["valor"] < parcelas[3]["valor"]


def test_unidade_sem_consumo_ainda_paga_a_area_comum():
    """Consumo zero nao e conta zero: o corredor continua aceso."""
    resultado = rateio.calcular(10000, 50.0, {1: 0.0, 2: 40.0})

    assert resultado["parcelas"][1]["consumo"] == 0.0
    assert resultado["parcelas"][1]["valor"] > 0


def test_consumo_identico_paga_o_mesmo():
    resultado = rateio.calcular(30000, 40.0, {1: 10.0, 2: 10.0, 3: 10.0})

    assert [p["valor"] for p in resultado["parcelas"].values()] == \
        [10000, 10000, 10000]


def test_uma_unidade_so_recebe_a_fatura_inteira():
    """Sem vizinho nao ha o que ratear: a area comum e dela tambem."""
    resultado = rateio.calcular(45000, 30.0, {7: 22.0})

    assert resultado["parcelas"][7]["valor"] == 45000
    assert resultado["resumo"]["consumo_comum"] == 8.0


# --- o que a previa transforma em alerta ---------------------------------

def test_consumo_comum_negativo_sai_negativo_em_vez_de_zerado():
    """Submedidor somando mais que o relogio geral indica leitura errada.

    O rateio nao corrige nem esconde: devolve o numero negativo, e quem
    transforma isso em `consumo_medido_acima_da_fatura` e a previa. Zerar
    aqui faria a previa fechar um mes com leitura furada.
    """
    resultado = rateio.calcular(10000, 50.0, {1: 30.0, 2: 30.0})

    assert resultado["resumo"]["consumo_comum"] == -10.0
    assert sum(p["valor"] for p in resultado["parcelas"].values()) == 10000


def test_sem_unidade_ocupada_nao_ha_o_que_ratear():
    assert rateio.calcular(10000, 50.0, {}) == {"resumo": None, "parcelas": {}}


def test_relogio_geral_zerado_nao_divide_por_zero():
    assert rateio.calcular(10000, 0.0, {1: 5.0}) == \
        {"resumo": None, "parcelas": {}}


# --- o cenario que o mock carrega ----------------------------------------

def _consumos(imovel_id: int, tipo: str, competencia: str) -> dict[int, float]:
    medidos = {}
    for unidade in db.unidades_do_imovel(imovel_id):
        if not db.contrato_ativo(unidade["id"]):
            continue
        registro = db.leitura(unidade["id"], tipo, competencia)
        if registro:
            medidos[unidade["id"]] = (registro["valor_atual"]
                                      - registro["valor_anterior"])
    return medidos


def test_as_cobrancas_do_cenario_sao_as_que_o_rateio_produz():
    """Guarda a coerencia dos dados de demonstracao.

    O historico de setembro e outubro e escrito a mao em `db.py`, e o
    README promete que ele sai desta conta. Sem este teste a promessa
    envelhece calada: o inquilino abre o historico e ve um centavo que o
    rateio nao explica.
    """
    for cobranca in db.COBRANCAS:
        imovel_id = db.unidade(cobranca["unidade_id"])["imovel_id"]
        competencia = cobranca["competencia"]

        for tipo, campo in (("agua", "valor_agua"), ("energia", "valor_energia")):
            fatura = db.fatura(imovel_id, tipo, competencia)
            assert fatura, f"{competencia}: falta a fatura de {tipo}"

            resultado = rateio.calcular(
                fatura["valor_total"],
                fatura["consumo_total"],
                _consumos(imovel_id, tipo, competencia),
            )
            esperado = resultado["parcelas"][cobranca["unidade_id"]]["valor"]

            assert cobranca[campo] == esperado, (
                f"{cobranca['identificacao']} em {competencia}: {tipo} "
                f"esta {cobranca[campo]} e o rateio da {esperado}"
            )


def test_o_total_da_cobranca_e_aluguel_mais_agua_mais_energia():
    for cobranca in db.COBRANCAS:
        assert cobranca["valor_total"] == (cobranca["valor_aluguel"]
                                           + cobranca["valor_agua"]
                                           + cobranca["valor_energia"])
