"""Banco em memoria.

Nao ha persistencia: reiniciar o servidor volta tudo ao estado inicial.
E de proposito, o objetivo aqui e servir de mock para o app Flutter.

O cenario reproduz os mockups: dois pontos, quatro unidades no primeiro
(uma delas vaga) e duas no segundo.
"""

from datetime import date
from itertools import count

import rateio

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


# Cobrancas de setembro e outubro, do imovel 1, para o painel do inquilino
# nao abrir vazio e para os status terem variacao.
#
# Preenchida no fim do arquivo, e nao aqui: os valores saem do proprio
# rateio, e o calculo usa as consultas que estao definidas mais abaixo.
# Antes eram numeros escritos a mao, e um centavo acabou na unidade
# errada em setembro — foi o primeiro teste do rateio que pegou. Calcular
# faz o historico de demonstracao ser, por construcao, o que a conta
# produz.
COBRANCAS: list[dict] = []

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


def _consumos_medidos(imovel_id: int, tipo: str,
                      competencia: str) -> dict[int, float]:
    medidos = {}
    for registro in unidades_do_imovel(imovel_id):
        if not contrato_ativo(registro["id"]):
            continue
        lida = leitura(registro["id"], tipo, competencia)
        if lida:
            medidos[registro["id"]] = lida["valor_atual"] - lida["valor_anterior"]
    return medidos


# Tudo pago, menos a Kitnet 02 em outubro: o painel precisa de variacao, e
# o inquilino precisa ver uma cobranca em atraso em algum lugar.
_ATRASOS = {("2026-10", 2)}


def _cobrancas_do_cenario() -> list[dict]:
    """O historico de demonstracao, calculado pelo rateio de verdade."""
    geradas = []
    for competencia in ("2026-09", "2026-10"):
        ano, mes = competencia.split("-")
        parcelas = {
            tipo: rateio.calcular(
                fatura(1, tipo, competencia)["valor_total"],
                fatura(1, tipo, competencia)["consumo_total"],
                _consumos_medidos(1, tipo, competencia),
            )
            for tipo in ("agua", "energia")
        }

        for unidade_do_mes in unidades_do_imovel(1):
            contrato = contrato_ativo(unidade_do_mes["id"])
            if not contrato:
                continue

            agua = parcelas["agua"]["parcelas"][unidade_do_mes["id"]]
            energia = parcelas["energia"]["parcelas"][unidade_do_mes["id"]]
            aluguel = contrato["valor_aluguel"]
            atrasada = (competencia, unidade_do_mes["id"]) in _ATRASOS

            geradas.append({
                "id": proximo_id("cobranca"),
                "contrato_id": contrato["id"],
                "unidade_id": unidade_do_mes["id"],
                "identificacao": unidade_do_mes["identificacao"],
                "inquilino": nome_do_inquilino(contrato),
                "competencia": competencia,
                "valor_aluguel": aluguel,
                "valor_agua": agua["valor"],
                "valor_energia": energia["valor"],
                "valor_total": aluguel + agua["valor"] + energia["valor"],
                "status": "atrasada" if atrasada else "paga",
                "vencimento": "%s-%s-%02d" % (ano, mes,
                                              contrato["dia_vencimento"]),
                "detalhe_agua": {
                    "consumo": agua["consumo"],
                    "rateio_comum": agua["rateio_comum"],
                    "valor_unitario": parcelas["agua"]["resumo"]["valor_unitario"],
                },
                "detalhe_energia": {
                    "consumo": energia["consumo"],
                    "rateio_comum": energia["rateio_comum"],
                    "valor_unitario": parcelas["energia"]["resumo"]["valor_unitario"],
                },
            })
    return geradas


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


# As cobrancas de demonstracao so podem ser montadas aqui, depois das
# consultas acima.
COBRANCAS.extend(_cobrancas_do_cenario())
