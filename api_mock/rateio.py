"""Rateio de uma fatura unica entre as unidades de um imovel.

A conta, por tipo de medidor:

    valor_unitario   = valor_total_fatura / consumo_total_fatura
    consumo_unidade  = leitura_atual - leitura_anterior
    consumo_comum    = consumo_total_fatura - soma(consumo_unidade)
    rateio_por_unid. = consumo_comum / unidades_ocupadas
    valor_unidade    = (consumo_unidade + rateio) * valor_unitario

O consumo comum e a diferenca entre o que o relogio geral marcou e a soma
dos submedidores: area comum, perda e imprecisao dos medidores baratos.
A decisao do projeto e dividi-lo em partes iguais entre as unidades
ocupadas.
"""

import math


def _distribuir_centavos(exatos: list[float], total: int) -> list[int]:
    """Arredonda preservando a soma.

    Arredondar cada valor isoladamente faz a soma fechar com um ou dois
    centavos de diferenca em relacao a fatura, e o proprietario percebe.
    Aqui cada valor cai para o inteiro de baixo e os centavos que sobram
    vao para quem tem a maior parte fracionaria (metodo do maior resto).
    """
    if not exatos:
        return []

    piso = [math.floor(v) for v in exatos]
    sobra = total - sum(piso)

    if sobra <= 0:
        return piso

    restos = sorted(range(len(exatos)),
                    key=lambda i: exatos[i] - piso[i],
                    reverse=True)
    for i in restos[:sobra]:
        piso[i] += 1
    return piso


def calcular(valor_total: int, consumo_total: float,
             consumos: dict[int, float]) -> dict:
    """Rateia uma fatura entre as unidades ocupadas.

    `consumos` mapeia unidade_id para o consumo medido no submedidor.
    Devolve o resumo da fatura e a parcela de cada unidade, em centavos.
    """
    ocupadas = len(consumos)
    if ocupadas == 0 or consumo_total <= 0:
        return {"resumo": None, "parcelas": {}}

    valor_unitario = valor_total / consumo_total
    consumo_medido = sum(consumos.values())
    consumo_comum = consumo_total - consumo_medido
    rateio = consumo_comum / ocupadas

    ids = list(consumos.keys())
    exatos = [(consumos[uid] + rateio) * valor_unitario for uid in ids]
    centavos = _distribuir_centavos(exatos, valor_total)

    parcelas = {
        uid: {
            "consumo": round(consumos[uid], 3),
            "rateio_comum": round(rateio, 3),
            "valor": valor,
        }
        for uid, valor in zip(ids, centavos)
    }

    resumo = {
        "valor_total_fatura": valor_total,
        "valor_unitario": round(valor_unitario, 4),
        "consumo_total": round(consumo_total, 3),
        "consumo_medido": round(consumo_medido, 3),
        "consumo_comum": round(consumo_comum, 3),
        "rateio_comum_por_unidade": round(rateio, 3),
    }

    return {"resumo": resumo, "parcelas": parcelas}
