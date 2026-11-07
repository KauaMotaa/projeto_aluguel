"""Banco em memoria.

Nao ha persistencia: reiniciar o servidor volta tudo ao estado inicial.
E de proposito, o objetivo aqui e servir de mock para o app Flutter.

O cenario reproduz os mockups: dois pontos, quatro unidades no primeiro
(uma delas vaga) e duas no segundo.
"""

from datetime import date
from itertools import count

_ids = {nome: count(1) for nome in
        ("imovel", "unidade", "inquilino", "contrato", "leitura", "fatura",
         "cobranca", "pagamento")}


def proximo_id(entidade: str) -> int:
    return next(_ids[entidade])


COMPETENCIA_ATUAL = "2026-11"

USUARIOS = [
    {"id": 1, "nome": "Kaua Mota", "email": "kaua@exemplo.com",
     "senha": "123456", "perfil": "proprietario"},
    {"id": 2, "nome": "Maria Souza", "email": "maria@exemplo.com",
     "senha": "123456", "perfil": "inquilino", "inquilino_id": 1},
]

IMOVEIS = [
    {"id": proximo_id("imovel"), "nome": "Palmeiras",
     "endereco": "Rua das Palmeiras, 240", "proprietario_id": 1},
    {"id": proximo_id("imovel"), "nome": "104 Sul",
     "endereco": "Quadra 104 Sul, Alameda 12", "proprietario_id": 1},
]

UNIDADES = [
    {"id": proximo_id("unidade"), "imovel_id": 1, "identificacao": "Kitnet 01"},
    {"id": proximo_id("unidade"), "imovel_id": 1, "identificacao": "Kitnet 02"},
    {"id": proximo_id("unidade"), "imovel_id": 1, "identificacao": "Kitnet 03"},
    {"id": proximo_id("unidade"), "imovel_id": 1, "identificacao": "Kitnet 04"},
    {"id": proximo_id("unidade"), "imovel_id": 2, "identificacao": "Casa 1"},
    {"id": proximo_id("unidade"), "imovel_id": 2, "identificacao": "Casa 2"},
]

INQUILINOS = [
    {"id": proximo_id("inquilino"), "nome": "Maria Souza", "telefone": "63 99000-0001"},
    {"id": proximo_id("inquilino"), "nome": "Jose Andrade", "telefone": "63 99000-0002"},
    {"id": proximo_id("inquilino"), "nome": "Ana Ribeiro", "telefone": "63 99000-0003"},
    {"id": proximo_id("inquilino"), "nome": "Carlos Pinto", "telefone": "63 99000-0004"},
    {"id": proximo_id("inquilino"), "nome": "Lucia Martins", "telefone": "63 99000-0005"},
]

# Kitnet 03 nao aparece: esta vaga.
CONTRATOS = [
    {"id": proximo_id("contrato"), "unidade_id": 1, "inquilino_id": 1,
     "valor_aluguel": 65000, "dia_vencimento": 10, "data_inicio": "2025-03-01",
     "data_fim": None, "ativo": True},
    {"id": proximo_id("contrato"), "unidade_id": 2, "inquilino_id": 2,
     "valor_aluguel": 62000, "dia_vencimento": 10, "data_inicio": "2026-01-15",
     "data_fim": None, "ativo": True},
    {"id": proximo_id("contrato"), "unidade_id": 4, "inquilino_id": 3,
     "valor_aluguel": 70000, "dia_vencimento": 5, "data_inicio": "2024-08-01",
     "data_fim": None, "ativo": True},
    {"id": proximo_id("contrato"), "unidade_id": 5, "inquilino_id": 4,
     "valor_aluguel": 85000, "dia_vencimento": 10, "data_inicio": "2025-11-01",
     "data_fim": None, "ativo": True},
    {"id": proximo_id("contrato"), "unidade_id": 6, "inquilino_id": 5,
     "valor_aluguel": 91000, "dia_vencimento": 10, "data_inicio": "2026-02-01",
     "data_fim": None, "ativo": True},
]


def _leitura(unidade_id, tipo, anterior, atual, competencia=COMPETENCIA_ATUAL):
    return {"id": proximo_id("leitura"), "unidade_id": unidade_id, "tipo": tipo,
            "competencia": competencia, "valor_anterior": anterior,
            "valor_atual": atual}


LEITURAS = [
    # Setembro e outubro ja fechados. Existem para o historico de consumo do
    # inquilino ter mais de um ponto, e porque a cadeia precisa ser continua:
    # o valor_atual de um mes e o valor_anterior do mes seguinte.
    _leitura(1, "agua", 128.0, 135.5, "2026-09"),
    _leitura(1, "energia", 2850, 3015, "2026-09"),
    _leitura(2, "agua", 86.0, 92.0, "2026-09"),
    _leitura(2, "energia", 2450, 2600, "2026-09"),
    _leitura(4, "agua", 186.0, 194.5, "2026-09"),
    _leitura(4, "energia", 3580, 3750, "2026-09"),

    _leitura(1, "agua", 135.5, 142.5, "2026-10"),
    _leitura(1, "energia", 3015, 3180, "2026-10"),
    _leitura(2, "agua", 92.0, 98.0, "2026-10"),
    _leitura(2, "energia", 2600, 2745, "2026-10"),
    _leitura(4, "agua", 194.5, 203.0, "2026-10"),
    _leitura(4, "energia", 3750, 3910, "2026-10"),

    _leitura(1, "agua", 142.5, 150.0),
    _leitura(1, "energia", 3180, 3365),
    _leitura(2, "agua", 98.0, 104.0),
    _leitura(2, "energia", 2745, 2905),
    _leitura(4, "agua", 203.0, 211.0),
    _leitura(4, "energia", 3910, 4110),
]


def _fatura(imovel_id, tipo, valor_total, consumo_total,
            competencia=COMPETENCIA_ATUAL):
    return {"id": proximo_id("fatura"), "imovel_id": imovel_id,
            "competencia": competencia, "tipo": tipo,
            "valor_total": valor_total, "consumo_total": consumo_total}


# O imovel 2 ainda nao teve leituras nem faturas lancadas neste mes: serve
# para ver os alertas da previa funcionando.
FATURAS = [
    _fatura(1, "agua", 36800, 23.0, "2026-09"),
    _fatura(1, "energia", 69500, 560.0, "2026-09"),
    _fatura(1, "agua", 37600, 23.5, "2026-10"),
    _fatura(1, "energia", 68000, 545.0, "2026-10"),

    _fatura(1, "agua", 38400, 24.0),
    _fatura(1, "energia", 72150, 580.0),
]


def _cobranca(contrato_id, unidade_id, identificacao, inquilino, competencia,
              aluguel, agua, energia, status, dia_vencimento):
    ano, mes = competencia.split("-")
    return {"id": proximo_id("cobranca"), "contrato_id": contrato_id,
            "unidade_id": unidade_id, "identificacao": identificacao,
            "inquilino": inquilino, "competencia": competencia,
            "valor_aluguel": aluguel, "valor_agua": agua,
            "valor_energia": energia,
            "valor_total": aluguel + agua + energia, "status": status,
            "vencimento": "%s-%s-%02d" % (ano, mes, dia_vencimento)}


# Cobrancas de setembro e outubro, do imovel 1, para o painel do inquilino
# nao abrir vazio e para os status terem variacao. As parcelas de agua e
# energia sao as que o rateio produz para as leituras acima: a soma das
# parcelas de cada tipo fecha exatamente com a fatura da competencia.
COBRANCAS: list[dict] = [
    _cobranca(1, 1, "Kitnet 01", "Maria Souza", "2026-09", 65000, 12534, 23581, "paga", 10),
    _cobranca(2, 2, "Kitnet 02", "Jose Andrade", "2026-09", 62000, 10133, 21719, "paga", 10),
    _cobranca(3, 4, "Kitnet 04", "Ana Ribeiro", "2026-09", 70000, 14133, 24200, "paga", 5),

    _cobranca(1, 1, "Kitnet 01", "Maria Souza", "2026-10", 65000, 12267, 23706, "paga", 10),
    _cobranca(2, 2, "Kitnet 02", "Jose Andrade", "2026-10", 62000, 10667, 21211, "atrasada", 10),
    _cobranca(3, 4, "Kitnet 04", "Ana Ribeiro", "2026-10", 70000, 14666, 23083, "paga", 5),
]

PAGAMENTOS: list[dict] = []


# --- consultas de conveniencia -------------------------------------------

def unidade(unidade_id: int) -> dict | None:
    return next((u for u in UNIDADES if u["id"] == unidade_id), None)


def unidades_do_imovel(imovel_id: int) -> list[dict]:
    return [u for u in UNIDADES if u["imovel_id"] == imovel_id]


def imovel(imovel_id: int) -> dict | None:
    return next((i for i in IMOVEIS if i["id"] == imovel_id), None)


def contrato_ativo(unidade_id: int) -> dict | None:
    return next((c for c in CONTRATOS
                 if c["unidade_id"] == unidade_id and c["ativo"]), None)


def inquilino(inquilino_id: int) -> dict | None:
    return next((i for i in INQUILINOS if i["id"] == inquilino_id), None)


def nome_do_inquilino(contrato: dict) -> str:
    pessoa = inquilino(contrato["inquilino_id"])
    return pessoa["nome"] if pessoa else "?"


def leitura(unidade_id: int, tipo: str, competencia: str) -> dict | None:
    return next((l for l in LEITURAS
                 if l["unidade_id"] == unidade_id
                 and l["tipo"] == tipo
                 and l["competencia"] == competencia), None)


def ultima_leitura(unidade_id: int, tipo: str) -> dict | None:
    registros = [l for l in LEITURAS
                 if l["unidade_id"] == unidade_id and l["tipo"] == tipo]
    return max(registros, key=lambda l: l["competencia"], default=None)


def fatura(imovel_id: int, tipo: str, competencia: str) -> dict | None:
    return next((f for f in FATURAS
                 if f["imovel_id"] == imovel_id
                 and f["tipo"] == tipo
                 and f["competencia"] == competencia), None)


def cobranca(cobranca_id: int) -> dict | None:
    return next((c for c in COBRANCAS if c["id"] == cobranca_id), None)


def cobrancas_do_contrato(contrato_id: int) -> list[dict]:
    return [c for c in COBRANCAS if c["contrato_id"] == contrato_id]


def competencias_com_dados() -> list[str]:
    """Competencias que tem algum lancamento, mais o mes do calendario.

    E o que alimenta o seletor de mes do app, da mais recente para a mais
    antiga. O app nao tem como adivinhar esse intervalo: quem sabe onde os
    lancamentos comecam e o servidor.

    O mes corrente entra mesmo sem lancamento nenhum, senao nao haveria por
    onde comecar um mes novo.
    """
    vistas = {registro["competencia"] for registro in LEITURAS}
    vistas |= {registro["competencia"] for registro in FATURAS}
    vistas |= {registro["competencia"] for registro in COBRANCAS}
    vistas.add(date.today().strftime("%Y-%m"))
    return sorted(vistas, reverse=True)
