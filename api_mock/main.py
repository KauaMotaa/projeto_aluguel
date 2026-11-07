"""API mock do app de gestao de aluguel.

Rodar:  uvicorn main:app --reload --host 0.0.0.0 --port 8000
Docs:   http://localhost:8000/docs
OpenAPI: http://localhost:8000/openapi.json
"""

from datetime import date
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Header, Query
from fastapi.middleware.cors import CORSMiddleware

import db
import models as m
import rateio

app = FastAPI(
    title="API de gestao de aluguel",
    description="Mock para o app Flutter. Dados em memoria, sem persistencia.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

V1 = "/api/v1"

# token -> usuario. Suficiente para um mock; nao use isso em producao.
SESSOES: dict[str, dict] = {}


def usuario_logado(authorization: str = Header(default="")) -> dict:
    token = authorization.removeprefix("Bearer ").strip()
    usuario = SESSOES.get(token)
    if not usuario:
        raise HTTPException(status_code=401, detail="Token ausente ou invalido")
    return usuario


def apenas_proprietario(usuario: dict = Depends(usuario_logado)) -> dict:
    if usuario["perfil"] != "proprietario":
        raise HTTPException(status_code=403, detail="Rota do proprietario")
    return usuario


# --- autenticacao ---------------------------------------------------------

@app.post(f"{V1}/auth/login", response_model=m.LoginOut, tags=["auth"])
def login(dados: m.LoginIn):
    usuario = next((u for u in db.USUARIOS
                    if u["email"] == dados.email and u["senha"] == dados.senha), None)
    if not usuario:
        raise HTTPException(status_code=401, detail="Email ou senha invalidos")

    token = f"mock-{usuario['id']}-{usuario['perfil']}"
    SESSOES[token] = usuario
    return {"token": token, "usuario": usuario}


# --- cadastro -------------------------------------------------------------

@app.get(f"{V1}/imoveis", response_model=list[m.ImovelOut], tags=["cadastro"])
def listar_imoveis(_: dict = Depends(apenas_proprietario)):
    saida = []
    for imovel in db.IMOVEIS:
        unidades = db.unidades_do_imovel(imovel["id"])
        ocupadas = [u for u in unidades if db.contrato_ativo(u["id"])]
        saida.append({
            "id": imovel["id"],
            "nome": imovel["nome"],
            "endereco": imovel["endereco"],
            "unidades": len(unidades),
            "unidades_ocupadas": len(ocupadas),
        })
    return saida


def _unidade_out(unidade: dict, competencia: Optional[str]) -> dict:
    contrato = db.contrato_ativo(unidade["id"])
    saida = {
        "id": unidade["id"],
        "imovel_id": unidade["imovel_id"],
        "identificacao": unidade["identificacao"],
        "status": "ocupada" if contrato else "vaga",
        "inquilino": db.nome_do_inquilino(contrato) if contrato else None,
        "valor_aluguel": contrato["valor_aluguel"] if contrato else None,
        "cobranca_status": None,
        "cobranca_total": None,
    }
    if contrato and competencia:
        cobranca = next((c for c in db.cobrancas_do_contrato(contrato["id"])
                         if c["competencia"] == competencia), None)
        if cobranca:
            saida["cobranca_status"] = cobranca["status"]
            saida["cobranca_total"] = cobranca["valor_total"]
    return saida


@app.get(f"{V1}/unidades", response_model=list[m.UnidadeOut], tags=["cadastro"])
def listar_unidades(
    competencia: Optional[str] = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    imovel_id: Optional[int] = None,
    _: dict = Depends(apenas_proprietario),
):
    unidades = db.UNIDADES
    if imovel_id is not None:
        unidades = db.unidades_do_imovel(imovel_id)
    return [_unidade_out(u, competencia) for u in unidades]


@app.get(f"{V1}/unidades/{{unidade_id}}", response_model=m.UnidadeOut, tags=["cadastro"])
def detalhar_unidade(
    unidade_id: int,
    competencia: Optional[str] = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    _: dict = Depends(apenas_proprietario),
):
    unidade = db.unidade(unidade_id)
    if not unidade:
        raise HTTPException(status_code=404, detail="Unidade nao encontrada")
    return _unidade_out(unidade, competencia)


@app.post(f"{V1}/unidades", response_model=m.UnidadeOut, status_code=201, tags=["cadastro"])
def criar_unidade(dados: m.UnidadeIn, _: dict = Depends(apenas_proprietario)):
    if not db.imovel(dados.imovel_id):
        raise HTTPException(status_code=404, detail="Imovel nao encontrado")

    unidade = {"id": db.proximo_id("unidade"), "imovel_id": dados.imovel_id,
               "identificacao": dados.identificacao}
    db.UNIDADES.append(unidade)
    return _unidade_out(unidade, None)


@app.post(f"{V1}/contratos", response_model=m.ContratoOut, status_code=201, tags=["cadastro"])
def criar_contrato(dados: m.ContratoIn, _: dict = Depends(apenas_proprietario)):
    if not db.unidade(dados.unidade_id):
        raise HTTPException(status_code=404, detail="Unidade nao encontrada")
    if not db.inquilino(dados.inquilino_id):
        raise HTTPException(status_code=404, detail="Inquilino nao encontrado")
    if db.contrato_ativo(dados.unidade_id):
        raise HTTPException(status_code=409, detail="A unidade ja tem contrato ativo")

    contrato = {"id": db.proximo_id("contrato"), **dados.model_dump(),
                "data_fim": None, "ativo": True}
    db.CONTRATOS.append(contrato)
    return {**contrato, "inquilino": db.nome_do_inquilino(contrato)}


# --- leituras e faturas ---------------------------------------------------

@app.get(f"{V1}/leituras", response_model=list[m.LeituraOut], tags=["leituras"])
def listar_leituras(
    competencia: str = Query(pattern=r"^\d{4}-\d{2}$"),
    imovel_id: Optional[int] = None,
    _: dict = Depends(apenas_proprietario),
):
    unidades = db.unidades_do_imovel(imovel_id) if imovel_id else db.UNIDADES
    saida = []
    for unidade in unidades:
        if not db.contrato_ativo(unidade["id"]):
            continue
        for tipo in ("agua", "energia"):
            registro = db.leitura(unidade["id"], tipo, competencia)
            anterior = registro["valor_anterior"] if registro else _valor_anterior(
                unidade["id"], tipo, competencia)
            atual = registro["valor_atual"] if registro else None
            saida.append({
                "unidade_id": unidade["id"],
                "identificacao": unidade["identificacao"],
                "tipo": tipo,
                "competencia": competencia,
                "valor_anterior": anterior,
                "valor_atual": atual,
                "consumo": round(atual - anterior, 3) if atual is not None else None,
            })
    return saida


def _valor_anterior(unidade_id: int, tipo: str, competencia: str) -> float:
    """Leitura que serve de base para o consumo desta competencia.

    Se a competencia ja tem registro, a base dela e o que vale: relancar
    a leitura do mes corrige o valor atual, nunca a base. Sem registro,
    a base e o valor_atual da competencia fechada mais recente.
    """
    registro = db.leitura(unidade_id, tipo, competencia)
    if registro:
        return registro["valor_anterior"]

    anteriores = [l for l in db.LEITURAS
                  if l["unidade_id"] == unidade_id
                  and l["tipo"] == tipo
                  and l["competencia"] < competencia]
    if not anteriores:
        return 0.0
    return max(anteriores, key=lambda l: l["competencia"])["valor_atual"]


@app.post(f"{V1}/leituras", response_model=list[m.LeituraOut], status_code=201, tags=["leituras"])
def lancar_leituras(dados: m.LeiturasLoteIn, _: dict = Depends(apenas_proprietario)):
    salvas = []
    for item in dados.leituras:
        unidade = db.unidade(item.unidade_id)
        if not unidade:
            raise HTTPException(status_code=404,
                                detail=f"Unidade {item.unidade_id} nao encontrada")

        anterior = _valor_anterior(item.unidade_id, item.tipo, dados.competencia)
        if item.valor_atual < anterior:
            raise HTTPException(
                status_code=422,
                detail=(f"{unidade['identificacao']}: leitura de {item.tipo} "
                        f"({item.valor_atual}) e menor que a anterior ({anterior})"),
            )

        registro = db.leitura(item.unidade_id, item.tipo, dados.competencia)
        if registro:
            registro["valor_atual"] = item.valor_atual
            registro["valor_anterior"] = anterior
        else:
            registro = {"id": db.proximo_id("leitura"), "unidade_id": item.unidade_id,
                        "tipo": item.tipo, "competencia": dados.competencia,
                        "valor_anterior": anterior, "valor_atual": item.valor_atual}
            db.LEITURAS.append(registro)

        salvas.append({
            "unidade_id": item.unidade_id,
            "identificacao": unidade["identificacao"],
            "tipo": item.tipo,
            "competencia": dados.competencia,
            "valor_anterior": anterior,
            "valor_atual": item.valor_atual,
            "consumo": round(item.valor_atual - anterior, 3),
        })
    return salvas


def _consumo_medido(imovel_id: int, tipo: str, competencia: str) -> float:
    """Soma dos submedidores ja lidos na competencia.

    Serve de piso para o consumo da fatura: se o relogio geral marcar menos
    que a soma dos submedidores, a area comum fica negativa e alguma leitura
    esta errada.
    """
    total = 0.0
    for unidade in db.unidades_do_imovel(imovel_id):
        if not db.contrato_ativo(unidade["id"]):
            continue
        registro = db.leitura(unidade["id"], tipo, competencia)
        if registro and registro["valor_atual"] is not None:
            total += registro["valor_atual"] - registro["valor_anterior"]
    return round(total, 3)


@app.get(f"{V1}/imoveis/{{imovel_id}}/faturas",
         response_model=list[m.FaturaOut], tags=["leituras"])
def listar_faturas(
    imovel_id: int,
    competencia: str = Query(pattern=r"^\d{4}-\d{2}$"),
    _: dict = Depends(apenas_proprietario),
):
    """Faturas da competencia, com os dois tipos sempre presentes.

    Devolve o tipo nao lancado com `valor_total` nulo em vez de omiti-lo: a
    tela de lancamento precisa de uma linha para cada medidor, preenchida ou
    nao, e e isso que permite editar uma fatura ja lancada sem redigitar.
    """
    if not db.imovel(imovel_id):
        raise HTTPException(status_code=404, detail="Imovel nao encontrado")

    saida = []
    for tipo in ("agua", "energia"):
        registro = db.fatura(imovel_id, tipo, competencia)
        saida.append({
            "imovel_id": imovel_id,
            "competencia": competencia,
            "tipo": tipo,
            "valor_total": registro["valor_total"] if registro else None,
            "consumo_total": registro["consumo_total"] if registro else None,
            "consumo_medido": _consumo_medido(imovel_id, tipo, competencia),
        })
    return saida


@app.post(f"{V1}/imoveis/{{imovel_id}}/faturas", status_code=201, tags=["leituras"])
def lancar_faturas(imovel_id: int, dados: m.FaturasLoteIn,
                   _: dict = Depends(apenas_proprietario)):
    if not db.imovel(imovel_id):
        raise HTTPException(status_code=404, detail="Imovel nao encontrado")

    for item in dados.faturas:
        registro = db.fatura(imovel_id, item.tipo, dados.competencia)
        if registro:
            registro.update(valor_total=item.valor_total,
                            consumo_total=item.consumo_total)
        else:
            db.FATURAS.append({"id": db.proximo_id("fatura"), "imovel_id": imovel_id,
                               "competencia": dados.competencia, **item.model_dump()})
    return {"imovel_id": imovel_id, "competencia": dados.competencia,
            "faturas_registradas": len(dados.faturas)}


# --- previa e fechamento --------------------------------------------------

def _montar_previa(imovel_id: int, competencia: str) -> dict:
    imovel = db.imovel(imovel_id)
    if not imovel:
        raise HTTPException(status_code=404, detail="Imovel nao encontrado")

    alertas: list[dict] = []
    ocupadas = [u for u in db.unidades_do_imovel(imovel_id)
                if db.contrato_ativo(u["id"])]

    if not ocupadas:
        alertas.append({"codigo": "sem_unidade_ocupada", "unidade_id": None,
                        "mensagem": "Nenhuma unidade ocupada neste imovel"})

    consumos: dict[str, dict[int, float]] = {"agua": {}, "energia": {}}
    for unidade in ocupadas:
        for tipo in ("agua", "energia"):
            registro = db.leitura(unidade["id"], tipo, competencia)
            if not registro or registro["valor_atual"] is None:
                alertas.append({
                    "codigo": "leitura_faltando",
                    "unidade_id": unidade["id"],
                    "mensagem": (f"{unidade['identificacao']}: leitura de {tipo} "
                                 "nao foi lancada"),
                })
                continue

            consumo = registro["valor_atual"] - registro["valor_anterior"]
            if consumo < 0:
                alertas.append({
                    "codigo": "leitura_menor_que_anterior",
                    "unidade_id": unidade["id"],
                    "mensagem": (f"{unidade['identificacao']}: leitura de {tipo} "
                                 "e menor que a anterior"),
                })
                continue

            consumos[tipo][unidade["id"]] = consumo

    resultados: dict[str, dict] = {}
    for tipo in ("agua", "energia"):
        fatura = db.fatura(imovel_id, tipo, competencia)
        if not fatura:
            alertas.append({"codigo": "fatura_faltando", "unidade_id": None,
                            "mensagem": f"Fatura de {tipo} nao foi lancada"})
            resultados[tipo] = {"resumo": None, "parcelas": {}}
            continue

        completo = len(consumos[tipo]) == len(ocupadas) and len(ocupadas) > 0
        if not completo:
            resultados[tipo] = {"resumo": None, "parcelas": {}}
            continue

        resultados[tipo] = rateio.calcular(
            fatura["valor_total"], fatura["consumo_total"], consumos[tipo])

        if resultados[tipo]["resumo"]["consumo_comum"] < 0:
            alertas.append({
                "codigo": "consumo_medido_acima_da_fatura",
                "unidade_id": None,
                "mensagem": (f"A soma dos submedidores de {tipo} passou o consumo "
                             "da fatura. Confira as leituras."),
            })

    vazia = {"consumo": 0.0, "rateio_comum": 0.0, "valor": 0}
    linhas = []
    total_geral = 0
    for unidade in ocupadas:
        contrato = db.contrato_ativo(unidade["id"])
        agua = resultados["agua"]["parcelas"].get(unidade["id"], vazia)
        energia = resultados["energia"]["parcelas"].get(unidade["id"], vazia)
        total = contrato["valor_aluguel"] + agua["valor"] + energia["valor"]
        total_geral += total
        linhas.append({
            "unidade_id": unidade["id"],
            "identificacao": unidade["identificacao"],
            "inquilino": db.nome_do_inquilino(contrato),
            "valor_aluguel": contrato["valor_aluguel"],
            "agua": agua,
            "energia": energia,
            "valor_total": total,
        })

    return {
        "imovel_id": imovel_id,
        "competencia": competencia,
        "agua": resultados["agua"]["resumo"],
        "energia": resultados["energia"]["resumo"],
        "unidades": linhas,
        "total_geral": total_geral,
        "alertas": alertas,
        "pode_fechar": len(alertas) == 0,
    }


@app.get(f"{V1}/imoveis/{{imovel_id}}/competencias/{{competencia}}/previa",
         response_model=m.PreviaOut, tags=["fechamento"])
def previa(imovel_id: int, competencia: str, _: dict = Depends(apenas_proprietario)):
    """Calcula o rateio sem gravar nada. E o que alimenta a tela de conferencia."""
    return _montar_previa(imovel_id, competencia)


@app.post(f"{V1}/imoveis/{{imovel_id}}/competencias/{{competencia}}/fechar",
          response_model=list[m.CobrancaOut], status_code=201, tags=["fechamento"])
def fechar(imovel_id: int, competencia: str, _: dict = Depends(apenas_proprietario)):
    """Confirma a previa e gera uma cobranca por contrato ativo."""
    resultado = _montar_previa(imovel_id, competencia)

    if not resultado["pode_fechar"]:
        raise HTTPException(status_code=409, detail={
            "mensagem": "A competencia tem pendencias e nao pode ser fechada",
            "alertas": resultado["alertas"],
        })

    ja_fechado = [c for c in db.COBRANCAS
                  if c["competencia"] == competencia
                  and db.unidade(c["unidade_id"])["imovel_id"] == imovel_id]
    if ja_fechado:
        raise HTTPException(status_code=409,
                            detail="Esta competencia ja foi fechada para este imovel")

    ano, mes = (int(p) for p in competencia.split("-"))
    geradas = []
    for linha in resultado["unidades"]:
        contrato = db.contrato_ativo(linha["unidade_id"])
        cobranca = {
            "id": db.proximo_id("cobranca"),
            "contrato_id": contrato["id"],
            "unidade_id": linha["unidade_id"],
            "identificacao": linha["identificacao"],
            "inquilino": linha["inquilino"],
            "competencia": competencia,
            "valor_aluguel": linha["valor_aluguel"],
            "valor_agua": linha["agua"]["valor"],
            "valor_energia": linha["energia"]["valor"],
            "valor_total": linha["valor_total"],
            "status": "aberta",
            "vencimento": date(ano, mes, contrato["dia_vencimento"]).isoformat(),
        }
        db.COBRANCAS.append(cobranca)
        geradas.append(cobranca)
    return geradas


# --- cobrancas ------------------------------------------------------------

@app.get(f"{V1}/cobrancas", response_model=list[m.CobrancaOut], tags=["cobrancas"])
def listar_cobrancas(
    competencia: Optional[str] = Query(default=None, pattern=r"^\d{4}-\d{2}$"),
    imovel_id: Optional[int] = None,
    _: dict = Depends(apenas_proprietario),
):
    saida = db.COBRANCAS
    if competencia:
        saida = [c for c in saida if c["competencia"] == competencia]
    if imovel_id is not None:
        saida = [c for c in saida
                 if db.unidade(c["unidade_id"])["imovel_id"] == imovel_id]
    return saida


@app.post(f"{V1}/cobrancas/{{cobranca_id}}/pagamento",
          response_model=m.PagamentoOut, status_code=201, tags=["cobrancas"])
def registrar_pagamento(cobranca_id: int, dados: m.PagamentoIn,
                        _: dict = Depends(apenas_proprietario)):
    cobranca = db.cobranca(cobranca_id)
    if not cobranca:
        raise HTTPException(status_code=404, detail="Cobranca nao encontrada")
    if cobranca["status"] == "paga":
        raise HTTPException(status_code=409, detail="Cobranca ja esta paga")

    pagamento = {"id": db.proximo_id("pagamento"), "cobranca_id": cobranca_id,
                 **dados.model_dump()}
    db.PAGAMENTOS.append(pagamento)

    pago = sum(p["valor"] for p in db.PAGAMENTOS if p["cobranca_id"] == cobranca_id)
    if pago >= cobranca["valor_total"]:
        cobranca["status"] = "paga"

    return {**pagamento, "cobranca_status": cobranca["status"]}


# --- visao do inquilino ---------------------------------------------------

def _contratos_do_inquilino(usuario: dict) -> list[dict]:
    inquilino_id = usuario.get("inquilino_id")
    return [c for c in db.CONTRATOS if c["inquilino_id"] == inquilino_id]


@app.get(f"{V1}/minhas-cobrancas", response_model=list[m.CobrancaOut], tags=["inquilino"])
def minhas_cobrancas(usuario: dict = Depends(usuario_logado)):
    if usuario["perfil"] != "inquilino":
        raise HTTPException(status_code=403, detail="Rota do inquilino")

    ids = {c["id"] for c in _contratos_do_inquilino(usuario)}
    return [c for c in db.COBRANCAS if c["contrato_id"] in ids]


@app.get(f"{V1}/meu-consumo", response_model=list[m.ConsumoOut], tags=["inquilino"])
def meu_consumo(usuario: dict = Depends(usuario_logado)):
    if usuario["perfil"] != "inquilino":
        raise HTTPException(status_code=403, detail="Rota do inquilino")

    saida = []
    for contrato in _contratos_do_inquilino(usuario):
        unidade = db.unidade(contrato["unidade_id"])
        por_competencia: dict[str, dict] = {}
        for registro in db.LEITURAS:
            if registro["unidade_id"] != unidade["id"]:
                continue
            ponto = por_competencia.setdefault(
                registro["competencia"],
                {"competencia": registro["competencia"], "agua": None, "energia": None})
            ponto[registro["tipo"]] = round(
                registro["valor_atual"] - registro["valor_anterior"], 3)

        saida.append({
            "unidade_id": unidade["id"],
            "identificacao": unidade["identificacao"],
            "historico": sorted(por_competencia.values(),
                                key=lambda p: p["competencia"]),
        })
    return saida
