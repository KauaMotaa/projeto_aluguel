"""Schemas de entrada e saida da API.

Todo valor monetario trafega em centavos, como inteiro. Consumo e float:
m3 de agua costuma ter uma casa decimal, kWh e inteiro na pratica.
"""

from typing import Literal, Optional

from pydantic import BaseModel, Field

TipoMedidor = Literal["agua", "energia"]
StatusCobranca = Literal["aberta", "paga", "atrasada"]


# --- autenticacao ---------------------------------------------------------

class LoginIn(BaseModel):
    email: str
    senha: str


class UsuarioOut(BaseModel):
    id: int
    nome: str
    perfil: Literal["proprietario", "inquilino"]


class LoginOut(BaseModel):
    token: str
    usuario: UsuarioOut


# --- cadastro -------------------------------------------------------------

class ImovelOut(BaseModel):
    id: int
    nome: str
    endereco: str
    unidades: int
    unidades_ocupadas: int


class UnidadeIn(BaseModel):
    imovel_id: int
    identificacao: str


class UnidadeOut(BaseModel):
    id: int
    imovel_id: int
    identificacao: str
    status: Literal["ocupada", "vaga"]
    inquilino: Optional[str] = None
    valor_aluguel: Optional[int] = None
    cobranca_status: Optional[StatusCobranca] = None
    cobranca_total: Optional[int] = None


class InquilinoIn(BaseModel):
    nome: str = Field(min_length=2)
    telefone: str = ""


class InquilinoOut(BaseModel):
    """Pessoa cadastrada, com as unidades que ela ocupa hoje.

    As unidades vem junto porque a lista de nomes sozinha nao diz quem ja
    esta alojado, e e isso que evita escolher por engano alguem que ja tem
    contrato ativo.
    """

    id: int
    nome: str
    telefone: str = ""
    unidades: list[str] = []


class ContratoIn(BaseModel):
    unidade_id: int
    inquilino_id: int
    valor_aluguel: int = Field(gt=0, description="em centavos")
    dia_vencimento: int = Field(ge=1, le=28)
    data_inicio: str


class ContratoOut(BaseModel):
    id: int
    unidade_id: int
    inquilino_id: int
    inquilino: str
    valor_aluguel: int
    dia_vencimento: int
    data_inicio: str
    ativo: bool


# --- leituras e faturas ---------------------------------------------------

class LeituraIn(BaseModel):
    unidade_id: int
    tipo: TipoMedidor
    valor_atual: float


class LeiturasLoteIn(BaseModel):
    competencia: str = Field(pattern=r"^\d{4}-\d{2}$")
    leituras: list[LeituraIn]


class LeituraOut(BaseModel):
    """Uma linha da tela de leituras.

    `media_consumo` e a media do que este medidor consumiu nas
    competencias anteriores, e existe para o app poder avisar quando o
    valor digitado destoa. Vem da API porque e ela que tem o historico; o
    app so conhece o mes aberto.

    `meses_historico` diz de quantos meses essa media saiu: com um mes so
    ela nao e media de nada, e avisar seria falso alarme.
    """

    unidade_id: int
    identificacao: str
    tipo: TipoMedidor
    competencia: str
    valor_anterior: float
    valor_atual: Optional[float] = None
    consumo: Optional[float] = None
    media_consumo: Optional[float] = None
    meses_historico: int = 0


class FaturaIn(BaseModel):
    tipo: TipoMedidor
    valor_total: int = Field(gt=0, description="em centavos")
    consumo_total: float = Field(gt=0)


class FaturasLoteIn(BaseModel):
    competencia: str = Field(pattern=r"^\d{4}-\d{2}$")
    faturas: list[FaturaIn]


class FaturaOut(BaseModel):
    """Fatura da concessionaria, lancada ou ainda em branco.

    Vem sempre com os dois tipos: a tela de lancamento precisa saber o que
    falta, nao so o que ja existe. `valor_total` nulo significa nao lancada.

    `consumo_medido` e a soma dos submedidores ja lidos na competencia, e
    serve de piso na tela: o consumo da fatura nao pode ser menor que ele,
    senao a area comum fica negativa.
    """

    imovel_id: int
    competencia: str
    tipo: TipoMedidor
    valor_total: Optional[int] = None
    consumo_total: Optional[float] = None
    consumo_medido: float


# --- competencias ---------------------------------------------------------

class CompetenciaOut(BaseModel):
    """Um mes no seletor do app.

    O fechamento e por ponto, nao por mes: um mes pode estar fechado num
    imovel e aberto no outro. Por isso aqui vem a contagem, e nao um
    booleano `fechada` que mentiria na metade dos casos.
    """

    competencia: str
    cobrancas: int
    imoveis_fechados: int
    imoveis: int
    atual: bool = Field(description="e o mes do calendario")


# --- previa e fechamento --------------------------------------------------

class ResumoTipo(BaseModel):
    valor_total_fatura: int
    valor_unitario: float = Field(description="centavos por m3 ou por kWh")
    consumo_total: float
    consumo_medido: float
    consumo_comum: float
    rateio_comum_por_unidade: float


class ParcelaConsumo(BaseModel):
    consumo: float
    rateio_comum: float
    valor: int


class LinhaPrevia(BaseModel):
    unidade_id: int
    identificacao: str
    inquilino: str
    valor_aluguel: int
    agua: ParcelaConsumo
    energia: ParcelaConsumo
    valor_total: int


class Alerta(BaseModel):
    codigo: str
    unidade_id: Optional[int] = None
    mensagem: str


class PreviaOut(BaseModel):
    imovel_id: int
    competencia: str
    agua: Optional[ResumoTipo] = None
    energia: Optional[ResumoTipo] = None
    unidades: list[LinhaPrevia]
    total_geral: int
    alertas: list[Alerta]
    pode_fechar: bool


# --- cobrancas ------------------------------------------------------------

class CobrancaOut(BaseModel):
    id: int
    contrato_id: int
    unidade_id: int
    identificacao: str
    inquilino: str
    competencia: str
    valor_aluguel: int
    valor_agua: int
    valor_energia: int
    valor_total: int
    status: StatusCobranca
    vencimento: str


class PagamentoIn(BaseModel):
    valor: int = Field(gt=0)
    data_pagamento: str
    forma: Literal["pix", "dinheiro", "transferencia", "outro"] = "pix"


class PagamentoOut(BaseModel):
    id: int
    cobranca_id: int
    valor: int
    data_pagamento: str
    forma: str
    cobranca_status: StatusCobranca


class PontoConsumo(BaseModel):
    competencia: str
    agua: Optional[float] = None
    energia: Optional[float] = None


class ConsumoOut(BaseModel):
    unidade_id: int
    identificacao: str
    historico: list[PontoConsumo]
