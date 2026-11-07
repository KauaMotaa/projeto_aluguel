import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/datasources/api_client.dart';
import '../../../data/models/previa.dart';
import '../../../data/repositories/fechamento_repository.dart';

class PreviaViewModel extends ChangeNotifier {
  PreviaViewModel(
    this._repo, {
    required this.imovelId,
    required this.competencia,
  });

  final FechamentoRepository _repo;
  final int imovelId;

  /// Vem do seletor do painel, pelo CompetenciaStore. E o mes que vai ser
  /// fechado, entao fica fixo enquanto a tela existe.
  final String competencia;

  bool _carregando = false;
  bool _fechando = false;
  String? _erro;
  Previa? _previa;
  int? _cobrancasGeradas;

  bool get carregando => _carregando;
  bool get fechando => _fechando;
  String? get erro => _erro;
  Previa? get previa => _previa;
  int? get cobrancasGeradas => _cobrancasGeradas;

  String get competenciaFormatada => Formatters.competencia(competencia);

  bool get podeFechar => (_previa?.podeFechar ?? false) && !_fechando;

  /// Se a pendencia e a fatura, a tela oferece o atalho para lancar ela.
  /// Leitura faltando nao entra aqui: aquela tela e por unidade, e o
  /// alerta ja diz qual.
  bool get faltaFatura =>
      _previa?.alertas.any((a) => a.codigo == 'fatura_faltando') ?? false;

  /// Fatura ja lancada, mas com o consumo abaixo da soma dos submedidores.
  /// Tambem se corrige na tela de fatura.
  bool get faturaIncoerente =>
      _previa?.alertas
          .any((a) => a.codigo == 'consumo_medido_acima_da_fatura') ??
      false;

  String get totalFormatado => Formatters.moeda(_previa?.totalGeral ?? 0);

  String get resumoCobrancas {
    final n = _previa?.unidades.length ?? 0;
    return 'Total a gerar  ·  $n ${n == 1 ? 'cobranca' : 'cobrancas'}';
  }

  /// Rotulos de uma fatura, prontos para a View.
  String unitario(ResumoTipo resumo, String tipo) {
    final porUnidade = Formatters.moeda(resumo.valorUnitario.round());
    return '$porUnidade/${tipo == 'agua' ? 'm³' : 'kWh'}';
  }

  String origemDaFatura(ResumoTipo resumo, String tipo) {
    final total = Formatters.moeda(resumo.valorTotalFatura);
    return '$total ÷ ${Formatters.consumo(resumo.consumoTotal, tipo)}';
  }

  String consumoComum() {
    final agua = _previa?.agua;
    final energia = _previa?.energia;
    if (agua == null || energia == null) return '';
    return 'Consumo comum: ${Formatters.consumo(agua.consumoComum, 'agua')} '
        'e ${Formatters.consumo(energia.consumoComum, 'energia')}';
  }

  String rateioExplicado() {
    final n = _previa?.unidades.length ?? 0;
    return 'Dividido em partes iguais entre as $n unidades ocupadas';
  }

  String parcela(ParcelaConsumo parcela, String tipo) {
    final medido = Formatters.consumo(parcela.consumo, tipo);
    final comum = Formatters.numero(parcela.rateioComum, casas: 2);
    return '$tipo · $medido + $comum de area comum';
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();

    try {
      _previa = await _repo.previa(
        imovelId: imovelId,
        competencia: competencia,
      );
    } on ApiException catch (e) {
      _erro = e.mensagem;
      _previa = null;
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<bool> fechar() async {
    _fechando = true;
    _erro = null;
    notifyListeners();

    try {
      _cobrancasGeradas = await _repo.fechar(
        imovelId: imovelId,
        competencia: competencia,
      );
      return true;
    } on ApiException catch (e) {
      _erro = e.mensagem;
      return false;
    } finally {
      _fechando = false;
      notifyListeners();
    }
  }
}
