import 'package:flutter/foundation.dart';

import '../../../core/state/competencia_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/datasources/api_client.dart';
import '../../../data/models/cobranca.dart';
import '../../../data/models/imovel.dart';
import '../../../data/models/unidade.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/cobranca_repository.dart';
import '../../../data/repositories/imovel_repository.dart';

/// Um ponto da lista: o imovel e as unidades dele, ja agrupadas.
class GrupoImovel {
  const GrupoImovel({
    required this.imovel,
    required this.unidades,
    required this.subtotal,
  });

  final Imovel imovel;
  final List<Unidade> unidades;
  final int subtotal;

  String get subtotalFormatado => Formatters.moeda(subtotal);
}

class PainelViewModel extends ChangeNotifier {
  PainelViewModel(this._repo, this._cobrancas, this._auth, this._competencia);

  final ImovelRepository _repo;
  final CobrancaRepository _cobrancas;
  final AuthRepository _auth;

  /// O mes vem daqui, nao de uma constante na classe. Trocar de mes e
  /// `selecionar` no store seguido de [carregar]: quem muda o valor e o
  /// seletor do cabecalho, e so ele.
  final CompetenciaStore _competencia;

  bool _carregando = false;
  String? _erro;
  List<GrupoImovel> _grupos = const [];

  /// Cobranca da competencia por unidade. Vem da rota de cobrancas, e nao
  /// da de unidades, porque o pagamento precisa do id da cobranca e da
  /// quebra entre aluguel, agua e energia — e `/unidades` traz so o total.
  Map<int, Cobranca> _porUnidade = const {};

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<GrupoImovel> get grupos => _grupos;

  String get competencia => _competencia.atual;
  String get competenciaFormatada => _competencia.formatada;

  int get totalFaturado =>
      _grupos.fold(0, (soma, grupo) => soma + grupo.subtotal);

  String get totalFormatado => Formatters.moeda(totalFaturado);

  int get totalRecebido => _porUnidade.values
      .where((c) => c.paga)
      .fold(0, (soma, c) => soma + c.valorTotal);

  int get totalEmAberto => _porUnidade.values
      .where((c) => !c.paga)
      .fold(0, (soma, c) => soma + c.valorTotal);

  String get resumoPontos =>
      '${_grupos.length} ${_grupos.length == 1 ? 'ponto' : 'pontos'}';

  /// Linha de recebimento do cabecalho. Fica nula quando o mes nao foi
  /// fechado em ponto nenhum: sem cobranca nao ha o que receber, e uma
  /// linha de zeros so ocuparia espaco.
  String? get resumoRecebimento {
    if (_porUnidade.isEmpty) return null;
    return '${Formatters.moeda(totalEmAberto)} em aberto  ·  '
        '${Formatters.moeda(totalRecebido)} recebido';
  }

  /// Pontos cadastrados, para o seletor da tela de nova unidade.
  List<Imovel> get imoveis => [for (final grupo in _grupos) grupo.imovel];

  /// Identificacoes em uso por ponto. O cadastro usa isso para recusar
  /// nome repetido sem precisar pedir a lista de novo.
  Map<int, List<String>> get identificacoesPorImovel => {
        for (final grupo in _grupos)
          grupo.imovel.id: [for (final u in grupo.unidades) u.identificacao],
      };

  Cobranca? cobrancaDa(Unidade unidade) => _porUnidade[unidade.id];

  /// O mes da unidade ja foi fechado, entao ha cobranca para abrir.
  ///
  /// Vale tambem para a que ja esta paga: dela ainda da para compartilhar
  /// a quebra com o inquilino, que e o comprovante dele.
  bool temCobranca(Unidade unidade) => _porUnidade.containsKey(unidade.id);

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      final imoveis = await _repo.listarImoveis();
      final unidades = await _repo.listarUnidades(competencia: competencia);
      final cobrancas = await _cobrancas.listar(competencia: competencia);

      _porUnidade = {for (final cobranca in cobrancas) cobranca.unidadeId: cobranca};

      _grupos = imoveis.map((imovel) {
        final doImovel =
            unidades.where((u) => u.imovelId == imovel.id).toList();
        final subtotal = doImovel.fold<int>(
          0,
          (soma, u) => soma + (u.cobrancaTotal ?? 0),
        );
        return GrupoImovel(
          imovel: imovel,
          unidades: doImovel,
          subtotal: subtotal,
        );
      }).toList();
    } on ApiException catch (e) {
      _erro = e.mensagem;
      _grupos = const [];
      _porUnidade = const {};
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Encerra a sessao. Limpa os grupos porque este ViewModel e global: se
  /// ficassem, o proximo login veria por um instante o painel do anterior.
  /// O mes escolhido tambem cai, pelo mesmo motivo.
  void sair() {
    _auth.sair();
    _competencia.limpar();
    _grupos = const [];
    _porUnidade = const {};
    _erro = null;
    notifyListeners();
  }

  /// Rotulo pronto para a View: a View nao formata nada.
  String valorDaUnidade(Unidade unidade) {
    if (!unidade.ocupada) return '';
    if (unidade.cobrancaTotal == null) {
      return Formatters.moeda(unidade.valorAluguel ?? 0);
    }
    return Formatters.moeda(unidade.cobrancaTotal!);
  }

  String legendaDaUnidade(Unidade unidade) {
    if (!unidade.ocupada) return 'Sem inquilino  ·  toque para alugar';
    if (unidade.cobrancaTotal == null) {
      return '${unidade.inquilino}  ·  mes ainda nao fechado';
    }
    final cobranca = _porUnidade[unidade.id];
    if (cobranca != null && !cobranca.paga) {
      return '${unidade.inquilino}  ·  vence ${Formatters.data(cobranca.vencimento)}';
    }
    return unidade.inquilino ?? '';
  }
}
