import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/datasources/api_client.dart';
import '../../../data/models/imovel.dart';
import '../../../data/models/unidade.dart';
import '../../../data/repositories/auth_repository.dart';
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
  PainelViewModel(this._repo, this._auth);

  final ImovelRepository _repo;
  final AuthRepository _auth;

  /// Fixa porque o mock so tem esta competencia carregada. Numa versao
  /// real viria de um seletor de mes na propria tela.
  static const String competencia = '2026-11';

  bool _carregando = false;
  String? _erro;
  List<GrupoImovel> _grupos = const [];

  bool get carregando => _carregando;
  String? get erro => _erro;
  List<GrupoImovel> get grupos => _grupos;

  String get competenciaFormatada => Formatters.competencia(competencia);

  int get totalAReceber =>
      _grupos.fold(0, (soma, grupo) => soma + grupo.subtotal);

  String get totalFormatado => Formatters.moeda(totalAReceber);

  String get resumoPontos =>
      '${_grupos.length} ${_grupos.length == 1 ? 'ponto' : 'pontos'}';

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      final imoveis = await _repo.listarImoveis();
      final unidades = await _repo.listarUnidades(competencia: competencia);

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
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Encerra a sessao. Limpa os grupos porque este ViewModel e global: se
  /// ficassem, o proximo login veria por um instante o painel do anterior.
  void sair() {
    _auth.sair();
    _grupos = const [];
    _erro = null;
    notifyListeners();
  }

  /// Rotulo pronto para a View: a View nao formata nada.
  String valorDaUnidade(Unidade unidade) {
    if (!unidade.ocupada) return '';
    if (unidade.cobrancaTotal == null) return Formatters.moeda(unidade.valorAluguel ?? 0);
    return Formatters.moeda(unidade.cobrancaTotal!);
  }

  String legendaDaUnidade(Unidade unidade) {
    if (!unidade.ocupada) return 'Sem inquilino';
    if (unidade.cobrancaTotal == null) {
      return '${unidade.inquilino}  ·  mes ainda nao fechado';
    }
    return unidade.inquilino ?? '';
  }
}
